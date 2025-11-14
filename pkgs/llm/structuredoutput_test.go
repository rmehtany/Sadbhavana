package llm

import (
	"context"
	"fmt"
	"io"
	"sadbhavana/tree-project/pkgs/file"

	"strings"
	"testing"
	"time"
)

// Test structs
type TestPerson struct {
	Name   string   `json:"name"`
	Age    int      `json:"age"`
	Email  string   `json:"email"`
	Skills []string `json:"skills"`
	Active bool     `json:"active"`
}

type TestSimple struct {
	Message string `json:"message"`
	Count   int    `json:"count"`
}

// Mock client for testing
type mockClient struct {
	responses []string
	callCount int
	shouldErr bool
}

func (m *mockClient) UploadFile(ctx context.Context, filename string, mimeType file.MimeType, data io.Reader) (*file.FileInfo, error) {
	return nil, fmt.Errorf("not implemented in mock")
}

func (m *mockClient) Prompt(ctx context.Context, req *Request) (*Response, error) {
	if m.shouldErr {
		return nil, fmt.Errorf("mock client error")
	}

	if m.callCount >= len(m.responses) {
		return nil, fmt.Errorf("no more mock responses available")
	}

	response := &Response{
		Content: m.responses[m.callCount],
		Usage:   TokenUsage{PromptTokens: 100, CompletionTokens: 50, TotalTokens: 150},
	}
	m.callCount++

	return response, nil
}

func TestSimpleStructuredOutput_Success_FirstAttempt(t *testing.T) {
	client := &mockClient{
		responses: []string{
			"```json\n{\"name\":\"John Doe\",\"age\":30,\"email\":\"john@example.com\",\"skills\":[\"Go\",\"Python\"],\"active\":true}\n```",
		},
	}

	ctx := context.Background()
	result, err := SimpleStructuredOutput[TestPerson](ctx, client, Config{}, "You are helpful", "Create a person profile")

	if err != nil {
		t.Fatalf("Expected success, got error: %v", err)
	}

	if result == nil {
		t.Fatal("Expected result, got nil")
	}

	expected := &TestPerson{
		Name:   "John Doe",
		Age:    30,
		Email:  "john@example.com",
		Skills: []string{"Go", "Python"},
		Active: true,
	}

	if result.Name != expected.Name || result.Age != expected.Age {
		t.Errorf("Expected %+v, got %+v", expected, result)
	}

	if client.callCount != 1 {
		t.Errorf("Expected 1 API call, got %d", client.callCount)
	}
}

func TestSimpleStructuredOutput_Success_WithRetry(t *testing.T) {
	client := &mockClient{
		responses: []string{
			"This is not valid JSON at all",
			"Still not JSON, just text response",
			"```json\n{\"message\":\"Success on third try\",\"count\":42}\n```",
		},
	}

	ctx := context.Background()
	result, err := SimpleStructuredOutput[TestSimple](ctx, client, Config{}, "You are helpful", "Create a simple object")

	if err != nil {
		t.Fatalf("Expected success, got error: %v", err)
	}

	if result == nil {
		t.Fatal("Expected result, got nil")
	}

	if result.Message != "Success on third try" || result.Count != 42 {
		t.Errorf("Expected {Success on third try, 42}, got {%s, %d}", result.Message, result.Count)
	}

	if client.callCount != 3 {
		t.Errorf("Expected 3 API calls, got %d", client.callCount)
	}
}

func TestSimpleStructuredOutput_FailureAfterMaxRetries(t *testing.T) {
	// Save original value and restore after test
	originalRetries := MaxStructuredOutputRetries
	defer func() { MaxStructuredOutputRetries = originalRetries }()

	MaxStructuredOutputRetries = 2

	client := &mockClient{
		responses: []string{
			"Invalid response 1",
			"Invalid response 2",
			"This should not be reached",
		},
	}

	ctx := context.Background()
	result, err := SimpleStructuredOutput[TestSimple](ctx, client, Config{}, "You are helpful", "Create a simple object")

	if err == nil {
		t.Fatal("Expected error, got success")
	}

	if result != nil {
		t.Errorf("Expected nil result, got %+v", result)
	}

	if client.callCount != 2 {
		t.Errorf("Expected 2 API calls, got %d", client.callCount)
	}

	expectedErrMsg := "failed after 2 attempts"
	if !strings.Contains(err.Error(), expectedErrMsg) {
		t.Errorf("Expected error to contain '%s', got: %v", expectedErrMsg, err)
	}
}

func TestSimpleStructuredOutput_ClientError(t *testing.T) {
	client := &mockClient{
		shouldErr: true,
	}

	ctx := context.Background()
	result, err := SimpleStructuredOutput[TestSimple](ctx, client, Config{}, "You are helpful", "Create a simple object")

	if err == nil {
		t.Fatal("Expected error, got success")
	}

	if result != nil {
		t.Errorf("Expected nil result, got %+v", result)
	}

	expectedErrMsg := "failed to call LLM on attempt 1"
	if !strings.Contains(err.Error(), expectedErrMsg) {
		t.Errorf("Expected error to contain '%s', got: %v", expectedErrMsg, err)
	}
}

func TestExtractJSONFromResponse_VariousFormats(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
		wantErr  bool
	}{
		{
			name:     "JSON with backticks and json label",
			input:    "```json\n{\"key\": \"value\"}\n```",
			expected: "{\"key\": \"value\"}",
			wantErr:  false,
		},
		{
			name:     "JSON with backticks no label",
			input:    "```\n{\"key\": \"value\"}\n```",
			expected: "{\"key\": \"value\"}",
			wantErr:  false,
		},
		{
			name:     "Direct JSON object",
			input:    "{\"key\": \"value\"}",
			expected: "{\"key\": \"value\"}",
			wantErr:  false,
		},
		{
			name:     "JSON array",
			input:    "[{\"key\": \"value\"}]",
			expected: "[{\"key\": \"value\"}]",
			wantErr:  false,
		},
		{
			name:     "JSON embedded in text",
			input:    "Here is the response: {\"key\": \"value\"} Hope this helps!",
			expected: "{\"key\": \"value\"}",
			wantErr:  false,
		},
		{
			name:     "Complex nested JSON",
			input:    "```json\n{\"user\": {\"name\": \"John\", \"data\": [1, 2, 3]}, \"active\": true}\n```",
			expected: "{\"user\": {\"name\": \"John\", \"data\": [1, 2, 3]}, \"active\": true}",
			wantErr:  false,
		},
		{
			name:     "No JSON found",
			input:    "This is just regular text with no JSON",
			expected: "",
			wantErr:  true,
		},
		{
			name:     "Malformed backticks",
			input:    "```\nThis is not JSON\n```",
			expected: "",
			wantErr:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := ExtractJSONFromResponse(tt.input)

			if tt.wantErr {
				if err == nil {
					t.Errorf("Expected error, got success with result: %s", result)
				}
				return
			}

			if err != nil {
				t.Errorf("Expected success, got error: %v", err)
				return
			}

			if result != tt.expected {
				t.Errorf("Expected %q, got %q", tt.expected, result)
			}
		})
	}
}

func TestSimpleStructuredOutput_RetryMessageGeneration(t *testing.T) {
	client := &mockClient{
		responses: []string{
			"Bad response 1",
			"```json\n{\"message\":\"Retry worked\",\"count\":1}\n```",
		},
	}

	ctx := context.Background()
	_, err := SimpleStructuredOutput[TestSimple](ctx, client, Config{}, "System message", "User message")

	if err != nil {
		t.Fatalf("Expected success, got error: %v", err)
	}

	// We can't directly test the retry message content without exposing internals,
	// but we can verify that retries happened
	if client.callCount != 2 {
		t.Errorf("Expected 2 API calls (1 original + 1 retry), got %d", client.callCount)
	}
}

func TestSimpleStructuredOutput_MaxRetriesCustomization(t *testing.T) {
	// Save original value and restore after test
	originalRetries := MaxStructuredOutputRetries
	defer func() { MaxStructuredOutputRetries = originalRetries }()

	MaxStructuredOutputRetries = 5

	client := &mockClient{
		responses: []string{
			"Bad 1", "Bad 2", "Bad 3", "Bad 4", "Bad 5", "Should not reach this",
		},
	}

	ctx := context.Background()
	_, err := SimpleStructuredOutput[TestSimple](ctx, client, Config{}, "System", "User")

	if err == nil {
		t.Fatal("Expected error after max retries")
	}

	if client.callCount != 5 {
		t.Errorf("Expected exactly 5 calls, got %d", client.callCount)
	}

	expectedErrMsg := "failed after 5 attempts"
	if !strings.Contains(err.Error(), expectedErrMsg) {
		t.Errorf("Expected error to mention 5 attempts, got: %v", err)
	}
}

func TestGetTypeName(t *testing.T) {
	tests := []struct {
		name     string
		testFunc func() string
		expected string
	}{
		{
			name:     "simple struct",
			testFunc: func() string { return getTypeName[TestPerson]() },
			expected: "TestPerson",
		},
		{
			name:     "simple type",
			testFunc: func() string { return getTypeName[string]() },
			expected: "string",
		},
		{
			name:     "int type",
			testFunc: func() string { return getTypeName[int]() },
			expected: "int",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.testFunc()
			// Just check that we get some reasonable name (exact format may vary)
			if result == "" || result == "unknown" {
				t.Errorf("Expected meaningful type name, got: %s", result)
			}
		})
	}
}

// Rich struct for schema testing
type SampleUser struct {
	ID          int            `json:"id"`
	Name        string         `json:"name" jsonschema:"title=the name,description=The name of a friend,example=joe,example=lucy,default=alex"`
	Friends     []int          `json:"friends,omitempty" jsonschema_description:"The list of IDs, omitted when empty"`
	Tags        map[string]any `json:"tags,omitempty" jsonschema_extras:"a=b,foo=bar,foo=bar1"`
	BirthDate   time.Time      `json:"birth_date,omitempty" jsonschema:"oneof_required=date"`
	YearOfBirth string         `json:"year_of_birth,omitempty" jsonschema:"oneof_required=year"`
	Metadata    any            `json:"metadata,omitempty" jsonschema:"oneof_type=string;array"`
	FavColor    string         `json:"fav_color,omitempty" jsonschema:"enum=red,enum=green,enum=blue"`
}

func TestGenerateEnhancedSystemMessage_SampleUserSchema(t *testing.T) {
	systemMsg := "Test system message"
	msg, err := generateEnhancedSystemMessage[SampleUser](systemMsg)
	if err != nil {
		t.Fatalf("generateEnhancedSystemMessage failed: %v", err)
	}

	// Check system message is included
	if !strings.Contains(msg, systemMsg) {
		t.Errorf("System message missing from output")
	}

	// Check type name
	if !strings.Contains(msg, "SampleUser") {
		t.Errorf("Type name missing from output")
	}

	// Check for schema fields and descriptions
	wantFields := []string{"id", "name", "friends", "tags", "birth_date", "year_of_birth", "metadata", "fav_color"}
	for _, field := range wantFields {
		if !strings.Contains(msg, field) {
			t.Errorf("Field %s missing from schema output", field)
		}
	}

	// Check for description and title
	if !strings.Contains(msg, "The name of a friend") {
		t.Errorf("Description for 'name' missing from schema output")
	}
	if !strings.Contains(msg, "the name") {
		t.Errorf("Title for 'name' missing from schema output")
	}

	// Check for enum values
	for _, color := range []string{"red", "green", "blue"} {
		if !strings.Contains(msg, color) {
			t.Errorf("Enum value %s missing from schema output", color)
		}
	}

	// Check for oneOf and required constructs for birth_date/year_of_birth
	if !strings.Contains(msg, "\"oneOf\"") {
		t.Errorf("oneOf construct missing from schema output")
	}
	if !strings.Contains(msg, "\"required\"") {
		t.Errorf("required field missing from schema output")
	}
	// Check for oneOf type for metadata property
	if !strings.Contains(msg, "metadata") || !strings.Contains(msg, "oneOf") {
		t.Errorf("oneOf type for metadata missing from schema output")
	}

	// Check for formatting instructions
	if !strings.Contains(msg, "STRICT FORMATTING REQUIREMENTS") {
		t.Errorf("Formatting instructions missing from output")
	}
	if !strings.Contains(msg, "```json") {
		t.Errorf("JSON code block instruction missing from output")
	}
}

// Benchmark test
func BenchmarkSimpleStructuredOutput(b *testing.B) {
	client := &mockClient{
		responses: make([]string, b.N),
	}

	// Fill with valid JSON responses
	for i := 0; i < b.N; i++ {
		client.responses[i] = "```json\n{\"message\":\"test\",\"count\":42}\n```"
	}

	ctx := context.Background()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		client.callCount = 0 // Reset for each iteration
		_, err := SimpleStructuredOutput[TestSimple](ctx, client, Config{}, "System", "User")
		if err != nil {
			b.Fatalf("Benchmark failed: %v", err)
		}
	}
}
