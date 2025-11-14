package file

import (
	"context"
	"sadbhavana/tree-project/pkgs/db"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/juju/errors"
)

func (f *FileInfo) SaveToDB(ctx context.Context, q *db.Queries) (string, error) {
	mimeTypeStr, err := f.MimeType.ToGoogleMimeType()
	if err != nil {
		return "", errors.Annotatef(err, "invalid mime type: %v", f.MimeType)
	}
	dbFile := db.UpsertFileParams{FileStore: f.FileStore, FileType: pgtype.Text{String: mimeTypeStr, Valid: true}}
	if f.FileID != "" {
		dbFile.FileStoreID = pgtype.Text{String: f.FileID, Valid: true}
	}
	if f.FilePath != "" {
		dbFile.FilePath = pgtype.Text{String: f.FilePath, Valid: true}
	}
	if f.FileURL != "" {
		dbFile.FileUrl = pgtype.Text{String: f.FileURL, Valid: true}
	}
	if f.Expiration != nil {
		dbFile.FileExpiration = pgtype.Timestamptz{Time: *f.Expiration, Valid: true}
	}

	upsertedFile, err := q.UpsertFile(ctx, dbFile)
	if err != nil {
		return "", errors.Annotatef(err, "failed to upsert file in database")
	}

	return upsertedFile.ID, nil
}

func ExtractFileInfoFromDB(dbFile db.CoreFile) (FileInfo, error) {
	mimeType, err := FromGoogleMimeType(dbFile.FileType.String)
	if err != nil {
		return FileInfo{}, errors.Annotatef(err, "invalid mime type from database: %v", dbFile.FileType.String)
	}

	var expiration *time.Time
	if dbFile.FileExpiration.Valid {
		expiration = &dbFile.FileExpiration.Time
	}

	return FileInfo{
		FileStore:  dbFile.FileStore,
		FileID:     dbFile.FileStoreID.String,
		FilePath:   dbFile.FilePath.String,
		FileURL:    dbFile.FileUrl.String,
		FileName:   dbFile.FileName.String,
		MimeType:   mimeType,
		Expiration: expiration,
	}, nil
}
