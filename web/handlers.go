package web

import (
	"context"
	"encoding/json"
	"fmt"
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
		markers, err = h.getTownClusterMarkers(ctx, input)
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

func (h *Handlers) getTownClusterMarkers(ctx context.Context, input *GetMarkersInput) ([]template.Marker, error) {
	rows, err := h.queries.GetTreesByTownCluster(ctx, db.GetTreesByTownClusterParams{
		SouthLat: input.South,
		NorthLat: input.North,
		WestLng:  input.West,
		EastLng:  input.East,
	})
	if err != nil {
		return nil, err
	}

	markers := make([]template.Marker, 0, len(rows))
	for _, row := range rows {
		markers = append(markers, template.Marker{
			Type:  template.MarkerTypeTownCluster,
			Lat:   row.CenterLat,
			Lng:   row.CenterLng,
			Count: row.TreeCount,
			ID:    row.TownCode,
			Label: row.TownName,
		})
	}

	return markers, nil
}

func (h *Handlers) getGridClusterMarkers(ctx context.Context, input *GetMarkersInput) ([]template.Marker, error) {
	gridSize := calculateGridSize(input.Zoom)

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

	markers := make([]template.Marker, 0, len(rows))
	for _, row := range rows {
		markers = append(markers, template.Marker{
			Type:    template.MarkerTypeGridCluster,
			Lat:     row.GridLat,
			Lng:     row.GridLng,
			Count:   row.TreeCount,
			TreeIDs: row.TreeIds,
		})
	}

	return markers, nil
}

func (h *Handlers) getIndividualTreeMarkers(ctx context.Context, input *GetMarkersInput) ([]template.Marker, error) {
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

	markers := make([]template.Marker, 0, len(trees))
	for _, tree := range trees {
		markers = append(markers, template.Marker{
			Type:  template.MarkerTypeTree,
			Lat:   tree.Latitude,
			Lng:   tree.Longitude,
			ID:    tree.ID,
			Label: fmt.Sprintf("Tree #%d - %s", tree.TreeNumber, tree.TownName),
		})
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
		ID:         tree.ID,
		TownCode:   tree.TownCode,
		TownName:   tree.TownName,
		TreeNumber: tree.TreeNumber,
		DonorName:  tree.DonorName,
		Latitude:   tree.Latitude,
		Longitude:  tree.Longitude,
		Metadata:   metadata,
	}
	if tree.PlantedAt.Valid {
		output.PlantedAt = tree.PlantedAt.Time
	}
	if tree.CreatedAt.Valid {
		output.CreatedAt = tree.CreatedAt.Time
	}

	return &output, nil
}

func (h *Handlers) GetClusterDetail(ctx context.Context, townCode string) (*template.ClusterDetail, error) {
	cluster, err := h.queries.GetClusterDetail(ctx, townCode)
	if err != nil {
		return nil, fmt.Errorf("failed to get cluster detail: %w", err)
	}

	var townMetadata map[string]interface{}
	if cluster.TownMetadata != nil {
		if err := json.Unmarshal(cluster.TownMetadata, &townMetadata); err != nil {
			return nil, fmt.Errorf("failed to parse town metadata: %w", err)
		}
	}

	output := template.ClusterDetail{
		TownCode:     cluster.TownCode,
		TownName:     cluster.TownName,
		TreeCount:    cluster.TreeCount,
		CenterLat:    cluster.CenterLat,
		CenterLng:    cluster.CenterLng,
		UniqueDonors: cluster.UniqueDonors,
		TownMetadata: townMetadata,
	}
	if cluster.FirstPlanted.Valid {
		output.FirstPlanted = &cluster.FirstPlanted.Time
	}
	if cluster.LastPlanted.Valid {
		output.LastPlanted = &cluster.LastPlanted.Time
	}

	return &output, nil
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
