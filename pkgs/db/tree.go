package db

import (
	"context"
	"time"
)

type GetTreesByGridClusterInput struct {
	DonorID  *string `json:"donor_id,omitempty"`
	Zoom     int     `json:"zoom" validate:"required,min=0,max=22"`
	EastLng  float64 `json:"east_lng" validate:"required,min=-180,max=180"`
	WestLng  float64 `json:"west_lng" validate:"required,min=-180,max=180"`
	SouthLat float64 `json:"south_lat" validate:"required,min=-90,max=90"`
	NorthLat float64 `json:"north_lat" validate:"required,min=-90,max=90"`
}

type GetTreesByGridClusterOutput struct {
	GridLng   float64  `json:"grid_lng" validate:"required,min=-180,max=180"`
	GridLat   float64  `json:"grid_lat" validate:"required,min=-90,max=90"`
	TreeCount int64    `json:"tree_count"`
	TreeIDs   []string `json:"tree_ids"`
}

func GetTreesByGridCluster(ctx context.Context, q *Queries, input GetTreesByGridClusterInput) ([]GetTreesByGridClusterOutput, error) {
	return callProcedureWithJSON[GetTreesByGridClusterInput, []GetTreesByGridClusterOutput](ctx, q, "core", "P_GetTreesByGridCluster", input)
}

type GetTreesByProjectClusterInput struct {
	DonorID  *string `json:"donor_id,omitempty"`
	EastLng  float64 `json:"east_lng" validate:"required,min=-180,max=180"`
	WestLng  float64 `json:"west_lng" validate:"required,min=-180,max=180"`
	SouthLat float64 `json:"south_lat" validate:"required,min=-90,max=90"`
	NorthLat float64 `json:"north_lat" validate:"required,min=-90,max=90"`
}

type GetTreesByProjectClusterOutput struct {
	ProjectCode string  `json:"project_code" validate:"required"`
	ProjectName string  `json:"project_name" validate:"required"`
	TreeCount   int64   `json:"tree_count" validate:"required,min=0"`
	CenterLat   float64 `json:"center_lat" validate:"required,min=-90,max=90"`
	CenterLng   float64 `json:"center_lng" validate:"required,min=-180,max=180"`
}

func GetTreesByProjectCluster(ctx context.Context, q *Queries, input GetTreesByProjectClusterInput) ([]GetTreesByProjectClusterOutput, error) {
	return callProcedureWithJSON[GetTreesByProjectClusterInput, []GetTreesByProjectClusterOutput](ctx, q, "core", "P_GetTreesByProjectCluster", input)
}

type GetIndividualTreesInput struct {
	DonorID  *string `json:"donor_id,omitempty"`
	EastLng  float64 `json:"east_lng" validate:"required,min=-180,max=180"`
	WestLng  float64 `json:"west_lng" validate:"required,min=-180,max=180"`
	SouthLat float64 `json:"south_lat" validate:"required,min=-90,max=90"`
	NorthLat float64 `json:"north_lat" validate:"required,min=-90,max=90"`
}

type GetIndividualTreesOutput struct {
	ID        string  `json:"id" validate:"required"`
	Latitude  float64 `json:"latitude" validate:"required,min=-90,max=90"`
	Longitude float64 `json:"longitude" validate:"required,min=-180,max=180"`
}

func GetIndividualTrees(ctx context.Context, q *Queries, input GetIndividualTreesInput) ([]GetIndividualTreesOutput, error) {
	return callProcedureWithJSON[GetIndividualTreesInput, []GetIndividualTreesOutput](ctx, q, "core", "P_GetIndividualTrees", input)
}

type GetTreeByIDInput struct {
	TreeID string `json:"tree_id" validate:"required"`
}

type GetTreeByIDOutput struct {
	ID               string                 `json:"id" validate:"required"`
	ProjectCode      string                 `json:"project_code" validate:"required"`
	TreeNumber       string                 `json:"tree_number" validate:"required"`
	DonorID          string                 `json:"donor_id" validate:"required"`
	Latitude         float64                `json:"latitude" validate:"required,min=-90,max=90"`
	Longitude        float64                `json:"longitude" validate:"required,min=-180,max=180"`
	PlantedAt        time.Time              `json:"planted_at" validate:"required"`
	CreatedAt        time.Time              `json:"created_at" validate:"required"`
	Metadata         map[string]interface{} `json:"metadata" validate:"required"`
	DonorName        string                 `json:"donor_name" validate:"required"`
	DonorPhoneNumber string                 `json:"donor_phone_number" validate:"required"`
	ProjectName      string                 `json:"project_name" validate:"required"`
	ProjectMetadata  map[string]interface{} `json:"project_metadata" validate:"required"`
}

func GetTreeByID(ctx context.Context, q *Queries, input GetTreeByIDInput) (GetTreeByIDOutput, error) {
	return callProcedureWithJSON[GetTreeByIDInput, GetTreeByIDOutput](ctx, q, "core", "P_GetTreeByID", input)
}
