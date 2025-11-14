package web

import (
	"context"
	"fmt"
	"net/http"

	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/html"
	"sadbhavana/tree-project/pkgs/template"
	"sadbhavana/tree-project/pkgs/whatsapp"

	"github.com/danielgtaylor/huma/v2"
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

func RegisterWhatsappHandlers(api huma.API) error {
	// Placeholder for future WhatsApp-related handlers
	huma.Register(api, huma.Operation{
		OperationID: "whatsapp-verification",
		Method:      http.MethodGet,
		Path:        "/whatsapp/webhook",
		Summary:     "Handle WhatsApp webhook verification",
		Tags:        []string{"whatsapp"},
	}, whatsapp.HandleWebhookVerification)

	huma.Register(api, huma.Operation{
		OperationID: "whatsapp-webhook",
		Method:      http.MethodPost,
		Path:        "/whatsapp/webhook",
		Summary:     "Handle WhatsApp webhook events",
		Tags:        []string{"whatsapp"},
	}, whatsapp.HandleWebhookEvent)

	return nil
}
