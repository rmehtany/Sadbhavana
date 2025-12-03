package db

import "context"

type GetTreesByGridClusterInput struct {
	Zoom     int     `json:"zoom" validate:"required,min=0,max=22"`
	EastLng  float64 `json:"east_lng" validate:"required,min=-180,max=180"`
	WestLng  float64 `json:"west_lng" validate:"required,min=-180,max=180"`
	SouthLat float64 `json:"south_lat" validate:"required,min=-90,max=90"`
	NorthLat float64 `json:"north_lat" validate:"required,min=-90,max=90"`
}

type GetTreesByGridClusterOutput struct {
	Clusters []GridTreeCluster `json:"clusters"`
}

type GridTreeCluster struct {
	GridLng   float64  `json:"grid_lng" validate:"required,min=-180,max=180"`
	GridLat   float64  `json:"grid_lat" validate:"required,min=-90,max=90"`
	TreeCount int64    `json:"tree_count"`
	TreeIDs   []string `json:"tree_ids"`
}

func GetTreesByGridCluster(ctx context.Context, q *Queries, input GetTreesByGridClusterInput) (GetTreesByGridClusterOutput, error) {
	return callProcedureWithJSON[GetTreesByGridClusterInput, GetTreesByGridClusterOutput](ctx, q, "core.P_GetTreesByGridCluster", input)
}

type GetTreesByProjectClusterInput struct {
	EastLng  float64 `json:"east_lng" validate:"required,min=-180,max=180"`
	WestLng  float64 `json:"west_lng" validate:"required,min=-180,max=180"`
	SouthLat float64 `json:"south_lat" validate:"required,min=-90,max=90"`
	NorthLat float64 `json:"north_lat" validate:"required,min=-90,max=90"`
}

type ProjectTreeCluster struct {
	ProjectCode string  `json:"project_code" validate:"required"`
	ProjectName string  `json:"project_name" validate:"required"`
	TreeCount   int64   `json:"tree_count" validate:"required,min=0"`
	CenterLat   float64 `json:"center_lat" validate:"required,min=-90,max=90"`
	CenterLng   float64 `json:"center_lng" validate:"required,min=-180,max=180"`
}

type GetTreesByProjectClusterOutput struct {
	Clusters []ProjectTreeCluster `json:"clusters"`
}

func GetTreesByProjectCluster(ctx context.Context, q *Queries, input GetTreesByProjectClusterInput) (GetTreesByProjectClusterOutput, error) {
	return callProcedureWithJSON[GetTreesByProjectClusterInput, GetTreesByProjectClusterOutput](ctx, q, "core.P_GetTreesByProjectCluster", input)
}
