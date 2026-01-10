package file

import (
	"fmt"
	"path/filepath"
	"strings"
	"time"
)

// MimeType represents supported file types
type MimeType string

const (
	MimeTypeZIP         MimeType = "zip"
	MimeTypePNG         MimeType = "png"
	MimeTypeJPEG        MimeType = "jpeg"
	MimeTypePDF         MimeType = "pdf"
	MimeTypeTiff        MimeType = "tiff"
	MimeTypeCSV         MimeType = "csv"
	MimeTypeJSON        MimeType = "json"
	MimeTypeXML         MimeType = "xml"
	MimeTypeHTML        MimeType = "html"
	MimeTypeGoogleDoc   MimeType = "gdoc"
	MimeTypeText        MimeType = "txt"
	MimeTypeMarkdown    MimeType = "md"
	MimeTypeDOCX        MimeType = "docx"
	MimeTypeXLSX        MimeType = "xlsx"
	MimeTypeGoogleSheet MimeType = "gsheet"
	MimeTypeFolder      MimeType = "folder"
	MimeTypeMP4         MimeType = "mp4"
	MimeTypeEml         MimeType = "eml"
	MimeTypeGIF         MimeType = "gif"
	MimeTypeUnknown     MimeType = "unknown"
)

func (m MimeType) ToAmazonMimeType() (string, error) {
	switch m {
	case MimeTypeZIP:
		return "application/zip", nil
	case MimeTypePNG:
		return "image/png", nil
	case MimeTypeJPEG:
		return "image/jpeg", nil
	case MimeTypeGIF:
		return "image/gif", nil
	case MimeTypeTiff:
		return "image/tiff", nil
	case MimeTypePDF:
		return "application/pdf", nil
	case MimeTypeCSV:
		return "text/csv", nil
	case MimeTypeXML:
		return "application/xml", nil
	case MimeTypeText:
		return "text/plain", nil
	case MimeTypeHTML:
		return "text/html", nil
	case MimeTypeMarkdown:
		return "text/markdown", nil
	case MimeTypeMP4:
		return "video/mp4", nil
	case MimeTypeJSON:
		return "application/json", nil
	case MimeTypeDOCX:
		return "application/vnd.openxmlformats-officedocument.wordprocessingml.document", nil
	case MimeTypeXLSX:
		return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", nil
	default:
		return "", fmt.Errorf("unknown mime type %s", m)
	}
}

// ToGoogleMimeType converts a MimeType to its corresponding Google Drive MIME type
func (m MimeType) ToGoogleMimeType() (string, error) {
	switch m {
	case MimeTypeZIP:
		return "application/zip", nil
	case MimeTypePNG:
		return "image/png", nil
	case MimeTypeJPEG:
		return "image/jpeg", nil
	case MimeTypeGIF:
		return "image/gif", nil
	case MimeTypeTiff:
		return "image/tiff", nil
	case MimeTypePDF:
		return "application/pdf", nil
	case MimeTypeCSV:
		return "text/csv", nil
	case MimeTypeGoogleDoc:
		return "application/vnd.google-apps.document", nil
	case MimeTypeText:
		return "text/plain", nil
	case MimeTypeXML:
		return "application/xml", nil
	case MimeTypeHTML:
		return "text/html", nil
	case MimeTypeJSON:
		return "application/json", nil
	case MimeTypeMarkdown:
		return "text/markdown", nil
	case MimeTypeMP4:
		return "video/mp4", nil
	case MimeTypeDOCX:
		return "application/vnd.openxmlformats-officedocument.wordprocessingml.document", nil
	case MimeTypeXLSX:
		return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", nil
	case MimeTypeGoogleSheet:
		return "application/vnd.google-apps.spreadsheet", nil
	case MimeTypeFolder:
		return "application/vnd.google-apps.folder", nil
	case MimeTypeEml:
		return "message/rfc822", nil
	default:
		return "", fmt.Errorf("unknown mime type %s", m)
	}
}

func FromGoogleMimeType(mimeType string) (MimeType, error) {
	switch mimeType {
	case "application/zip", "application/x-zip-compressed":
		return MimeTypeZIP, nil
	case "image/png":
		return MimeTypePNG, nil
	case "image/jpeg":
		return MimeTypeJPEG, nil
	case "image/gif":
		return MimeTypeGIF, nil
	case "image/tiff":
		return MimeTypeTiff, nil
	case "application/pdf", "pdf":
		return MimeTypePDF, nil
	case "text/csv":
		return MimeTypeCSV, nil
	case "application/vnd.google-apps.document":
		return MimeTypeGoogleDoc, nil
	case "text/plain":
		return MimeTypeText, nil
	case "application/xml":
		return MimeTypeXML, nil
	case "text/html":
		return MimeTypeHTML, nil
	case "application/json":
		return MimeTypeJSON, nil
	case "text/markdown":
		return MimeTypeMarkdown, nil
	case "video/mp4":
		return MimeTypeMP4, nil
	case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
		return MimeTypeDOCX, nil
	case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
		return MimeTypeXLSX, nil
	case "application/vnd.google-apps.spreadsheet":
		return MimeTypeGoogleSheet, nil
	case "application/vnd.google-apps.folder":
		return MimeTypeFolder, nil
	case "message/rfc822":
		return MimeTypeEml, nil
	default:
		return MimeTypeUnknown, fmt.Errorf("unknown mime type %s", mimeType)
	}
}

func FromAmazonMimeType(mimeType string) (MimeType, error) {
	switch mimeType {
	case "application/zip":
		return MimeTypeZIP, nil
	case "image/png":
		return MimeTypePNG, nil
	case "image/jpeg":
		return MimeTypeJPEG, nil
	case "image/gif":
		return MimeTypeGIF, nil
	case "image/tiff":
		return MimeTypeTiff, nil
	case "application/pdf", "pdf":
		return MimeTypePDF, nil
	case "text/csv":
		return MimeTypeCSV, nil
	case "application/xml":
		return MimeTypeXML, nil
	case "text/plain":
		return MimeTypeText, nil
	case "text/html":
		return MimeTypeHTML, nil
	case "text/markdown":
		return MimeTypeMarkdown, nil
	case "video/mp4":
		return MimeTypeMP4, nil
	case "application/json":
		return MimeTypeJSON, nil
	case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
		return MimeTypeDOCX, nil
	case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
		return MimeTypeXLSX, nil
	case "message/rfc822":
		return MimeTypeEml, nil
	default:
		return MimeTypeUnknown, fmt.Errorf("unknown mime type %s", mimeType)
	}
}

func (m MimeType) ToAnthropicMimeType() (string, error) {
	switch m {
	case MimeTypePDF:
		return "PDF", nil
	case MimeTypeDOCX:
		return "DOCX", nil
	case MimeTypeXLSX:
		return "XLSX", nil
	case MimeTypeCSV:
		return "CSV", nil
	case MimeTypeText:
		return "TXT", nil
	case MimeTypeJSON:
		return "JSON", nil
	default:
		return "", fmt.Errorf("unsupported mime type %s for Anthropic", m)
	}
}

func FromFilename(filename string) (MimeType, error) {
	// Extract the file extension by splitting on the last dot
	ext := ""
	if dot := strings.LastIndex(filename, "."); dot != -1 {
		ext = filename[dot+1:]
	}
	return FromExtension(ext)
}

func FromFileName(filename string) (MimeType, error) {
	// Extract the file extension by splitting on the last dot
	ext := ""
	if dot := strings.LastIndex(filename, "."); dot != -1 {
		ext = filename[dot+1:]
	}
	return FromExtension(ext)
}

// FromExtension converts a file extension to a MimeType
func FromExtension(ext string) (MimeType, error) {
	// Remove the dot if present and convert to lowercase
	ext = strings.TrimPrefix(strings.ToLower(ext), ".")

	switch ext {
	case "zip":
		return MimeTypeZIP, nil
	case "png":
		return MimeTypePNG, nil
	case "jpg", "jpeg":
		return MimeTypeJPEG, nil
	case "gif":
		return MimeTypeGIF, nil
	case "tiff":
		return MimeTypeTiff, nil
	case "pdf":
		return MimeTypePDF, nil
	case "csv":
		return MimeTypeCSV, nil
	case "gdoc":
		return MimeTypeGoogleDoc, nil
	case "txt":
		return MimeTypeText, nil
	case "md", "markdown":
		return MimeTypeMarkdown, nil
	case "xlsx", "xls", "xlsm", "xlsb", "xltx", "xltm":
		return MimeTypeXLSX, nil
	case "gsheet":
		return MimeTypeGoogleSheet, nil
	case "doc", "docx":
		return MimeTypeDOCX, nil
	case "folder", "dir", "directory":
		return MimeTypeFolder, nil
	case "mp4":
		return MimeTypeMP4, nil
	case "xml", "drawio":
		return MimeTypeXML, nil
	case "html":
		return MimeTypeHTML, nil
	case "json":
		return MimeTypeJSON, nil
	default:
		return MimeTypeUnknown, fmt.Errorf("unknown mime type %s", ext)
	}
}

// FileInfo represents information about an uploaded file
type FileInfo struct {
	FileStore  string            `json:"file_store" validate:"required" oneof:"local google"`
	FileID     string            `json:"file_id" validate:"required"`
	FilePath   string            `json:"file_path,omitempty"`
	FileURL    string            `json:"file_url,omitempty"`
	Size       int64             `json:"size,omitempty"`
	FileName   string            `json:"file_name" validate:"required"`
	MimeType   MimeType          `json:"mime_type" validate:"required"`
	Expiration *time.Time        `json:"expiration,omitempty"`
	Metadata   map[string]string `json:"metadata,omitempty"`
}

type FolderInfo struct {
	FolderId   string `json:"folder_id,omitempty"`
	FolderPath string `json:"folder_path,omitempty"`
	FolderURL  string `json:"folder_url" validate:"required"`
}

func (m MimeType) IsImage() bool {
	switch m {
	case MimeTypePNG, MimeTypeJPEG, MimeTypeGIF, MimeTypeTiff:
		return true
	default:
		return false
	}
}

func GetFileName(filePath string) string {
	// Get the base filename (handles both Unix and Windows paths)
	base := filepath.Base(filePath)

	// Remove the extension (only the last one)
	ext := filepath.Ext(base)
	return strings.TrimSuffix(base, ext)
}
