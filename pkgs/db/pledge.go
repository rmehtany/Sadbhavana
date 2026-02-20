package db

import "context"

type GetPledgeInput struct {
	DonorIdn   int `json:"donor_idn,omitempty"`
	ProjectIdn int `json:"project_idn,omitempty"`
}

type DbPledge struct {
	PledgeIdn      int            `json:"pledge_idn"`
	ProjectIdn     int            `json:"project_idn"`
	DonorIdn       int            `json:"donor_idn"`
	PledgeTs       string         `json:"pledge_ts"`
	TreeCntPledged int            `json:"tree_cnt_pledged"`
	TreeCntPlanted int            `json:"tree_cnt_planted"`
	PledgeCredit   map[string]any `json:"pledge_credit"`
	PropertyList   map[string]any `json:"property_list"`
}

func GetPledge(ctx context.Context, q *Queries, input GetPledgeInput) ([]DbPledge, error) {
	return callDbApi[GetPledgeInput, []DbPledge](ctx, q, "GetPledge", input)
}

type SavePledgeInput struct {
	PledgeIdn      int            `json:"pledge_idn,omitempty"`
	ProjectIdn     int            `json:"project_idn"`
	DonorIdn       int            `json:"donor_idn"`
	PledgeTs       string         `json:"pledge_ts,omitempty"`
	TreeCntPledged int            `json:"tree_cnt_pledged"`
	TreeCntPlanted int            `json:"tree_cnt_planted"`
	PledgeCredit   map[string]any `json:"pledge_credit,omitempty"`
	PropertyList   map[string]any `json:"property_list,omitempty"`
}

func SavePledge(ctx context.Context, q *Queries, input []SavePledgeInput) ([]DbPledge, error) {
	return callDbApi[[]SavePledgeInput, []DbPledge](ctx, q, "SavePledge", input)
}

type DeletePledgeInput struct {
	PledgeIdn int `json:"pledge_idn"`
}

type DeletePledgeRequest struct {
	Cascade bool                `json:"cascade,omitempty"`
	Pledges []DeletePledgeInput `json:"pledges"`
}

func DeletePledge(ctx context.Context, q *Queries, input DeletePledgeRequest) ([]DbPledge, error) {
	return callDbApi[DeletePledgeRequest, []DbPledge](ctx, q, "DeletePledge", input)
}
