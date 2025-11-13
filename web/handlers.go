package web

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"

	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/template"
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
	log.Printf("DonorID: %s", input.DonorID)
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

	log.Printf("DonorID: %s", input.DonorID)

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
	log.Printf("DonorID: %s", input.DonorID)
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
