package llm

import (
	"context"
	"fmt"
	"io"
	"sadbhavana/tree-project/pkgs/conf"
	"sadbhavana/tree-project/pkgs/file"
	"sadbhavana/tree-project/pkgs/utils"

	"strings"

	"github.com/juju/errors"
	"google.golang.org/genai"
)

const GEMINI_PROVIDER_NAME string = "GEMINI"

// Gemini model enums
type GeminiModel string

const (
	Gemini25Flash GeminiModel = "gemini-2.5-flash"
	Gemini25Pro   GeminiModel = "gemini-2.5-pro"
	Gemini20Flash GeminiModel = "gemini-2.0-flash"
	Gemini15Pro   GeminiModel = "gemini-1.5-pro"
	Gemini15Flash GeminiModel = "gemini-1.5-flash"
)

// Options for client configuration
type Option func(*ClientConfig)

type ClientConfig struct {
	BaseURL string
}

func WithBaseURL(url string) Option {
	return func(c *ClientConfig) {
		c.BaseURL = url
	}
}

// Validate Gemini models
func isValidGeminiModel(model GeminiModel) bool {
	switch model {
	case Gemini25Flash, Gemini25Pro, Gemini20Flash, Gemini15Pro, Gemini15Flash:
		return true
	}
	return false
}

type geminiClient struct {
	client *genai.Client
	model  string
	config *ClientConfig
}

// Factory function for Gemini client
func NewGeminiClient(ctx context.Context, model GeminiModel, opts ...Option) (Client, error) {
	apiKey := conf.GetConfig().GeminiConfig.APIKey
	if apiKey == "" {
		return nil, fmt.Errorf("API key is required")
	}
	if !isValidGeminiModel(model) {
		return nil, fmt.Errorf("invalid Gemini model: %s", model)
	}

	config := &ClientConfig{
		BaseURL: "https://generativelanguage.googleapis.com",
	}

	for _, opt := range opts {
		opt(config)
	}

	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		APIKey:  apiKey,
		Backend: genai.BackendGeminiAPI,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create Gemini client: %w", err)
	}

	return &geminiClient{
		client: client,
		model:  string(model),
		config: config,
	}, nil
}

func (c *geminiClient) UploadFile(ctx context.Context, filename string, mimeType file.MimeType, data io.Reader) (*file.FileInfo, error) {
	mimeTypeStr, err := mimeType.ToGoogleMimeType()
	if err != nil {
		return nil, fmt.Errorf("failed to get MIME type: %w", err)
	}

	uploadResp, err := c.client.Files.Upload(ctx, data, &genai.UploadFileConfig{
		MIMEType:    mimeTypeStr,
		DisplayName: filename,
	})
	if err != nil {
		return nil, c.handleError(err)
	}

	return &file.FileInfo{
		FileID:     uploadResp.Name,
		FileURL:    uploadResp.URI,
		FileName:   uploadResp.DisplayName,
		MimeType:   mimeType,
		Expiration: &uploadResp.ExpirationTime,
	}, nil
}

func (c *geminiClient) Prompt(ctx context.Context, req *Request) (*Response, error) {
	contents, err := c.convertToGeminiContents(req.Messages)
	if err != nil {
		return nil, fmt.Errorf("failed to convert messages: %w", err)
	}

	config := &genai.GenerateContentConfig{}

	for _, msg := range req.Messages {
		if msg.Content.File != nil && msg.Content.File.FileID != "" {
			// check if file id has prefix https://
			if !strings.HasPrefix(msg.Content.File.FileID, "https://") {
				return nil, fmt.Errorf("file id must be a valid URI starting with https://")
			}

		}

	}

	if req.Config.Temperature != nil {
		temp := float32(*req.Config.Temperature)
		config.Temperature = &temp
	}
	if req.Config.MaxTokens != nil {
		config.MaxOutputTokens = int32(*req.Config.MaxTokens)
	}
	if req.Config.TopP != nil {
		topP := float32(*req.Config.TopP)
		config.TopP = &topP
	}

	resp, err := c.client.Models.GenerateContent(ctx, c.model, contents, config)
	if err != nil {
		return nil, c.handleError(err)
	}

	content := resp.Text()
	if content == "" {
		return nil, fmt.Errorf("no response content: %w", ErrServerError)
	}

	usage := TokenUsage{}
	if resp.UsageMetadata != nil {
		usage = TokenUsage{
			PromptTokens:     int(resp.UsageMetadata.PromptTokenCount),
			CompletionTokens: int(resp.UsageMetadata.CandidatesTokenCount),
			TotalTokens:      int(resp.UsageMetadata.TotalTokenCount),
		}
	}

	output := Response{
		Content: content,
		Usage:   usage,
	}

	return &output, nil
}

func (c *geminiClient) convertToGeminiContents(messages []Message) ([]*genai.Content, error) {
	var contents []*genai.Content

	for _, msg := range messages {
		role := c.convertRole(msg.Role)
		var parts []*genai.Part

		switch msg.Content.Type {
		case ContentTypeText:
			parts = append(parts, &genai.Part{
				Text: msg.Content.Text.Text,
			})
		case ContentTypeFile:
			googleMimeType, err := msg.Content.File.MimeType.ToGoogleMimeType()
			if err != nil {
				return nil, fmt.Errorf("failed to convert MIME type: %w", err)
			}
			parts = append(parts, &genai.Part{
				FileData: &genai.FileData{
					FileURI:  msg.Content.File.FileID,
					MIMEType: googleMimeType,
				},
			})
		}

		// Check if we can merge with the previous content (same role)
		if len(contents) > 0 && contents[len(contents)-1].Role == role {
			// Merge parts into the existing content
			contents[len(contents)-1].Parts = append(contents[len(contents)-1].Parts, parts...)
		} else {
			// Create new content
			contents = append(contents, &genai.Content{
				Parts: parts,
				Role:  role,
			})
		}
	}

	return contents, nil
}

func (c *geminiClient) convertRole(role Role) string {
	switch role {
	case RoleSystem:
		return "user" // Gemini doesn't have system role, use user
	case RoleUser:
		return "user"
	case RoleAssistant:
		return "model"
	default:
		return "user"
	}
}

func (c *geminiClient) handleError(err error) error {
	// For the official genai package, we'll handle errors more generically
	// since the exact error types may vary
	if err == nil {
		return nil
	}

	errStr := err.Error()

	// Check common error patterns in the error message
	switch {
	case utils.StringContains(errStr, "unauthorized", "authentication", "api key"):
		return errors.Annotatef(err, "authentication failed")
	case utils.StringContains(errStr, "rate limit", "quota"):
		return errors.Annotatef(err, "rate limit exceeded")
	case utils.StringContains(errStr, "bad request", "invalid"):
		return errors.Annotatef(err, "invalid input")
	case utils.StringContains(errStr, "not found"):
		return errors.Annotatef(err, "resource not found")
	case utils.StringContains(errStr, "forbidden", "quota exceeded"):
		return errors.Annotatef(err, "quota exceeded")
	case utils.StringContains(errStr, "server error", "internal error"):
		return errors.Annotatef(err, "server error")
	default:
		return errors.Annotatef(err, "request failed")
	}
}
