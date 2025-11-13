package web

import (
	"sadbhavana/tree-project/pkgs/template"
	"time"
)

// GetMarkersInput defines the viewport bounds and zoom level for marker queries
type GetMarkersInput struct {
	North   float64 `query:"north" minimum:"-90" maximum:"90"`
	South   float64 `query:"south" minimum:"-90" maximum:"90"`
	East    float64 `query:"east" minimum:"-180" maximum:"180"`
	West    float64 `query:"west" minimum:"-180" maximum:"180"`
	Zoom    int     `query:"zoom" minimum:"1" maximum:"20"`
	DonorID string  `query:"donorId,omitempty"`
}

// GetTreeDetailInput defines the tree ID parameter
type GetTreeDetailInput struct {
	ID string `path:"id" minLength:"21" maxLength:"21" pattern:"^TRE_[A-Za-z0-9_-]{17}$"`
}

// GetClusterDetailInput defines the project code parameter
type GetClusterDetailInput struct {
	ProjectCode string `path:"projectCode" minLength:"2" maxLength:"2"`
	DonorID     string `query:"donorId,omitempty"`
}

// MarkerType represents the type of marker being returned
type MarkerType string

const (
	MarkerTypeProjectCluster MarkerType = "project-cluster"
	MarkerTypeGridCluster    MarkerType = "grid-cluster"
	MarkerTypeTree           MarkerType = "tree"
)

// Marker represents a unified marker structure for all zoom levels
type Marker struct {
	Type    MarkerType `json:"type"`
	Lat     float64    `json:"lat"`
	Lng     float64    `json:"lng"`
	Count   int64      `json:"count,omitempty"`   // For clusters
	ID      string     `json:"id,omitempty"`      // For trees or project code
	Label   string     `json:"label,omitempty"`   // Display name
	TreeIDs []string   `json:"treeIds,omitempty"` // For grid clusters
}

// TreeDetail represents detailed information about a single tree
type TreeDetail struct {
	ID          string                 `json:"id"`
	ProjectCode string                 `json:"projectCode"`
	ProjectName string                 `json:"projectName"`
	TreeNumber  int32                  `json:"treeNumber"`
	DonorID     string                 `json:"donorId"`
	DonorName   string                 `json:"donorName"`
	Latitude    float64                `json:"latitude"`
	Longitude   float64                `json:"longitude"`
	PlantedAt   *time.Time             `json:"plantedAt,omitempty"`
	CreatedAt   *time.Time             `json:"createdAt,omitempty"`
	Metadata    map[string]interface{} `json:"metadata"`
}

// ClusterDetail represents detailed information about a project cluster
type ClusterDetail struct {
	ProjectCode     string                 `json:"projectCode"`
	ProjectName     string                 `json:"projectName"`
	TreeCount       int64                  `json:"treeCount"`
	CenterLat       float64                `json:"centerLat"`
	CenterLng       float64                `json:"centerLng"`
	FirstPlanted    *time.Time             `json:"firstPlanted,omitempty"`
	LastPlanted     *time.Time             `json:"lastPlanted,omitempty"`
	UniqueDonors    int64                  `json:"uniqueDonors"`
	ProjectMetadata map[string]interface{} `json:"projectMetadata"`
}

// MarkersResponse wraps the markers array for HTML rendering
type MarkersResponse struct {
	Markers []Marker `json:"markers"`
	Zoom    int      `json:"zoom"`
}

type ClusterDetailRawResponse struct {
	Body template.ClusterDetail `json:"body"`
}
