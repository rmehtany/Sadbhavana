package db

import "context"

type GetTreeClustersInput struct {
	Zoom      int     `json:"zoom" validate:"required,min=0,max=22"`
	East_Lng  float64 `json:"east_lng" validate:"required,min=-180,max=180"`
	West_Lng  float64 `json:"west_lng" validate:"required,min=-180,max=180"`
	South_Lat float64 `json:"south_lat" validate:"required,min=-90,max=90"`
	North_Lat float64 `json:"north_lat" validate:"required,min=-90,max=90"`
}

type GetTreeClustersOutput struct {
	Clusters []TreeCluster `json:"clusters"`
}

type TreeCluster struct {
	Grid_Lng  float64  `json:"grid_lng" validate:"required,min=-180,max=180"`
	Grid_Lat  float64  `json:"grid_lat" validate:"required,min=-90,max=90"`
	TreeCount int64    `json:"tree_count"`
	TreeIDs   []string `json:"tree_ids"`
}

func GetTreeClusters(ctx context.Context, q *Queries, input GetTreeClustersInput) (GetTreeClustersOutput, error) {
	return callProcedureWithJSON[GetTreeClustersInput, GetTreeClustersOutput](ctx, q, "P_GetTreeClusters", input)
}
