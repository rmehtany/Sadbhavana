package db

import "context"

type GetProjectInput struct {
	ProjectPattern string `json:"project_pattern,omitempty"`
}

type DbProject struct {
	ProjectIdn     int            `json:"project_idn" validate:"required"`
	ProjectId      string         `json:"project_id" validate:"required"`
	ProjectName    string         `json:"project_name" validate:"required"`
	StartDt        string         `json:"start_dt" validate:"required"`
	TreeCntPledged int            `json:"tree_cnt_pledged" validate:"required"`
	TreeCntPlanted int            `json:"tree_cnt_planted" validate:"required"`
	Latitude       float64        `json:"latitude" validate:"required"`
	Longitude      float64        `json:"longitude" validate:"required"`
	PropertyList   map[string]any `json:"property_list"`
}

func GetProject(ctx context.Context, q *Queries, input GetProjectInput) ([]DbProject, error) {
	return callDbApi[GetProjectInput, []DbProject](ctx, q, "GetProject", input)
}

type SaveProjectInput struct {
	ProjectIdn     int            `json:"project_idn" validate:"optional"`
	ProjectId      string         `json:"project_id" validate:"required"`
	ProjectName    string         `json:"project_name" validate:"required"`
	StartDt        string         `json:"start_dt,omitempty"`
	TreeCntPledged int            `json:"tree_cnt_pledged,omitempty"`
	TreeCntPlanted int            `json:"tree_cnt_planted,omitempty"`
	Latitude       float64        `json:"latitude" validate:"required"`
	Longitude      float64        `json:"longitude" validate:"required"`
	PropertyList   map[string]any `json:"property_list,omitempty"`
}

func SaveProject(ctx context.Context, q *Queries, input []SaveProjectInput) ([]DbProject, error) {
	return callDbApi[[]SaveProjectInput, []DbProject](ctx, q, "SaveProject", input)
}

type DeleteProjectInput struct {
	ProjectIdn string `json:"project_idn" validate:"required"`
}

func DeleteProject(ctx context.Context, q *Queries, input []DeleteProjectInput) ([]DbProject, error) {
	return callDbApi[[]DeleteProjectInput, []DbProject](ctx, q, "DeleteProject", input)
}
