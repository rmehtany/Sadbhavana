package db

import "context"

type GetDonorInput struct {
	DonorPattern string `json:"donor_pattern,omitempty"`
}

type DbDonor struct {
	DonorIdn     int            `json:"donor_idn" validate:"required"`
	DonorName    string         `json:"donor_name" validate:"required"`
	MobileNumber string         `json:"mobile_number" validate:"required"`
	City         string         `json:"city" validate:"required"`
	EmailAddr    string         `json:"email_addr" validate:"required"`
	Country      string         `json:"country" validate:"required"`
	BirthDt      string         `json:"birth_dt" validate:"required"`
	PropertyList map[string]any `json:"property_list"`
}

func GetDonor(ctx context.Context, q *Queries, input GetDonorInput) ([]DbDonor, error) {
	return callDbApi[GetDonorInput, []DbDonor](ctx, q, "GetDonor", input)
}
