package service

import (
	"context"
	"fmt"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/providers"
	"sadbhavana/tree-project/pkgs/whatsapp"
	"time"
)

func CreatePhotoUploadData(ctx context.Context, q *db.Queries, fileInfoMap map[string]whatsapp.ImageInfo, providerType providers.ProviderType) []db.SaveTreePhotoInput {
	mappedData := make([]db.SaveTreePhotoInput, 0, len(fileInfoMap))
	for key, value := range fileInfoMap {
		if value.TreeID == "" {
			continue
		}
		mappedData = append(mappedData, db.SaveTreePhotoInput{
			TreeId:            value.TreeID,
			ProviderName:      string(providerType),
			FileStoreId:       key,
			FilePath:          value.Path,
			FileName:          value.Name,
			FileType:          value.MimeType,
			PhotoTs:           value.PhotoTime.Format("2006-01-02 15:04:05"),
			PhotoLatitude:     value.Latitude,
			PhotoLongitude:    value.Longitude,
			PhotoPropertyList: nil,
			UploadTs:          time.Now().Format("2006-01-02 15:04:05"),
		})
	}
	fmt.Printf("MappedData size is %d\n", len(mappedData))
	return mappedData
}
