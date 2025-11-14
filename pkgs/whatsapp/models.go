package whatsapp

import "sadbhavana/tree-project/pkgs/file"

type WebhookVerifyInput struct {
	Mode      string `query:"hub.mode" doc:"Should be 'subscribe'"`
	Token     string `query:"hub.verify_token" doc:"Your verify token"`
	Challenge string `query:"hub.challenge" doc:"Challenge string to return"`
}

// Webhook verification response
type WebhookVerifyOutput struct {
	Body string `header:"Content-Type=text/plain"`
}

// Webhook event structures
type WebhookInput struct {
	Body WebhookPayload
}

type WebhookPayload struct {
	Object string  `json:"object"`
	Entry  []Entry `json:"entry"`
}

type Entry struct {
	ID      string   `json:"id"`
	Changes []Change `json:"changes"`
}

type Change struct {
	Value Value  `json:"value"`
	Field string `json:"field"`
}

type Value struct {
	MessagingProduct string    `json:"messaging_product"`
	Metadata         Metadata  `json:"metadata"`
	Contacts         []Contact `json:"contacts,omitempty"`
	Messages         []Message `json:"messages,omitempty"`
}

type Metadata struct {
	DisplayPhoneNumber string `json:"display_phone_number"`
	PhoneNumberID      string `json:"phone_number_id"`
}

type Contact struct {
	Profile Profile `json:"profile"`
	WaID    string  `json:"wa_id"`
}

type Profile struct {
	Name string `json:"name"`
}

type Message struct {
	From      string    `json:"from"`
	ID        string    `json:"id"`
	Timestamp string    `json:"timestamp"`
	Type      string    `json:"type"` // "text", "image", "video", "audio", "document", etc.
	Text      *TextMsg  `json:"text,omitempty"`
	Image     *MediaMsg `json:"image,omitempty"`
	Video     *MediaMsg `json:"video,omitempty"`
	Audio     *MediaMsg `json:"audio,omitempty"`
	Document  *MediaMsg `json:"document,omitempty"`
}

type TextMsg struct {
	Body string `json:"body"`
}

type MediaMsg struct {
	ID       string `json:"id"` // Media ID to download
	MimeType string `json:"mime_type"`
	SHA256   string `json:"sha256"`
	Caption  string `json:"caption,omitempty"`
}

type WebhookOutput struct {
	Body string
}

// MediaURLResponse represents the response from WhatsApp when getting media URL
type MediaURLResponse struct {
	URL              string `json:"url"`
	MimeType         string `json:"mime_type"`
	SHA256           string `json:"sha256"`
	FileSize         int64  `json:"file_size"`
	ID               string `json:"id"`
	MessagingProduct string `json:"messaging_product"`
}

type ParsedMessageType string

const (
	ParsedMessageTypeText     ParsedMessageType = "text"
	ParsedMessageTypeImage    ParsedMessageType = "image"
	ParsedMessageTypeVideo    ParsedMessageType = "video"
	ParsedMessageTypeAudio    ParsedMessageType = "audio"
	ParsedMessageTypeDocument ParsedMessageType = "document"
)

type ParsedMessage struct {
	From string            `json:"from"`
	Type ParsedMessageType `json:"type"`
	Text *string           `json:"content,omitempty"` // Text body or local file path
	File *file.FileInfo    `json:"file,omitempty"`    // For media messages
}
