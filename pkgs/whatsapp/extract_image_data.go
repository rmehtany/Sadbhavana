package whatsapp

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/file"
	"sadbhavana/tree-project/pkgs/llm"
	"sadbhavana/tree-project/pkgs/llmactions"
	"strconv"
	"strings"
	"time"

	"github.com/juju/errors"
	"google.golang.org/api/drive/v3"
	"google.golang.org/genai"
)

// Create a struct to keep data paired
type ImageSource struct {
	Name       string
	ID         string
	Path       string
	MimeType   string
	Longitude  float64
	Latitude   float64
	PhotoTime  time.Time
	Data       []byte
	TreeID     string
	Confidence float64
}

// Create a struct to keep data paired
type ImageInfo struct {
	Name       string
	ID         string
	Path       string
	MimeType   string
	Longitude  float64
	Latitude   float64
	PhotoTime  time.Time
	TreeID     string
	Confidence float64
}

type ExtractionResult struct {
	TreeID     string  `json:"tree_id"`
	FileID     string  `json:"file_id"`
	FileName   string  `json:"file_name"`
	Confidence float64 `json:"confidence"`
}

type ExtractTreeIdOutput struct {
	TreeID     string  `json:"tree_id"`
	Confidence float64 `json:"confidence"`
}

func ExtractImageDataFromFileInfo(ctx context.Context, q *db.Queries, fileInfo file.FileInfo) error {
	if fileInfo.MimeType.IsImage() == false {
		return nil
	}
	fmt.Println("File is image, that is confirmed...")
	// fileID, wasUpdated, err := fileInfo.SaveToDB(ctx, q)
	// if err != nil {
	// 	return errors.Annotatef(err, "failed to save image file to database")
	// }
	// if wasUpdated {
	// 	// Already processed
	// 	return nil
	// }

	client, err := llm.NewGeminiClient(ctx, llm.Gemini25Flash)
	if err != nil {
		return errors.Annotatef(err, "failed to create Gemini client")
	}

	fmt.Println("Client is ", client)
	imageData, err := llmactions.ExtractTreeId(ctx, q, client, fileInfo)
	if err != nil {
		return errors.Annotatef(err, "failed to extract tree ID from image")
	}

	if imageData.Confidence < 0.7 {
		fmt.Printf("low confidence (%f) in extracted tree ID %s for fileId %s\n", imageData.Confidence, imageData.TreeID, fileInfo.FileName)
		// return fmt.Errorf("low confidence (%f) in extracted tree ID %s", imageData.Confidence, imageData.TreeID)
	}

	if len(imageData.TreeID) < 3 {
		fmt.Printf("extracted tree ID %s is too short for fileId %s\n", imageData.TreeID, fileInfo.FileName)
		// return fmt.Errorf("extracted tree ID %s is too short", imageData.TreeID)
	}
	fmt.Printf("Extracted treeId is %s\n", imageData.TreeID)
	projectCode := imageData.TreeID[:2]
	treeNumber, err := strconv.Atoi(imageData.TreeID[2:])
	if err != nil {
		fmt.Printf("failed to parse tree number from extracted tree ID %s: %v\n", imageData.TreeID, err)
		// return errors.Annotatef(err, "failed to parse tree number from extracted tree ID %s", imageData.TreeID)
	}

	tree, err := q.GetTreeByProjectCodeAndNumber(ctx, db.GetTreeByProjectCodeAndNumberParams{
		ProjectCode: projectCode,
		TreeNumber:  int32(treeNumber),
	})
	fmt.Printf("tree details : %v", tree)
	if err != nil {
		return errors.Annotatef(err, "failed to get tree by extracted tree ID %s", imageData.TreeID)
	}

	_, err = q.CreateTreeUpdate(ctx, db.CreateTreeUpdateParams{
		TreeID: tree.ID,
		FileID: fileInfo.FileID,
	})
	if err != nil {
		return errors.Annotatef(err, "failed to create tree update for tree ID %s", imageData.TreeID)
	}

	return nil
}

func FinalExtractImageDataFromFolderInfoList(ctx context.Context, q *db.Queries, folder *drive.File, fileStore *file.UpdatedGoogleDriveFileStore) (map[string]ImageInfo, error) {
	// 2. Setup Gemini Client
	log.Println("Inside finalExtractImageData...")
	geminiClient, err := llm.NewGeminiClient(ctx, llm.Gemini25Flash)
	if err != nil {
		return nil, errors.Annotatef(err, "failed to create Gemini client")
	}
	// fmt.Println("Client is ", geminiClient)

	folderID := folder.Id
	pageToken := ""

	fileInfoMap := make(map[string]ImageInfo)
	for {
		// 1. Fetch metadata for the next 20 images
		query := fmt.Sprintf("'%s' in parents and mimeType contains 'image/'", folderID)
		call := fileStore.Service.Files.List().Q(query).PageSize(20).Fields("nextPageToken, files(id, name, mimeType, parents, createdTime, modifiedTime, imageMediaMetadata/location, imageMediaMetadata/time)")
		if pageToken != "" {
			call.PageToken(pageToken)
		}

		res, err := call.Do()
		if err != nil {
			log.Fatal(err)
		}

		if len(res.Files) == 0 {
			break
		}
		log.Printf("Fetched %d files from folder %s\n", len(res.Files), folder.Name)
		// 2. Setup the channel and data
		// Buffer the channel to prevent the producer from blocking immediately
		partsChan := make(chan ImageSource, len(res.Files))

		err1 := CreatePartsChanFromFiles(res, fileStore, partsChan)
		if err1 != nil {
			return fileInfoMap, err1
		}
		close(partsChan)

		//create new method to assemble prompt, create fileInfoMap, Send request to Gemini, Get response from Gemini and map the same into other response
		extractedData, err1 := ExtractTreeIdFromImages(ctx, partsChan, geminiClient, fileInfoMap)
		if err1 != nil {
			updateTreeIdAndNameInFileInfoMap(extractedData, fileInfoMap)
			return fileInfoMap, err1
		}

		updateTreeIdAndNameInFileInfoMap(extractedData, fileInfoMap)

		// // 5. Extract Text from Response
		// if len(resp.Candidates) == 0 || len(resp.Candidates[0].Content.Parts) == 0 {
		// 	return fmt.Errorf("empty response from model")
		// }

		// break
		// 6. Check if there are more images
		pageToken = res.NextPageToken
		if pageToken == "" {
			fmt.Println("Completed all images.")
			break
		}
	}
	return fileInfoMap, nil
}

func updateTreeIdAndNameInFileInfoMap(extractedData []ExtractionResult, fileInfoMap map[string]ImageInfo) {
	for _, res := range extractedData {
		image := fileInfoMap[res.FileID]
		fmt.Printf("res.FileName is %s and res.TreeID is %s", res.FileName, res.TreeID)

		if res.TreeID != "" {
			image.TreeID = res.TreeID
			image.Confidence = res.Confidence
			image.Name = res.TreeID + "." + strings.Split(res.FileName, ".")[len(strings.Split(res.FileName, "."))-1]
			// log.Printf("image.path is %s", image.Path)
			if strings.Contains(image.Path, "/") {
				image.Path = strings.Split(image.Path, "/")[len(strings.Split(image.Path, "/"))-2] + "/" + image.Name
			} else {
				image.Path = image.Name
			}
			fileInfoMap[res.FileID] = image
		} else {
			delete(fileInfoMap, res.FileID)
			fmt.Printf("Deleted file %s from fileInfoMap\n", res.FileName)
			fmt.Println("fileinfomap size is ", len(fileInfoMap))
		}
	}
}

func ExtractTreeIdFromImages(ctx context.Context, partsChan chan ImageSource, geminiClient llm.Client, fileInfoMap map[string]ImageInfo) ([]ExtractionResult, error) {
	// 3. Assemble Prompt and create file info map
	var promptParts []*genai.Part
	for item := range partsChan {
		promptParts = append(promptParts, &genai.Part{
			Text: fmt.Sprintf("File Name: %s, File ID: %s", item.Name, item.ID),
		})
		// log.Printf("itemname is %s, item mimetype is %s", item.Name, item.MimeType)
		// Add Image Data Part
		promptParts = append(promptParts, &genai.Part{
			InlineData: &genai.Blob{
				MIMEType: item.MimeType,
				Data:     item.Data,
			},
		})
		//Create a map to store file related info against file id
		fileInfoMap[item.ID] = mapFileInfoAndImageSource(item)
		// log.Println("After adding to map, image is ", fileInfoMap[item.ID])
	}

	instruction := `Extract the ID (1 or 2 chars + digits) from the red text on the white boards. 
		Return a JSON array using this schema: 
		{"tree_id": string, "file_id": string, "file_name": string, "confidence": float}`

	log.Printf("Constructed prompt with %d parts\n", len(promptParts))
	// 2. Configure the Request (v1.35.0 Config Style)
	config := &genai.GenerateContentConfig{
		SystemInstruction: &genai.Content{
			Parts: []*genai.Part{
				{Text: instruction},
			},
		},
		ResponseMIMEType: "application/json",      // Hard-enforces JSON output
		Temperature:      genai.Ptr(float32(0.2)), // Low temperature for high extraction accuracy
	}

	// 3. Construct Content Slice
	contents := []*genai.Content{
		{
			Role:  "user",
			Parts: promptParts,
		},
	}

	resp, err := geminiClient.GenerateContent(ctx, contents, config)
	if err != nil {
		log.Printf("Failed to generate content: %v\n", err)
		return nil, err
	}
	log.Printf("Response: %v\n", resp)

	// Transform raw text into Go objects
	extractedData, err := parseGeminiResponse(resp)
	if err != nil {
		log.Printf("Parsing error: %v", err)
	}
	return extractedData, nil
}

func mapFileInfoAndImageSource(imageFile ImageSource) ImageInfo {
	return ImageInfo{
		Name:       imageFile.Name,
		ID:         imageFile.ID,
		Path:       imageFile.Path,
		MimeType:   imageFile.MimeType,
		Longitude:  imageFile.Longitude,
		Latitude:   imageFile.Latitude,
		PhotoTime:  imageFile.PhotoTime,
		TreeID:     "",
		Confidence: 0,
	}
}

func CreatePartsChanFromFiles(res *drive.FileList, fileStore *file.UpdatedGoogleDriveFileStore, partsChan chan ImageSource) error {
	for _, f := range res.Files {
		dl, err := fileStore.Service.Files.Get(f.Id).Download()
		if err != nil {
			return err
		}
		data, err := io.ReadAll(dl.Body)
		defer dl.Body.Close()
		if err != nil {
			return err
		}

		var latitude, longitude float64
		var photoTime time.Time

		if f.ImageMediaMetadata != nil {
			if f.ImageMediaMetadata.Location != nil {
				latitude = f.ImageMediaMetadata.Location.Latitude
				longitude = f.ImageMediaMetadata.Location.Longitude
			}
			photoTime = MapStringToTime(f.ImageMediaMetadata.Time)
		} else {
			photoTime = MapStringToTime(f.CreatedTime)
		}

		filePath := ""
		if len(f.Parents) > 0 {
			parentID := f.Parents[0]
			parentFolder, err := fileStore.Service.Files.Get(parentID).Fields("name").Do()
			if err == nil {
				filePath = parentFolder.Name + "/" + f.Name
			} else {
				log.Printf("Failed to get parent folder name for ID %s: %v", parentID, err)
				filePath = parentID + "/" + f.Name // Fallback to ID
			}
		} else {
			filePath = f.Name
		}

		// We wrap the data and a text hint so Gemini knows which file is which
		partsChan <- ImageSource{
			Name:      f.Name,
			ID:        f.Id,
			Path:      filePath,
			MimeType:  f.MimeType,
			Longitude: longitude,
			Latitude:  latitude,
			PhotoTime: photoTime,
			Data:      data,
		}
	}
	return nil
}

func MapStringToTime(timeString string) time.Time {
	if timeString != "" {
		// Try parsing the RFC3339 formatted time with milliseconds (like "2026-01-26T11:59:06.011Z")
		const format1 = "2006-01-02T15:04:05.999Z"
		// Also try original EXIF format as fallback
		const format2 = "2006:01:02 15:04:05"

		t, err := time.Parse(time.RFC3339Nano, timeString)
		if err == nil {
			return t
		}

		t, err = time.Parse(format1, timeString)
		if err == nil {
			return t
		}

		t, err = time.Parse(format2, timeString)
		if err == nil {
			return t
		}

		log.Printf("failed to parse EXIF time %q", timeString)
	}
	return time.Time{}
}

func parseGeminiResponse(resp *genai.GenerateContentResponse) ([]ExtractionResult, error) {
	// 1. Safety check for empty results
	if len(resp.Candidates) == 0 || len(resp.Candidates[0].Content.Parts) == 0 {
		return nil, fmt.Errorf("no content in response")
	}

	// 2. Extract the raw JSON string from the first part
	rawJSON := resp.Candidates[0].Content.Parts[0].Text

	// 3. Unmarshal into our Go slice
	var results []ExtractionResult
	err := json.Unmarshal([]byte(rawJSON), &results)
	if err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w | Raw: %s", err, rawJSON)
	}

	return results, nil
}

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
