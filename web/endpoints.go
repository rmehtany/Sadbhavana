package web

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"sadbhavana/tree-project/pkgs/conf"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/html"
	"sadbhavana/tree-project/pkgs/template"
	"sadbhavana/tree-project/pkgs/whatsapp"

	"github.com/danielgtaylor/huma/v2"
	"github.com/go-chi/chi/v5"
)

func RegisterMapHandlers(api huma.API) error {
	ctx := context.Background()
	queries, err := db.NewQueries(ctx)
	if err != nil {
		return fmt.Errorf("failed to initialize database queries: %w", err)
	}

	handlers := NewHandlers(queries)

	huma.Register(api, huma.Operation{
		OperationID: "get-markers",
		Method:      http.MethodGet,
		Path:        "/api/markers",
		Summary:     "Get map markers",
		Tags:        []string{"markers"},
	}, func(ctx context.Context, input *GetMarkersInput) (*html.HTMLResponse, error) {
		markers, err := handlers.GetMarkers(ctx, input)
		if err != nil {
			return nil, huma.Error500InternalServerError("Failed to retrieve markers", err)
		}

		return html.CreateHTMLResponse(ctx, template.MarkerContainer(markers))
	})

	huma.Register(api, huma.Operation{
		OperationID: "get-tree-detail",
		Method:      http.MethodGet,
		Path:        "/api/tree/{id}",
		Summary:     "Get tree details",
		Tags:        []string{"trees"},
	}, func(ctx context.Context, input *GetTreeDetailInput) (*html.HTMLResponse, error) {
		tree, err := handlers.GetTreeDetail(ctx, input.ID)
		if err != nil {
			return nil, huma.Error404NotFound("Tree not found", err)
		}

		return html.CreateHTMLResponse(ctx, template.TreeDetailPanel(tree))
	})

	huma.Register(api, huma.Operation{
		OperationID: "get-cluster-detail",
		Method:      http.MethodGet,
		Path:        "/api/cluster/{projectCode}",
		Summary:     "Get cluster details",
		Tags:        []string{"clusters"},
	}, func(ctx context.Context, input *GetClusterDetailInput) (*html.HTMLResponse, error) {
		cluster, err := handlers.GetClusterDetail(ctx, input.ProjectCode)
		if err != nil {
			return nil, huma.Error404NotFound("Cluster not found", err)
		}

		return html.CreateHTMLResponse(ctx, template.ClusterDetailPanel(cluster))
	})

	huma.Register(api, huma.Operation{
		OperationID: "get-cluster-detail-raw",
		Method:      http.MethodGet,
		Path:        "/api/cluster/{projectCode}/raw",
		Summary:     "Get raw cluster details",
		Tags:        []string{"clusters"},
	}, func(ctx context.Context, input *GetClusterDetailInput) (*ClusterDetailRawResponse, error) {
		cluster, err := handlers.GetClusterDetail(ctx, input.ProjectCode)
		if err != nil {
			return nil, fmt.Errorf("failed to get cluster detail: %w", err)
		}

		return &ClusterDetailRawResponse{
			Body: *cluster,
		}, nil
	})

	return nil
}

func RegisterWhatsappHandlers(mux chi.Router) error {
	// GET for webhook verification
	mux.Get("/whatsapp/webhook", func(w http.ResponseWriter, r *http.Request) {
		mode := r.URL.Query().Get("hub.mode")
		token := r.URL.Query().Get("hub.verify_token")
		challenge := r.URL.Query().Get("hub.challenge")

		log.Printf("Verification request - Mode: %s, Token: %s", mode, token)

		verifyToken := conf.GetConfig().WhatsappConfig.VerifyToken

		if mode == "subscribe" && token == verifyToken {
			log.Println("Webhook verified successfully")
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(challenge))
			return
		}

		log.Println("Verification failed")
		w.WriteHeader(http.StatusForbidden)
		w.Write([]byte("Verification failed"))
	})

	// POST for webhook events
	mux.Post("/whatsapp/webhook", func(w http.ResponseWriter, r *http.Request) {
		var payload whatsapp.WebhookPayload
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			log.Printf("Error decoding webhook payload: %v", err)
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte("Bad Request"))
			return
		}

		// Call your handler function
		input := &whatsapp.WebhookInput{Body: payload}
		output, err := whatsapp.HandleWebhookEvent(r.Context(), input)
		if err != nil {
			log.Printf("Error handling webhook event: %v", err)
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte(output.Body))
	})

	return nil
}
