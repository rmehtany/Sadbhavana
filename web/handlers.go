package web

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/url"
	"strings"
	"time"

	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/html"
	"sadbhavana/tree-project/pkgs/template"
	"sadbhavana/tree-project/pkgs/utils"

	"github.com/a-h/templ"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type Handlers struct {
	queries *db.Queries
}

func NewHandlers(queries *db.Queries) *Handlers {
	return &Handlers{
		queries: queries,
	}
}

func (h *Handlers) GetMarkers(ctx context.Context, input *GetMarkersInput) ([]template.Marker, error) {
	var markers []template.Marker
	var err error

	if input.Zoom <= 8 {
		markers, err = h.getProjectClusterMarkers(ctx, input)
	} else if input.Zoom <= 12 {
		markers, err = h.getGridClusterMarkers(ctx, input)
	} else {
		markers, err = h.getIndividualTreeMarkers(ctx, input)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to get markers: %w", err)
	}

	return markers, nil
}

func (h *Handlers) getProjectClusterMarkers(ctx context.Context, input *GetMarkersInput) ([]template.Marker, error) {
	var markers []template.Marker
	if input.DonorID == "" {
		rows, err := h.queries.GetTreesByProjectCluster(ctx, db.GetTreesByProjectClusterParams{
			SouthLat: input.South,
			NorthLat: input.North,
			WestLng:  input.West,
			EastLng:  input.East,
		})
		if err != nil {
			return nil, err
		}

		markers = make([]template.Marker, 0, len(rows))
		for _, row := range rows {
			markers = append(markers, template.Marker{
				Type:  template.MarkerTypeProjectCluster,
				Lat:   row.CenterLat,
				Lng:   row.CenterLng,
				Count: row.TreeCount,
				ID:    row.ProjectCode,
				Label: row.ProjectName,
			})
		}
	} else {
		rows, err := h.queries.GetDonorTreesByProjectCluster(ctx, db.GetDonorTreesByProjectClusterParams{
			SouthLat: input.South,
			NorthLat: input.North,
			WestLng:  input.West,
			EastLng:  input.East,
			DonorID:  input.DonorID,
		})
		if err != nil {
			return nil, err
		}

		markers = make([]template.Marker, 0, len(rows))
		for _, row := range rows {
			markers = append(markers, template.Marker{
				Type:  template.MarkerTypeProjectCluster,
				Lat:   row.CenterLat,
				Lng:   row.CenterLng,
				Count: row.TreeCount,
				ID:    row.ProjectCode,
				Label: row.ProjectName,
			})
		}
	}

	return markers, nil
}

func (h *Handlers) getGridClusterMarkers(ctx context.Context, input *GetMarkersInput) ([]template.Marker, error) {
	gridSize := calculateGridSize(input.Zoom)

	var markers []template.Marker

	if input.DonorID == "" {
		rows, err := h.queries.GetTreesByGridCluster(ctx, db.GetTreesByGridClusterParams{
			SouthLat: input.South,
			NorthLat: input.North,
			WestLng:  input.West,
			EastLng:  input.East,
			GridSize: gridSize,
		})
		if err != nil {
			return nil, err
		}
		markers = make([]template.Marker, 0, len(rows))
		for _, row := range rows {
			markers = append(markers, template.Marker{
				Type:    template.MarkerTypeGridCluster,
				Lat:     row.GridLat,
				Lng:     row.GridLng,
				Count:   row.TreeCount,
				TreeIDs: row.TreeIds,
			})
		}
	} else {
		rows, err := h.queries.GetDonorTreesByGridCluster(ctx, db.GetDonorTreesByGridClusterParams{
			SouthLat: input.South,
			NorthLat: input.North,
			WestLng:  input.West,
			EastLng:  input.East,
			GridSize: gridSize,
			DonorID:  input.DonorID,
		})
		if err != nil {
			return nil, err
		}
		markers = make([]template.Marker, 0, len(rows))
		for _, row := range rows {
			markers = append(markers, template.Marker{
				Type:    template.MarkerTypeGridCluster,
				Lat:     row.GridLat,
				Lng:     row.GridLng,
				Count:   row.TreeCount,
				TreeIDs: row.TreeIds,
			})
		}
	}

	return markers, nil
}

func (h *Handlers) getIndividualTreeMarkers(ctx context.Context, input *GetMarkersInput) ([]template.Marker, error) {
	var markers []template.Marker
	if input.DonorID == "" {
		trees, err := h.queries.GetIndividualTrees(ctx, db.GetIndividualTreesParams{
			SouthLat:    input.South,
			NorthLat:    input.North,
			WestLng:     input.West,
			EastLng:     input.East,
			ResultLimit: 1000,
		})
		if err != nil {
			return nil, err
		}

		markers = make([]template.Marker, 0, len(trees))
		for _, tree := range trees {
			markers = append(markers, template.Marker{
				Type:  template.MarkerTypeTree,
				Lat:   tree.Latitude,
				Lng:   tree.Longitude,
				ID:    tree.ID,
				Label: fmt.Sprintf("Tree #%d - %s", tree.TreeNumber, tree.ProjectName),
			})
		}
	} else {
		trees, err := h.queries.GetDonorIndividualTrees(ctx, db.GetDonorIndividualTreesParams{
			SouthLat:    input.South,
			NorthLat:    input.North,
			WestLng:     input.West,
			EastLng:     input.East,
			DonorID:     input.DonorID,
			ResultLimit: 1000,
		})
		if err != nil {
			return nil, err
		}

		markers = make([]template.Marker, 0, len(trees))
		for _, tree := range trees {
			markers = append(markers, template.Marker{
				Type:  template.MarkerTypeTree,
				Lat:   tree.Latitude,
				Lng:   tree.Longitude,
				ID:    tree.ID,
				Label: fmt.Sprintf("Tree #%d - %s", tree.TreeNumber, tree.ProjectName),
			})
		}
	}

	return markers, nil
}

func (h *Handlers) GetTreeDetail(ctx context.Context, treeID string) (*template.TreeDetail, error) {
	tree, err := h.queries.GetTreeByID(ctx, treeID)
	if err != nil {
		return nil, fmt.Errorf("failed to get tree detail: %w", err)
	}

	var metadata map[string]interface{}
	if err := json.Unmarshal(tree.Metadata, &metadata); err != nil {
		return nil, fmt.Errorf("failed to parse tree metadata: %w", err)
	}

	output := template.TreeDetail{
		ID:          tree.ID,
		ProjectCode: tree.ProjectCode,
		ProjectName: tree.ProjectName,
		TreeNumber:  tree.TreeNumber,
		DonorName:   tree.DonorName,
		Latitude:    tree.Latitude,
		Longitude:   tree.Longitude,
		Metadata:    metadata,
	}

	latestTreeUpdate, err := h.queries.GetLatestTreeUpdateFile(ctx, treeID)
	if err != nil && err != pgx.ErrNoRows {
		return nil, fmt.Errorf("failed to get latest tree update file: %w", err)
	}
	if err == nil && latestTreeUpdate.FileUrl.Valid && latestTreeUpdate.UpdateDate.Valid {
		output.ImageURL = &latestTreeUpdate.FileUrl.String
		output.ImageTakenAt = &latestTreeUpdate.UpdateDate.Time
	}

	if tree.PlantedAt.Valid {
		output.PlantedAt = tree.PlantedAt.Time
	}
	if tree.CreatedAt.Valid {
		output.CreatedAt = tree.CreatedAt.Time
	}

	return &output, nil
}

func (h *Handlers) GetClusterDetail(ctx context.Context, projectCode string) (*template.ClusterDetail, error) {
	output := &template.ClusterDetail{}

	cluster, err := h.queries.GetClusterDetail(ctx, projectCode)
	if err != nil {
		return nil, fmt.Errorf("failed to get cluster detail: %w", err)
	}

	if cluster.ProjectMetadata != nil {
		err := json.Unmarshal(cluster.ProjectMetadata, &output.ProjectMetadata)
		if err != nil {
			return nil, fmt.Errorf("failed to parse project metadata: %w", err)
		}
	}
	output.ProjectCode = cluster.ProjectCode
	output.ProjectName = cluster.ProjectName
	output.TreeCount = cluster.TreeCount
	output.CenterLat = cluster.CenterLat
	output.CenterLng = cluster.CenterLng
	output.UniqueDonors = cluster.UniqueDonors
	if cluster.FirstPlanted.Valid {
		output.FirstPlanted = &cluster.FirstPlanted.Time
	}
	if cluster.LastPlanted.Valid {
		output.LastPlanted = &cluster.LastPlanted.Time
	}

	return output, nil
}

func calculateGridSize(zoom int) float64 {
	gridSize := 0.1 / math.Pow(2, float64(zoom-8))

	if gridSize < 0.001 {
		gridSize = 0.001
	}
	if gridSize > 0.1 {
		gridSize = 0.1
	}

	return gridSize
}

func GetAdminPage(ctx context.Context, input *AdminPageInput) (*html.HTMLResponse, error) {
	return html.CreateHTMLResponse(ctx, template.SadbhavanaAdminPage(input.BannerMsg))
}

func SearchProjects(ctx context.Context, input *ProjectSearchInput) (*html.HTMLResponse, error) {
	query := input.ProjectSearch

	if query == "" {
		return html.CreateHTMLResponse(ctx, templ.Raw(""))
	}

	q, err := db.NewQueries(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize database queries: %w", err)
	}

	dbProjects, err := q.SearchProjects(ctx, pgtype.Text{String: query, Valid: true})
	if err != nil {
		return nil, fmt.Errorf("failed to search projects: %w", err)
	}

	projects := make([]template.Project, 0, len(dbProjects))
	for _, p := range dbProjects {
		projects = append(projects, template.Project{
			Code: p.ProjectCode,
			Name: p.ProjectName,
		})
	}

	return html.CreateHTMLResponse(ctx, template.ProjectSearchResults(projects))
}

// POST /api/projects - Creates a new project
func CreateProject(ctx context.Context, input *CreateProjectInput) (*RedirectResponse, error) {
	metadata := make(map[string]string)
	for i := 0; i < len(input.Body.MetadataKeys) && i < len(input.Body.MetadataValues); i++ {
		metadata[input.Body.MetadataKeys[i]] = input.Body.MetadataValues[i]
	}

	metadataJSON, err := json.Marshal(metadata)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal project metadata: %w", err)
	}

	q, tx, err := db.NewQueriesWithTx(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get database queries: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = q.CreateProject(ctx, db.CreateProjectParams{
		ProjectCode: strings.ToUpper(input.Body.Code),
		ProjectName: input.Body.Name,
		Metadata:    metadataJSON,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create project: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	msg := fmt.Sprintf("Project '%s' created successfully!", input.Body.Name)

	return &RedirectResponse{
		HXRedirect: "/admin?banner_msg=" + url.QueryEscape(msg),
	}, nil
}

// POST /api/donors - Creates a new donor
func CreateDonor(ctx context.Context, input *CreateDonorInput) (*RedirectResponse, error) {
	// TODO: Save donor to database
	q, tx, err := db.NewQueriesWithTx(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get database queries: %w", err)
	}
	defer tx.Rollback(ctx)

	//Normalize phone number before saving
	number, err := utils.NormalizePhoneNumber(input.Body.Phone)
	if err != nil {
		return nil, fmt.Errorf("failed to normalize phone number: %w", err)
	}

	_, err = q.CreateDonor(ctx, db.CreateDonorParams{
		DonorName:   input.Body.Name,
		PhoneNumber: number,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create donor: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	msg := fmt.Sprintf("Donor '%s' created successfully!", input.Body.Name)

	return &RedirectResponse{
		HXRedirect: "/admin?banner_msg=" + url.QueryEscape(msg),
	}, nil
}

// GET /api/donors/search - Searches donors by name
func SearchDonors(ctx context.Context, input *DonorSearchInput) (*html.HTMLResponse, error) {
	query := input.DonorSearch

	if query == "" {
		return html.CreateHTMLResponse(ctx, templ.Raw(""))
	}

	q, err := db.NewQueries(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize database queries: %w", err)
	}

	dbDonors, err := q.SearchDonors(ctx, pgtype.Text{String: query, Valid: true})
	if err != nil {
		return nil, fmt.Errorf("failed to search donors: %w", err)
	}

	donors := make([]template.Donor, 0, len(dbDonors))
	for _, d := range dbDonors {
		donors = append(donors, template.Donor{
			ID:   d.ID,
			Name: d.DonorName,
		})
	}

	return html.CreateHTMLResponse(ctx, template.DonorSearchResults(donors))
}

// POST /api/trees - Creates a new tree
func CreateTree(ctx context.Context, input *CreateTreeInput) (*RedirectResponse, error) {
	// TODO: Save tree to database

	metadata := make(map[string]string)
	for i := 0; i < len(input.Body.MetadataKeys) && i < len(input.Body.MetadataValues); i++ {
		metadata[input.Body.MetadataKeys[i]] = input.Body.MetadataValues[i]
	}

	metadataJSON, err := json.Marshal(metadata)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal project metadata: %w", err)
	}
	var plantedAt pgtype.Timestamptz
	if input.Body.DatePlanted != "" {
		plantedAt.Time, err = time.Parse("2006-01-02", input.Body.DatePlanted)
		if err != nil {
			return nil, fmt.Errorf("failed to parse date planted: %w", err)
		} else {
			plantedAt.Valid = true
		}
	}
	q, tx, err := db.NewQueriesWithTx(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get database queries: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = q.CreateTree(ctx, db.CreateTreeParams{
		ProjectCode:   strings.ToUpper(input.Body.ProjectCode),
		TreeNumber:    int32(input.Body.TreeNumber),
		DonorID:       input.Body.DonorID,
		StMakepoint:   input.Body.Longitude,
		StMakepoint_2: input.Body.Latitude,
		PlantedAt:     plantedAt,
		Metadata:      metadataJSON,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create tree: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	msg := fmt.Sprintf("Tree #%d created successfully!", input.Body.TreeNumber)

	return &RedirectResponse{
		HXRedirect: "/admin?banner_msg=" + url.QueryEscape(msg),
	}, nil
}
