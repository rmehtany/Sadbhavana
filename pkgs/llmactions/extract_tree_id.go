package llmactions

import (
	"context"
	"fmt"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/file"
	"sadbhavana/tree-project/pkgs/llm"
)

type ExtractTreeIdOutput struct {
	TreeID     string  `json:"tree_id"`
	Confidence float64 `json:"confidence"`
}

const ExtractTreeIdPrompt string = `Attached is a photo containing a sign near the center of the photo with text in red ink. On the first line, there is an id which consists of 2 characters followed by an integer, on the second, the name of the donor, and then non-english text on the rest.
You should output the following JSON in the following format:

` + "```" + `json
{
"tree_id": "the extracted identifier (string). Example: 'AB1234'",
"confidence": "A score from 0.0 to 1.0 indicating confidence in the extracted ID (float)"
}` + "```"

func ExtractTreeId(ctx context.Context, q *db.Queries, client llm.Client, fileInfo file.FileInfo) (ExtractTreeIdOutput, error) {
	reader, cleanup, err := file.DownloadFile(ctx, q, fileInfo)
	if err != nil {
		return ExtractTreeIdOutput{}, fmt.Errorf("failed to download file: %w", err)
	}
	defer cleanup()

	geminiFileInfo, err := client.UploadFile(ctx, fileInfo.FileName, fileInfo.MimeType, reader)
	if err != nil {
		return ExtractTreeIdOutput{}, fmt.Errorf("failed to upload file to LLM: %w", err)
	}

	//NOTE: The file id here is actually a URL. This is because Gemini requires a publicly accessible URL for file inputs.
	fileContents := []llm.FileContent{
		{
			FileID:   geminiFileInfo.FileURL,
			MimeType: fileInfo.MimeType,
		},
	}

	llmOutput, err := llm.SimpleStructuredOutputWithFile[ExtractTreeIdOutput](ctx, client, llm.Config{}, ExtractTreeIdPrompt, "", fileContents)
	if err != nil {
		return ExtractTreeIdOutput{}, fmt.Errorf("failed to get LLM output: %w", err)
	}

	return *llmOutput, nil
}
