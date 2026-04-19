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
	"google.golang.org/api/drive/v3"
	"google.golang.org/api/option"
)

// Manual OAuth helper functions have been removed as they are no longer needed
// with service account authentication. The application now uses automated
// authentication via auth.GetActiveToken() which handles JWT token generation
// and refresh automatically.
//
// For reference, the old manual OAuth flow required:
// - getClient() - to orchestrate the OAuth flow
// - getTokenFromWeb() - to wait for browser authentication and code.json file
// - tokenFromFile() / saveToken() - to manage token.json file
// - getCodeFromFile() - to read authorization code from code.json
//
// All of this has been replaced with a single call to auth.GetActiveToken()

type UpdatedGoogleDriveFileStore struct {
	Service      *drive.Service
	ProviderType providers.ProviderType
}

func NewUpdatedGoogleDriveFileStore(ctx context.Context, q *db.Queries) (*UpdatedGoogleDriveFileStore, error) {
	// Use automated service account authentication via GetActiveToken
	// This eliminates the need for manual OAuth flow and browser authentication
	activeToken, err := auth.GetActiveToken(ctx, q, providers.GOOGLE_PROVIDER)
	if err != nil {
		return nil, fmt.Errorf("failed to get active token: %w", err)
	}
	fmt.Println("activeToken is {}", activeToken.AccessToken)
	client := oauth2.NewClient(ctx, oauth2.StaticTokenSource(&activeToken))
	srv, err := drive.NewService(ctx, option.WithHTTPClient(client))
	if err != nil {
		return nil, fmt.Errorf("unable to retrieve Drive client: %w", err)
	}

	fmt.Println("Successfully created Google Drive service with automated authentication")
	return &UpdatedGoogleDriveFileStore{
		Service:      srv,
		ProviderType: providers.GOOGLE_PROVIDER,
	}, nil
}

// ListFiles lists files in the given folder.
func (g *UpdatedGoogleDriveFileStore) ListFiles(ctx context.Context, folder FolderInfo) ([]FileInfo, error) {
	// default to root if no folder id provided
	folderID := folder.FolderId
	if folderID == "" {
		folderID = "root"
	}

	q := fmt.Sprintf("'%s' in parents and trashed=false", folderID)
	// request a small set of fields
	res, err := g.Service.Files.List().Q(q).Fields("files(id,name,size,mimeType,webContentLink,webViewLink)").Do()
	if err != nil {
		return nil, err
	}
	fmt.Printf("Number of files in folder is %d", len(res.Files))
	out := make([]FileInfo, 0, len(res.Files))
	for _, it := range res.Files {
		mt, err := FromGoogleMimeType(it.MimeType)
		if err != nil {
			return nil, err
		}
		// Use provided folder path when available as the FilePath
		fi := FileInfo{
			FileStore: "google",
			FileID:    it.Id,
			FileName:  it.Name,
			FilePath:  folder.FolderPath + "/" + it.Name,
			FileURL:   pickNonEmpty(it.WebContentLink, it.WebViewLink),
			Size:      it.Size,
			MimeType:  mt,
		}
		out = append(out, fi)
	}
	return out, nil
}

func pickNonEmpty(s1, s2 string) string {
	if s1 != "" {
		return s1
	}
	return s2
}

// UploadFile uploads data to Google Drive and returns the created FileInfo.
func (g *UpdatedGoogleDriveFileStore) UploadFile(ctx context.Context, fileName string, fileType MimeType, folderInfo FolderInfo, data io.Reader) (FileInfo, error) {
	// prepare drive file metadata
	fmt.Println("uploadFile method of UpdatedGoogleDriveFileStore")
	mimeStr, err := fileType.ToGoogleMimeType()
	if err != nil {
		return FileInfo{}, err
	}
	df := &drive.File{
		Name:     fileName,
		MimeType: mimeStr,
	}

	// ensure folder id
	folderID := folderInfo.FolderId
	if folderID == "" {
		folderID = "root"
	}
	// set parent reference for Drive v3 (Parents is []string)
	df.Parents = []string{folderID}

	// create with media (Drive v3)
	created, err := g.Service.Files.Create(df).Media(data).Do()
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
		FileName:  created.Name,
		FilePath:  folderInfo.FolderPath,
		FileURL:   pickNonEmpty(created.WebContentLink, created.WebViewLink),
		Size:      created.Size,
		MimeType:  mt,
	}, nil
}

// DownloadFile returns an io.Reader and a cleanup func (to be deferred) for the file contents.
func (g *UpdatedGoogleDriveFileStore) DownloadFile(ctx context.Context, file FileInfo) (io.Reader, func(), error) {
	// For Google-native docs/spreadsheets, export as PDF by default
	fmt.Println("Inside downloadFile of UpdatedGoogleDriveFileStore")
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
	fmt.Println("err is ", err)
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
func (g *UpdatedGoogleDriveFileStore) DeleteFile(ctx context.Context, file FileInfo) error {
	return g.Service.Files.Delete(file.FileID).Do()
}
