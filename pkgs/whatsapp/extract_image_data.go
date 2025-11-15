package whatsapp

import (
	"context"
	"fmt"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/llm"
	"sadbhavana/tree-project/pkgs/llmactions"
	"strconv"

	"github.com/juju/errors"
)

func extractImageData(ctx context.Context, q *db.Queries, msg ParsedMessage) error {
	if msg.Type != ParsedMessageTypeImage || msg.File == nil {
		return nil
	}

	fileID, wasUpdated, err := msg.File.SaveToDB(ctx, q)
	if err != nil {
		return errors.Annotatef(err, "failed to save image file to database")
	}
	if wasUpdated {
		// Already processed
		return nil
	}

	client, err := llm.NewGeminiClient(ctx, llm.Gemini25Pro)
	if err != nil {
		return errors.Annotatef(err, "failed to create Gemini client")
	}

	imageData, err := llmactions.ExtractTreeId(ctx, q, client, *msg.File)
	if err != nil {
		return errors.Annotatef(err, "failed to extract tree ID from image")
	}

	if imageData.Confidence < 0.7 {
		return fmt.Errorf("low confidence (%f) in extracted tree ID %s", imageData.Confidence, imageData.TreeID)
	}

	if len(imageData.TreeID) < 3 {
		return fmt.Errorf("extracted tree ID %s is too short", imageData.TreeID)
	}

	projectCode := imageData.TreeID[:2]
	treeNumber, err := strconv.Atoi(imageData.TreeID[2:])
	if err != nil {
		return errors.Annotatef(err, "failed to parse tree number from extracted tree ID %s", imageData.TreeID)
	}

	tree, err := q.GetTreeByProjectCodeAndNumber(ctx, db.GetTreeByProjectCodeAndNumberParams{
		ProjectCode: projectCode,
		TreeNumber:  int32(treeNumber),
	})
	if err != nil {
		return errors.Annotatef(err, "failed to get tree by extracted tree ID %s", imageData.TreeID)
	}

	_, err = q.CreateTreeUpdate(ctx, db.CreateTreeUpdateParams{
		TreeID: tree.ID,
		FileID: fileID,
	})
	if err != nil {
		return errors.Annotatef(err, "failed to create tree update for tree ID %s", imageData.TreeID)
	}

	return nil
}
