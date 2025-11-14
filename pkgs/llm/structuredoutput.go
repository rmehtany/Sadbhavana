package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"reflect"
	"regexp"
	"strings"

	"github.com/invopop/jsonschema"
)

// MaxStructuredOutputRetries defines the maximum number of retry attempts for structured output
var MaxStructuredOutputRetries = 3

// SimpleStructuredOutput calls an LLM with a structured output requirement
// It automatically generates JSON schema from type T and parses the response
// Retries up to MaxStructuredOutputRetries times if JSON parsing fails
func SimpleStructuredOutput[T any](ctx context.Context, client Client, cfg Config, systemMessage string, userMessage string) (result *T, err error) {
	return structuredOutputWithOptionalFile[T](ctx, client, cfg, systemMessage, userMessage, nil)
}

// SimpleStructuredOutputWithFile calls an LLM with a structured output requirement and includes a file
// It automatically generates JSON schema from type T and parses the response
// Retries up to MaxStructuredOutputRetries times if JSON parsing fails
func SimpleStructuredOutputWithFile[T any](ctx context.Context, client Client, cfg Config, systemMessage string, userMessage string, fileContents []FileContent) (result *T, err error) {
	return structuredOutputWithOptionalFile[T](ctx, client, cfg, systemMessage, userMessage, fileContents)
}

// structuredOutputWithOptionalFile is the common implementation for both structured output functions
func structuredOutputWithOptionalFile[T any](ctx context.Context, client Client, cfg Config, systemMessage string, userMessage string, fileContents []FileContent) (result *T, err error) {
	// Generate enhanced system message with JSON schema
	enhancedSystemMessage, err := generateEnhancedSystemMessage[T](systemMessage)
	if err != nil {
		return nil, err
	}

	// Execute retry loop with structured output parsing
	var lastErr error
	var lastResponse string

	for attempt := 0; attempt < MaxStructuredOutputRetries; attempt++ {
		// Build current user message (with retry info if needed)
		currentUserMessage := buildCurrentUserMessage(userMessage, attempt, lastResponse)

		// Build messages array
		messages := buildMessagesArray(enhancedSystemMessage, currentUserMessage, fileContents)

		// Call LLM
		request := &Request{Messages: messages, Config: cfg}
		response, err := client.Prompt(ctx, request)
		if err != nil {
			return nil, fmt.Errorf("failed to call LLM on attempt %d: %w", attempt+1, err)
		}

		lastResponse = response.Content

		// Try to parse the response
		result, err := ParseJSONResponse[T](response.Content)
		if err != nil {
			lastErr = fmt.Errorf("attempt %d - %w", attempt+1, err)
			continue
		}

		// Success!
		return result, nil
	}

	// All retries exhausted
	return nil, fmt.Errorf("failed after %d attempts, last error: %w", MaxStructuredOutputRetries, lastErr)
}

// generateEnhancedSystemMessage creates system message with JSON schema and formatting requirements
func generateEnhancedSystemMessage[T any](systemMessage string) (string, error) {
	// Generate JSON schema from type T
	var zero T
	reflector := jsonschema.Reflector{
		AllowAdditionalProperties: false,
		DoNotReference:            true,
	}

	schema := reflector.Reflect(zero)
	schemaBytes, err := json.MarshalIndent(schema, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to marshal JSON schema: %w", err)
	}

	typeName := getTypeName[T]()

	// Enhanced system message with schema and clear instructions
	enhancedSystemMessage := fmt.Sprintf(`%s

CRITICAL: You must respond with valid JSON that exactly matches the required schema for type '%s'. 

JSON Schema:
%s

STRICT FORMATTING REQUIREMENTS:
- Return ONLY valid JSON wrapped in triple backticks with json label
- Use the exact format: `+"```json\n{your json here}\n```"+`
- Ensure all required fields are included
- Match the exact field names and types from the schema
- Do not include any explanatory text outside the JSON block
- Double-check your JSON syntax before responding

Example format:
`+"```json\n{\n  \"field1\": \"value1\",\n  \"field2\": 42\n}\n```",
		systemMessage, typeName, string(schemaBytes))

	return enhancedSystemMessage, nil
}

// buildCurrentUserMessage creates the user message, adding retry info if this is a retry attempt
func buildCurrentUserMessage(userMessage string, attempt int, lastResponse string) string {
	if attempt == 0 {
		return userMessage
	}

	return fmt.Sprintf(`%s

RETRY ATTEMPT %d: The previous response was not valid JSON or did not match the required schema. Please ensure you:
1. Use the exact format: `+"```json\n{your json}\n```"+`
2. Include all required fields from the schema
3. Use correct data types
4. Return valid JSON syntax only

Previous response that failed: %s`, userMessage, attempt, lastResponse)
}

// buildMessagesArray constructs the messages array for the LLM request
func buildMessagesArray(systemMessage, userMessage string, fileContents []FileContent) []Message {
	messages := []Message{
		{
			Role: RoleSystem,
			Content: MessageContent{
				Type: ContentTypeText,
				Text: &TextContent{Text: systemMessage},
			},
		},
	}

	if userMessage != "" {
		messages = append(messages, Message{
			Role: RoleUser,
			Content: MessageContent{
				Type: ContentTypeText,
				Text: &TextContent{Text: userMessage},
			},
		})
	}

	// Add file message if file content is provided

	for _, fileContent := range fileContents {
		messages = append(messages, Message{
			Role: RoleUser,
			Content: MessageContent{
				Type: ContentTypeFile,
				File: &fileContent,
			},
		})
	}

	return messages
}

// ParseJSONResponse extracts and unmarshals JSON from the LLM response
func ParseJSONResponse[T any](content string) (*T, error) {
	jsonContent, err := ExtractJSONFromResponse(content)
	if err != nil {
		return nil, fmt.Errorf("failed to extract JSON: %w", err)
	}

	var result T
	err = json.Unmarshal([]byte(jsonContent), &result)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %w", err)
	}

	return &result, nil
}

// getTypeName returns a readable name for type T
func getTypeName[T any]() string {
	var zero T
	t := reflect.TypeOf(zero)

	// Handle pointer types
	if t != nil && t.Kind() == reflect.Ptr {
		t = t.Elem()
	}

	if t != nil {
		if t.PkgPath() != "" {
			return fmt.Sprintf("%s.%s", t.PkgPath(), t.Name())
		}
		return t.Name()
	}

	return "unknown"
}

// ExtractJSONFromResponse extracts JSON content from LLM response text
func ExtractJSONFromResponse(content string) (string, error) {
	// Try multiple patterns to find JSON content

	// Pattern 1: JSON in triple backticks with json label
	jsonRegex := regexp.MustCompile("(?s)```json\\s*\\n?(.*?)\\n?```")
	matches := jsonRegex.FindStringSubmatch(content)
	if len(matches) > 1 {
		return strings.TrimSpace(matches[1]), nil
	}

	// Pattern 2: JSON in triple backticks without label
	backtickRegex := regexp.MustCompile("(?s)```\\s*\\n?(.*?)\\n?```")
	matches = backtickRegex.FindStringSubmatch(content)
	if len(matches) > 1 {
		candidate := strings.TrimSpace(matches[1])
		// Validate it looks like JSON
		if (strings.HasPrefix(candidate, "{") && strings.HasSuffix(candidate, "}")) ||
			(strings.HasPrefix(candidate, "[") && strings.HasSuffix(candidate, "]")) {
			return candidate, nil
		}
	}

	// Pattern 3: Direct JSON (starts and ends with braces/brackets)
	content = strings.TrimSpace(content)
	if (strings.HasPrefix(content, "{") && strings.HasSuffix(content, "}")) ||
		(strings.HasPrefix(content, "[") && strings.HasSuffix(content, "]")) {
		return content, nil
	}

	// Pattern 4: Find first complete JSON object/array in the text
	firstBrace := strings.Index(content, "{")
	firstBracket := strings.Index(content, "[")

	var startPos, endPos int
	endChar := "}"

	// Determine whether to look for object {} or array []
	if firstBrace != -1 && (firstBracket == -1 || firstBrace < firstBracket) {
		startPos = firstBrace
		endChar = "}"
	} else if firstBracket != -1 {
		startPos = firstBracket
		endChar = "]"
	} else {
		return "", fmt.Errorf("no JSON object or array found in response")
	}

	log.Println(endChar)

	// Find the matching closing brace/bracket
	braceCount := 0
	inString := false
	escaped := false

	for i := startPos; i < len(content); i++ {
		char := content[i]

		if escaped {
			escaped = false
			continue
		}

		if char == '\\' {
			escaped = true
			continue
		}

		if char == '"' {
			inString = !inString
			continue
		}

		if !inString {
			if char == '{' || char == '[' {
				braceCount++
			} else if char == '}' || char == ']' {
				braceCount--
				if braceCount == 0 {
					endPos = i + 1
					break
				}
			}
		}
	}

	if endPos > startPos {
		return content[startPos:endPos], nil
	}

	return "", fmt.Errorf("no valid JSON found in response: %s", content)
}
