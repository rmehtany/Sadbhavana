package file

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"sadbhavana/tree-project/pkgs/auth"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/providers"

	"golang.org/x/oauth2"
	"google.golang.org/api/drive/v2"
	"google.golang.org/api/option"
)

type GoogleDriveFileStore struct {
	Service *drive.Service
}

func NewGoogleDriveFileStore(ctx context.Context, q *db.Queries) (*GoogleDriveFileStore, error) {
	activeToken, err := auth.GetActiveToken(ctx, q, providers.GOOGLE_PROVIDER)
	if err != nil {
		return nil, err
	}

	client := oauth2.NewClient(ctx, oauth2.StaticTokenSource(&activeToken))
	service, err := drive.NewService(ctx, option.WithHTTPClient(client))
	if err != nil {
		return nil, err
	}

	return &GoogleDriveFileStore{
		Service: service,
	}, nil
}

// ListFiles lists files in the given folder.
func (g *GoogleDriveFileStore) ListFiles(ctx context.Context, folder FolderInfo) ([]FileInfo, error) {
	// default to root if no folder id provided
	folderID := folder.FolderId
	if folderID == "" {
		folderID = "root"
	}

	q := fmt.Sprintf("'%s' in parents and trashed=false", folderID)
	// request a small set of fields
	res, err := g.Service.Files.List().Q(q).Fields("items(id,title,fileSize,mimeType,webContentLink,alternateLink)").Do()
	if err != nil {
		return nil, err
	}

	out := make([]FileInfo, 0, len(res.Items))
	for _, it := range res.Items {
		mt, err := FromGoogleMimeType(it.MimeType)
		if err != nil {
			return nil, err
		}
		// Use provided folder path when available as the FilePath
		fi := FileInfo{
			FileStore: "google",
			FileID:    it.Id,
			FileName:  it.Title,
			FilePath:  folder.FolderPath,
			FileURL:   firstNonEmpty(it.WebContentLink, it.AlternateLink),
			Size:      it.FileSize,
			MimeType:  mt,
		}
		out = append(out, fi)
	}
	return out, nil
}

func firstNonEmpty(s1, s2 string) string {
	if s1 != "" {
		return s1
	}
	return s2
}

// UploadFile uploads data to Google Drive and returns the created FileInfo.
func (g *GoogleDriveFileStore) UploadFile(ctx context.Context, fileName string, fileType MimeType, folderInfo FolderInfo, data io.Reader) (FileInfo, error) {
	// prepare drive file metadata
	mimeStr, err := fileType.ToGoogleMimeType()
	if err != nil {
		return FileInfo{}, err
	}
	df := &drive.File{
		Title:    fileName,
		MimeType: mimeStr,
	}

	// ensure folder id
	folderID := folderInfo.FolderId
	if folderID == "" {
		folderID = "root"
	}
	// set parent reference (drive v2 uses ParentReference)
	df.Parents = []*drive.ParentReference{{Id: folderID}}

	// insert with media
	created, err := g.Service.Files.Insert(df).Media(data).Do()
	if err != nil {
		return FileInfo{}, err
	}

	mt, err := FromGoogleMimeType(created.MimeType)
	if err != nil {
		return FileInfo{}, err
	}
	return FileInfo{
		FileStore: "google",
		FileID:    created.Id,
		FileName:  created.Title,
		FilePath:  folderInfo.FolderPath,
		FileURL:   firstNonEmpty(created.WebContentLink, created.AlternateLink),
		Size:      created.FileSize,
		MimeType:  mt,
	}, nil
}

// DownloadFile returns an io.Reader and a cleanup func (to be deferred) for the file contents.
func (g *GoogleDriveFileStore) DownloadFile(ctx context.Context, file FileInfo) (io.Reader, func(), error) {
	// For Google-native docs/spreadsheets, export as PDF by default
	var resp *http.Response
	var err error

	switch file.MimeType {
	case MimeTypeGoogleDoc:
		resp, err = g.Service.Files.Export(file.FileID, "application/pdf").Download()
	case MimeTypeGoogleSheet:
		resp, err = g.Service.Files.Export(file.FileID, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet").Download()
	default:
		resp, err = g.Service.Files.Get(file.FileID).Download()
	}
	if err != nil {
		return nil, nil, err
	}

	cleanup := func() {
		if resp.Body != nil {
			resp.Body.Close()
		}
	}
	return resp.Body, cleanup, nil
}

// DeleteFile deletes the file from Google Drive.
func (g *GoogleDriveFileStore) DeleteFile(ctx context.Context, file FileInfo) error {
	return g.Service.Files.Delete(file.FileID).Do()
}
