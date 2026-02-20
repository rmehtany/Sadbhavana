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

type SaveDonorInput struct {
	DonorIdn     int            `json:"donor_idn,omitempty" validate:"optional"`
	DonorName    string         `json:"donor_name" validate:"required"`
	MobileNumber string         `json:"mobile_number" validate:"required"`
	City         string         `json:"city" validate:"required"`
	EmailAddr    string         `json:"email_addr,omitempty" validate:"required"`
	Country      string         `json:"country" validate:"required"`
	BirthDt      string         `json:"birth_dt,omitempty" validate:"required"`
	PropertyList map[string]any `json:"property_list,omitempty"`
}

func SaveDonor(ctx context.Context, q *Queries, input []SaveDonorInput) ([]DbDonor, error) {
	return callDbApi[[]SaveDonorInput, []DbDonor](ctx, q, "SaveDonor", input)
}

type DeleteDonorInput struct {
	DonorIdn int `json:"donor_idn,omitempty" validate:"required"`
}

type DeleteDonorRequest struct {
	Cascade bool               `json:"cascade,omitempty"`
	Donors  []DeleteDonorInput `json:"donors"`
}

func DeleteDonor(ctx context.Context, q *Queries, input DeleteDonorRequest) ([]DbDonor, error) {
	return callDbApi[DeleteDonorRequest, []DbDonor](ctx, q, "DeleteDonor", input)
}

type GetDonorUpdateInput struct {
	BatchSize int `json:"batch_size,omitempty"`
}

type DbDonorUpdate struct {
	Idn                    int            `json:"idn"`
	TreeIdn                int            `json:"tree_idn"`
	TreeId                 string         `json:"tree_id"`
	CreditName             string         `json:"credit_name"`
	UploadTs               string         `json:"upload_ts"`
	DonorName              string         `json:"donor_name"`
	DonorEmail             string         `json:"donor_email"`
	DonorMobile            string         `json:"donor_mobile"`
	ProjectName            string         `json:"project_name"`
	PhotoTs                string         `json:"photo_ts"`
	PhotoLocationLatitude  float64        `json:"photo_location_latitude"`
	PhotoLocationLongitude float64        `json:"photo_location_longitude"`
	FileStoreId            string         `json:"file_store_id"`
	FileName               string         `json:"file_name"`
	FilePath               string         `json:"file_path"`
	FileType               string         `json:"file_type"`
	PropertyList           map[string]any `json:"property_list"`
}

func GetDonorUpdate(ctx context.Context, q *Queries, input GetDonorUpdateInput) ([]DbDonorUpdate, error) {
	return callDbApi[GetDonorUpdateInput, []DbDonorUpdate](ctx, q, "GetDonorUpdate", input)
}

type PostDonorUpdateInput struct {
	Idn        int    `json:"idn" validate:"required"`
	SendStatus string `json:"send_status" validate:"required,oneof=sent failed"`
}

type PostDonorUpdateResponse struct {
	UpdatedCount     int  `json:"updated_count"`
	NewHighWaterMark *int `json:"new_high_water_mark"`
}

func PostDonorUpdate(ctx context.Context, q *Queries, input []PostDonorUpdateInput) (PostDonorUpdateResponse, error) {
	return callDbApi[[]PostDonorUpdateInput, PostDonorUpdateResponse](ctx, q, "PostDonorUpdate", input)
}
