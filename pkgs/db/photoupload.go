package db

import (
	"context"
	"fmt"
)

type SaveTreePhotoInput struct {
	TreeId            string         `json:"tree_id" validate:"required"`
	ProviderName      string         `json:"provider_name" validate:"required"`
	FileStoreId       string         `json:"file_store_id" validate:"required"`
	FilePath          string         `json:"file_path" validate:"required"`
	FileName          string         `json:"file_name" validate:"required"`
	FileType          string         `json:"file_type" validate:"required"`
	PhotoTs           string         `json:"photo_ts"`
	PhotoLatitude     float64        `json:"photo_latitude"`
	PhotoLongitude    float64        `json:"photo_longitude"`
	PhotoPropertyList map[string]any `json:"photo_property_list"`
	UploadTs          string         `json:"upload_ts"`
}

type SaveTreePhotoResponse struct {
	FilesCreated    int `json:"files_created"`
	PhotosProcessed int `json:"photos_processed"`
	TotalRecords    int `json:"total_records"`
}

func SaveTreePhoto(ctx context.Context, q *Queries, input []SaveTreePhotoInput) (SaveTreePhotoResponse, error) {
	fmt.Println("input is ", input)
	return callDbApi[[]SaveTreePhotoInput, SaveTreePhotoResponse](ctx, q, "UploadTreePhoto", input)
}
