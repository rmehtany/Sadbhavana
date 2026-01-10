package file

import (
	"context"
	"fmt"
	"io"

	"sadbhavana/tree-project/pkgs/db"
)

type FileStore interface {
	ListFiles(ctx context.Context, folder FolderInfo) ([]FileInfo, error)
	UploadFile(ctx context.Context, fileName string, fileType MimeType, folderInfo FolderInfo, data io.Reader) (FileInfo, error)
	DownloadFile(ctx context.Context, file FileInfo) (io.Reader, func(), error)
	DeleteFile(ctx context.Context, file FileInfo) error
}

func DownloadFile(ctx context.Context, q *db.Queries, fileInfo FileInfo) (io.Reader, func(), error) {
	var store FileStore
	var err error
	switch fileInfo.FileStore {
	case "local":
		store = NewLocalFileStore()
	case "google":
		store, err = NewGoogleDriveFileStore(ctx, q)
		if err != nil {
			return nil, nil, err
		}
	}
	if store == nil {
		return nil, nil, fmt.Errorf("no file store available for type %s", fileInfo.FileStore)
	}
	return store.DownloadFile(ctx, fileInfo)
}

func NewFileStore(storeType string, config map[string]string) (FileStore, error) {
	switch storeType {
	case "local":
		return NewLocalFileStore(), nil
	case "google":
		// Caller should use NewGoogleDriveFileStore directly when DB Queries are required.
		return nil, fmt.Errorf("google file store must be created with NewGoogleDriveFileStore(ctx, q)")
	default:
		return nil, fmt.Errorf("unsupported file store type: %s", storeType)
	}
}
