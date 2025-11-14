package llm

import (
	"context"
	"errors"
	"io"
	"sadbhavana/tree-project/pkgs/file"

	"time"
)

// Client represents an LLM provider client
type Client interface {
	UploadFile(ctx context.Context, filename string, mimeType file.MimeType, data io.Reader) (*file.FileInfo, error)
	Prompt(ctx context.Context, req *Request) (*Response, error)
}

// Common error types
var (
	ErrRateLimit      = errors.New("rate limit exceeded")
	ErrInvalidInput   = errors.New("invalid input")
	ErrAuthentication = errors.New("authentication failed")
	ErrQuotaExceeded  = errors.New("quota exceeded")
	ErrNotFound       = errors.New("resource not found")
	ErrServerError    = errors.New("server error")
)

type AIFileInfo struct {
	FileID     string
	FileURL    string
	FileSize   int64
	Expiration *time.Time
	MimeType   file.MimeType
}

func NewClient(ctx context.Context, providerName, modelName string) (Client, error) {
	switch providerName {
	case "GEMINI":
		return NewGeminiClient(ctx, GeminiModel(modelName))
	default:
		return nil, errors.New("unsupported provider")
	}
}
