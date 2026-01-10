package file

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// LocalFileStore implements FileStore using the local filesystem
type LocalFileStore struct {
	Root string
}

// ensureRoot ensures the root folder exists
func (l *LocalFileStore) ensureRoot() error {
	return os.MkdirAll(l.Root, 0755)
}

// ListFiles lists files in a given folder
func (l *LocalFileStore) ListFiles(ctx context.Context, folder FolderInfo) ([]FileInfo, error) {
	if err := l.ensureRoot(); err != nil {
		return nil, err
	}

	folderPath := filepath.Join(l.Root, folder.FolderPath)
	entries, err := os.ReadDir(folderPath)
	if err != nil {
		return nil, err
	}

	var files []FileInfo
	for _, e := range entries {
		info, err := e.Info()
		if err != nil {
			continue
		}
		mime, _ := FromExtension(filepath.Ext(e.Name()))
		files = append(files, FileInfo{
			FileStore: "local",
			FilePath:  filepath.Join(folder.FolderPath, e.Name()),
			FileName:  e.Name(),
			Size:      info.Size(),
			MimeType:  mime,
		})
	}
	return files, nil
}

// UploadFile saves a file to the local filesystem
func (l *LocalFileStore) UploadFile(ctx context.Context, fileName string, fileType MimeType, folderInfo FolderInfo, data io.Reader) (FileInfo, error) {
	if err := l.ensureRoot(); err != nil {
		return FileInfo{}, err
	}

	var filePath string
	if folderInfo.FolderPath == "" {
		filePath = fileName
	} else {
		filePath = filepath.Join(folderInfo.FolderPath, fileName)
	}
	fullPath := filepath.Join(l.Root, filePath)
	if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
		return FileInfo{}, err
	}

	out, err := os.Create(fullPath)
	if err != nil {
		return FileInfo{}, err
	}
	defer out.Close()

	n, err := io.Copy(out, data)
	if err != nil {
		return FileInfo{}, err
	}

	file := FileInfo{
		FileStore: "local",
		FilePath:  fullPath,
		MimeType:  fileType,
		FileName:  fileName,
		Size:      n,
		FileURL:   fmt.Sprintf("static/%s", filePath),
	}
	return file, nil
}

// DownloadFile opens a file for reading
func (l *LocalFileStore) DownloadFile(ctx context.Context, file FileInfo) (io.Reader, func(), error) {
	fullPath := filepath.Join(l.Root, file.FilePath)
	f, err := os.Open(fullPath)
	if err != nil {
		return nil, nil, err
	}

	// Return file reader and a close function
	closeFn := func() {
		_ = f.Close()
	}
	return f, closeFn, nil
}

// DeleteFile removes a file from the filesystem
func (l *LocalFileStore) DeleteFile(ctx context.Context, file FileInfo) error {
	fullPath := filepath.Join(l.Root, file.FilePath)
	return os.Remove(fullPath)
}

// Example constructor
func NewLocalFileStore() *LocalFileStore {
	return &LocalFileStore{Root: "static"}
}
