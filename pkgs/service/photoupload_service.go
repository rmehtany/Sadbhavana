package service

import (
	"context"
	"fmt"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/file"
	"sadbhavana/tree-project/pkgs/whatsapp"
	"time"

	"github.com/juju/errors"
	"google.golang.org/api/drive/v3"
)

func PhotoDetectionAndStorage(ctx context.Context) error {
	fmt.Printf("Inside the service starting point %v\n", time.Now())
	q, tx, err := db.NewQueriesWithTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to get database queries: %w", err)
	}
	defer tx.Rollback(ctx)
	fileStore, err := file.NewUpdatedGoogleDriveFileStore(ctx, q)
	if err != nil {
		return fmt.Errorf("failed to create Google Drive file store: %w", err)
	}
	query := "name='SampleTreePhotos' and mimeType='application/vnd.google-apps.folder' and trashed=false"
	folderList, err := fileStore.Service.Files.List().Q(query).Do()

	if err != nil {
		return fmt.Errorf("failed to list folders from Google Drive: %w", err)
	}
	if len(folderList.Files) == 0 {
		return fmt.Errorf("folder 'SampleTreePhotos' not found in Google Drive")
	}
	fmt.Println("folderList size is", len(folderList.Files))
	treePhotosFolder := folderList.Files[0]
	fmt.Printf("Found folder: %s (ID: %s)\n", treePhotosFolder.Name, treePhotosFolder.Id)
	//Fetch photos in batches, extract treeId using Gemini LLM and update database with treeId and photo details
	fmt.Printf("Before tree detection time is %v\n", time.Now())
	fileInfoMap, error := whatsapp.FinalExtractImageDataFromFolderInfoList(ctx, q, treePhotosFolder, fileStore)
	if error != nil {
		fmt.Printf("Able to extract treeData for images of size %d\n", len(fileInfoMap))
		treePhotoInput := CreatePhotoUploadData(ctx, q, fileInfoMap, fileStore.ProviderType)
		fmt.Println("treePhotoInput is", treePhotoInput)
		// treePhotoResponse, err := db.SaveTreePhoto(ctx, q, treePhotoInput)
		// if err != nil {
		// 	return errors.Annotatef(err, "failed to save tree photo")
		// }
		// fmt.Print("treePhotoResponse is", treePhotoResponse)
		// RenameFiles(ctx, q, fileInfoMap, fileStore)
		return errors.Annotatef(error, "failed to extract image data from folder info list")
	}
	fmt.Printf("Able to extract treeData for images of size %d, time is %v\n", len(fileInfoMap), time.Now())
	treePhotoInput := CreatePhotoUploadData(ctx, q, fileInfoMap, fileStore.ProviderType)
	fmt.Println("treePhotoInput is", treePhotoInput)
	fmt.Printf("Before saving and after treeId detection, time is %v\n", time.Now())
	treePhotoResponse, err := db.SaveTreePhoto(ctx, q, treePhotoInput)

	if err != nil {
		return errors.Annotatef(err, "failed to save tree photo")
	}
	tx.Commit(ctx)
	fmt.Print("treePhotoResponse is", treePhotoResponse)
	fmt.Printf("after saving and before renaming, time is %v\n", time.Now())
	RenameFiles(ctx, q, fileInfoMap, fileStore)
	fmt.Printf("after renaming, time is %v\n", time.Now())
	return nil
}

func RenameFiles(ctx context.Context, q *db.Queries, fileInfoMap map[string]whatsapp.ImageInfo, fileStore *file.UpdatedGoogleDriveFileStore) error {
	fmt.Print("Renaming files start : current time is ", time.Now())
	for _, image := range fileInfoMap {
		if image.TreeID != "" {
			updateFile := &drive.File{Name: image.Name}
			_, err := fileStore.Service.Files.Update(image.ID, updateFile).Do()

			if err != nil {
				return fmt.Errorf("failed to rename file %s: %w", image.Name, err)
			}
		}
	}
	fmt.Print("Renaming files end : current time is ", time.Now())
	return nil
}
