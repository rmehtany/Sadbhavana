package llm

import "sadbhavana/tree-project/pkgs/file"

// Role represents the role of a message sender
type Role string

const (
	RoleSystem    Role = "system"
	RoleUser      Role = "user"
	RoleAssistant Role = "assistant"
)

// ContentType represents the type of message content
type ContentType string

const (
	ContentTypeText ContentType = "text"
	ContentTypeFile ContentType = "file"
)

// MessageContent represents the content of a message (either text or file)
type MessageContent struct {
	Type ContentType  `json:"type" validate:"required,oneof=text file"`
	Text *TextContent `json:"text,omitempty"`
	File *FileContent `json:"file,omitempty"`
}

// TextContent represents text-based message content
type TextContent struct {
	Text string `json:"text" validate:"required"`
}

// FileContent represents file-based message content
type FileContent struct {
	// This is file url for GEMINI
	FileID   string        `json:"file_id" validate:"required"`
	MimeType file.MimeType `json:"mime_type" validate:"required"`
}

// Message represents a single message in a conversation
type Message struct {
	Role    Role           `json:"role" validate:"required,oneof=system user assistant"`
	Content MessageContent `json:"content" validate:"required"`
}

// Request represents a request to an LLM
type Request struct {
	Messages []Message `json:"messages" validate:"required,min=1,dive"`
	Config   Config    `json:"config"`
}

// Config holds configuration for LLM requests
type Config struct {
	Temperature *float64 `json:"temperature,omitempty" validate:"omitempty,min=0,max=2"`
	MaxTokens   *int     `json:"max_tokens,omitempty" validate:"omitempty,min=1"`
	TopP        *float64 `json:"top_p,omitempty" validate:"omitempty,min=0,max=1"`
}

// Response represents the response from an LLM
type Response struct {
	Content string     `json:"content"`
	Usage   TokenUsage `json:"usage"`
}

// TokenUsage tracks token consumption
type TokenUsage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
}
