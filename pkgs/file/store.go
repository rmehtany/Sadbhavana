package file

import (
	"context"
	"fmt"
	"io"
)

type FileStore interface {
	ListFiles(ctx context.Context, folder FolderInfo) ([]FileInfo, error)
	UploadFile(ctx context.Context, file FileInfo, data io.Reader) (FileInfo, error)
	DownloadFile(ctx context.Context, file FileInfo) (io.Reader, func(), error)
	DeleteFile(ctx context.Context, file FileInfo) error
}

func DownloadFile(ctx context.Context, fileInfo FileInfo) (io.Reader, func(), error) {
	var store FileStore
	switch fileInfo.FileStore {
	case "local":
		store = NewLocalFileStore()
	}
	return store.DownloadFile(ctx, fileInfo)
}

func NewFileStore(storeType string, config map[string]string) (FileStore, error) {
	switch storeType {
	case "local":
		return NewLocalFileStore(), nil
	default:
		return nil, fmt.Errorf("unsupported file store type: %s", storeType)
	}
}
