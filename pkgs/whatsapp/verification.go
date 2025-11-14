package whatsapp

import (
	"context"
	"log"
	"sadbhavana/tree-project/pkgs/conf"

	"github.com/danielgtaylor/huma/v2"
)

func HandleWebhookVerification(ctx context.Context, input *WebhookVerifyInput) (*WebhookVerifyOutput, error) {
	log.Printf("Verification request - Mode: %s, Token: %s", input.Mode, input.Token)

	token := conf.GetConfig().WhatsappConfig.VerifyToken

	if input.Mode == "subscribe" && input.Token == token {
		log.Println("Webhook verified successfully")
		return &WebhookVerifyOutput{Body: input.Challenge}, nil
	}

	log.Println("Verification failed")
	return nil, huma.Error403Forbidden("Verification failed")
}
