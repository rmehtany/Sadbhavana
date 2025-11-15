package web

import (
	"mime/multipart"
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
	DonorID string  `query:"donor_id,omitempty"`
}

// GetTreeDetailInput defines the tree ID parameter
type GetTreeDetailInput struct {
	ID string `path:"id" minLength:"21" maxLength:"21" pattern:"^TRE_[A-Za-z0-9_-]{17}$"`
}

// GetClusterDetailInput defines the project code parameter
type GetClusterDetailInput struct {
	ProjectCode string `path:"projectCode" minLength:"2" maxLength:"2"`
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

type AdminPageInput struct {
	BannerMsg string `query:"banner_msg"`
}

type ProjectSearchInput struct {
	ProjectSearch string `query:"project_search"`
}

// Request/Response types for Projects

type CreateProjectInputParsed struct {
	Name           string   `json:"name" form:"name"`
	Code           string   `json:"code" form:"code" pattern:"[A-Za-z]{2}" maxLength:"2" minLength:"2"`
	MetadataKeys   []string `form:"metadata-key[]"`
	MetadataValues []string `form:"metadata-value[]"`
}

type RedirectResponse struct {
	HXRedirect string `header:"HX-Redirect"`
}

// Request/Response types for Donors

type CreateDonorInputParsed struct {
	Name  string `json:"name" form:"name"`
	Phone string `json:"phone" form:"phone"`
}

type DonorSearchInput struct {
	DonorSearch string `query:"donor_search"`
}

// Request/Response types for Trees

type FormInput struct {
	RawBody multipart.Form
}

type CreateTreeInputParsed struct {
	ProjectCode    string   `json:"project_code" form:"project_search"`
	TreeNumber     int      `json:"tree_number" form:"tree_number" minimum:"1"`
	DonorID        string   `json:"donor_id" form:"donor_id"`
	Latitude       float64  `json:"latitude" form:"latitude" minimum:"-90" maximum:"90"`
	Longitude      float64  `json:"longitude" form:"longitude" minimum:"-180" maximum:"180"`
	DatePlanted    string   `json:"date_planted" form:"date_planted"`
	MetadataKeys   []string `form:"metadata-key[]"`
	MetadataValues []string `form:"metadata-value[]"`
}
