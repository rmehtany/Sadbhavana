package whatsapp

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sadbhavana/tree-project/pkgs/conf"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/file"
	"time"
)

func HandleWebhookEvent(ctx context.Context, input *WebhookInput) (*WebhookOutput, error) {
	payload := input.Body

	log.Printf("Received webhook: %+v", payload)
	q, tx, err := db.NewQueriesWithTx(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get database queries: %w", err)
	}
	defer tx.Rollback(ctx)

	// Process each entry
	for _, entry := range payload.Entry {
		for _, change := range entry.Changes {
			if change.Field == "messages" {
				msgs, err := processMessages(change.Value)
				if err != nil {
					log.Printf("Failed to process messages: %v", err)
					continue
				}
				for _, msg := range msgs {
					err = extractImageData(ctx, q, msg)
					if err != nil {
						log.Printf("Failed to extract image data: %v", err)
						continue
					}
				}
			}
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Must return 200 OK to Meta
	return &WebhookOutput{Body: "EVENT_RECEIVED"}, nil
}

// Process incoming messages
func processMessages(value Value) ([]ParsedMessage, error) {
	parsedMessages := make([]ParsedMessage, 0, len(value.Messages))
	var err error

	for _, message := range value.Messages {
		log.Printf("Message from %s, Type: %s", message.From, message.Type)

		var dataID string
		msg := ParsedMessage{
			From: message.From,
			Type: ParsedMessageType(message.Type),
		}

		switch message.Type {
		case "text":
			if message.Text == nil {
				return nil, fmt.Errorf("text message missing text data")
			}
			msg.Text = &message.Text.Body
		case "image":
			if message.Image == nil {
				return nil, fmt.Errorf("image message missing image data")
			}
			log.Printf("Image received - ID: %s, MimeType: %s", message.Image.ID, message.Image.MimeType)
			dataID = message.Image.ID
		case "video":
			if message.Video == nil {
				return nil, fmt.Errorf("video message missing video data")
			}
			log.Printf("Video received - ID: %s, MimeType: %s", message.Video.ID, message.Video.MimeType)
			dataID = message.Video.ID
		case "audio":
			if message.Audio == nil {
				return nil, fmt.Errorf("audio message missing audio data")
			}
			log.Printf("Audio received - ID: %s, MimeType: %s", message.Audio.ID, message.Audio.MimeType)
			dataID = message.Audio.ID
		case "document":
			if message.Document == nil {
				return nil, fmt.Errorf("document message missing document data")
			}
			log.Printf("Document received - ID: %s, MimeType: %s", message.Document.ID, message.Document.MimeType)
			dataID = message.Document.ID
		}
		if dataID != "" {
			msg.File, err = downloadMedia(dataID)
			if err != nil {
				log.Printf("Failed to download media ID %s: %v", dataID, err)
				continue
			}
			log.Printf("Media downloaded and saved: %+v", msg.File)
		}
		parsedMessages = append(parsedMessages, msg)
	}
	return parsedMessages, nil
}

// downloadMedia downloads media from WhatsApp and saves it to local file store
func downloadMedia(mediaID string) (*file.FileInfo, error) {
	ctx := context.Background()

	// Step 1: Get the media URL from WhatsApp
	accessToken := conf.GetConfig().WhatsappConfig.AccessToken
	mediaURLEndpoint := fmt.Sprintf("https://graph.facebook.com/v18.0/%s", mediaID)

	req, err := http.NewRequest("GET", mediaURLEndpoint, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to get media URL: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("failed to get media URL, status: %d, body: %s", resp.StatusCode, string(body))
	}

	var mediaResp MediaURLResponse
	if err := json.NewDecoder(resp.Body).Decode(&mediaResp); err != nil {
		return nil, fmt.Errorf("failed to decode media response: %w", err)
	}

	log.Printf("Media URL obtained: %s, MimeType: %s, Size: %d bytes", mediaResp.URL, mediaResp.MimeType, mediaResp.FileSize)

	// Step 2: Download the actual file from the URL
	downloadReq, err := http.NewRequest("GET", mediaResp.URL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create download request: %w", err)
	}
	downloadReq.Header.Set("Authorization", "Bearer "+accessToken)

	downloadResp, err := client.Do(downloadReq)
	if err != nil {
		return nil, fmt.Errorf("failed to download media: %w", err)
	}
	defer downloadResp.Body.Close()

	if downloadResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(downloadResp.Body)
		return nil, fmt.Errorf("failed to download media, status: %d, body: %s", downloadResp.StatusCode, string(body))
	}

	// Step 3: Convert WhatsApp mime type to your MimeType
	mimeType, err := file.FromGoogleMimeType(mediaResp.MimeType)
	if err != nil {
		log.Printf("Warning: unknown mime type %s, using unknown", mediaResp.MimeType)
		mimeType = file.MimeTypeUnknown
	}

	// Step 4: Generate filename with appropriate extension from MimeType
	timestamp := time.Now().Format("20060102-150405")
	filename := fmt.Sprintf("whatsapp-%s-%s.%s", mediaID, timestamp, string(mimeType))

	folderInfo := file.FolderInfo{
		FolderPath: "whatsapp",
	}

	// Step 6: Save to local file store
	fileStore, err := file.NewFileStore("local", nil)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize file store: %w", err)
	}
	savedFile, err := fileStore.UploadFile(ctx, filename, mimeType, folderInfo, downloadResp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to save file: %w", err)
	}

	log.Printf("Media downloaded successfully: %s (Size: %d bytes, Path: %s)", savedFile.FileName, savedFile.Size, savedFile.FilePath)

	return &savedFile, nil
}
