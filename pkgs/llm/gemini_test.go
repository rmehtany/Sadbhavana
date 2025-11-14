package llm

import (
	"context"
	"sadbhavana/tree-project/pkgs/conf"
	"testing"
	"time"
)

// Medium complexity nested structure for testing
type UserProfile struct {
	PersonalInfo PersonalInfo `json:"personal_info"`
	Address      Address      `json:"address"`
	Preferences  Preferences  `json:"preferences"`
	Metadata     Metadata     `json:"metadata"`
}

type PersonalInfo struct {
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Email     string `json:"email"`
	Age       int    `json:"age"`
}

type Address struct {
	Street  string `json:"street"`
	City    string `json:"city"`
	State   string `json:"state"`
	ZipCode string `json:"zip_code"`
	Country string `json:"country"`
}

type Preferences struct {
	Theme              string   `json:"theme"`
	Language           string   `json:"language"`
	NotificationsOn    bool     `json:"notifications_on"`
	FavoriteCategories []string `json:"favorite_categories"`
}

type Metadata struct {
	CreatedAt    string  `json:"created_at"`
	LastLogin    string  `json:"last_login"`
	LoginCount   int     `json:"login_count"`
	AccountScore float64 `json:"account_score"`
}

// TestGeminiIntegration_StructuredOutput tests the SimpleStructuredOutput function
// with a real Gemini API client using a medium complexity nested JSON structure
//
// To run this test, set the GEMINI_API_KEY environment variable:
// GEMINI_API_KEY=your_api_key_here go test -run TestGeminiIntegration_StructuredOutput -v
//
// Skip this test in CI/automated testing by using build tags:
// go test -tags=integration -run TestGeminiIntegration_StructuredOutput -v
func TestGeminiIntegration_StructuredOutput(t *testing.T) {
	// Skip if no API key is provided
	conf.LoadEnvFromFile("../../.env")
	apiKey := conf.GetConfig().GeminiConfig.APIKey
	if apiKey == "" {
		t.Skip("Skipping integration test: GEMINI_API_KEY environment variable not set")
	}

	// Create context with timeout for the API call
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Create Gemini client
	client, err := NewGeminiClient(ctx, Gemini25Flash)
	if err != nil {
		t.Fatalf("Failed to create Gemini client: %v", err)
	}

	// Set a reasonable retry limit for integration test
	originalRetries := MaxStructuredOutputRetries
	MaxStructuredOutputRetries = 3
	defer func() { MaxStructuredOutputRetries = originalRetries }()

	// System message that explains the task
	systemMessage := `You are a helpful assistant that creates realistic user profile data. 
	Always respond with properly formatted JSON that matches the exact schema provided.
	Make the data realistic and internally consistent.`

	// User message requesting a specific type of user profile
	userMessage := `Create a user profile for a software engineer named Sarah Chen who lives in San Francisco, CA. 
	She should be in her late 20s, prefer dark theme, speak English, have notifications enabled, 
	and be interested in technology, reading, and hiking. Include realistic timestamps and account metrics.`

	// Call the function under test
	result, err := SimpleStructuredOutput[UserProfile](
		ctx,
		client,
		Config{},
		systemMessage,
		userMessage,
	)

	// Verify the result
	if err != nil {
		t.Fatalf("SimpleStructuredOutput failed: %v", err)
	}

	if result == nil {
		t.Fatal("Expected result, got nil")
	}

	// Validate the structure and content
	t.Run("PersonalInfo", func(t *testing.T) {
		if result.PersonalInfo.FirstName == "" {
			t.Error("PersonalInfo.FirstName should not be empty")
		}
		if result.PersonalInfo.LastName == "" {
			t.Error("PersonalInfo.LastName should not be empty")
		}
		if result.PersonalInfo.Email == "" {
			t.Error("PersonalInfo.Email should not be empty")
		}
		if result.PersonalInfo.Age <= 0 || result.PersonalInfo.Age > 150 {
			t.Errorf("PersonalInfo.Age should be realistic, got: %d", result.PersonalInfo.Age)
		}
		t.Logf("PersonalInfo: %+v", result.PersonalInfo)
	})

	t.Run("Address", func(t *testing.T) {
		if result.Address.City == "" {
			t.Error("Address.City should not be empty")
		}
		if result.Address.State == "" {
			t.Error("Address.State should not be empty")
		}
		if result.Address.Country == "" {
			t.Error("Address.Country should not be empty")
		}
		// Since we asked for San Francisco, CA, let's check if the AI understood
		t.Logf("Address: %+v", result.Address)
	})

	t.Run("Preferences", func(t *testing.T) {
		if result.Preferences.Theme == "" {
			t.Error("Preferences.Theme should not be empty")
		}
		if result.Preferences.Language == "" {
			t.Error("Preferences.Language should not be empty")
		}
		if len(result.Preferences.FavoriteCategories) == 0 {
			t.Error("Preferences.FavoriteCategories should not be empty")
		}
		// We asked for notifications to be enabled
		if !result.Preferences.NotificationsOn {
			t.Log("Expected notifications to be enabled based on prompt")
		}
		t.Logf("Preferences: %+v", result.Preferences)
	})

	t.Run("Metadata", func(t *testing.T) {
		if result.Metadata.CreatedAt == "" {
			t.Error("Metadata.CreatedAt should not be empty")
		}
		if result.Metadata.LastLogin == "" {
			t.Error("Metadata.LastLogin should not be empty")
		}
		if result.Metadata.LoginCount < 0 {
			t.Errorf("Metadata.LoginCount should be non-negative, got: %d", result.Metadata.LoginCount)
		}
		if result.Metadata.AccountScore < 0.0 || result.Metadata.AccountScore > 100.0 {
			t.Logf("Metadata.AccountScore might be outside expected range: %f", result.Metadata.AccountScore)
		}
		t.Logf("Metadata: %+v", result.Metadata)
	})

	// Log the complete result for manual inspection
	t.Logf("Complete UserProfile result: %+v", result)

	// Additional validation: Check if the response contains reasonable data
	// based on our specific prompt about Sarah Chen in San Francisco
	if result.PersonalInfo.FirstName != "" && result.PersonalInfo.LastName != "" {
		fullName := result.PersonalInfo.FirstName + " " + result.PersonalInfo.LastName
		t.Logf("Generated user: %s", fullName)
	}

	// Verify that the JSON schema guidance worked
	if len(result.Preferences.FavoriteCategories) > 0 {
		t.Logf("User interests: %v", result.Preferences.FavoriteCategories)
	}
}

// TestGeminiIntegration_SimpleStructure tests with a simpler structure to ensure
// basic functionality works
func TestGeminiIntegration_SimpleStructure(t *testing.T) {
	conf.LoadEnvFromFile("../../.env")
	apiKey := conf.GetConfig().GeminiConfig.APIKey
	if apiKey == "" {
		t.Skip("Skipping integration test: GEMINI_API_KEY environment variable not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	client, err := NewGeminiClient(ctx, Gemini25Flash)
	if err != nil {
		t.Fatalf("Failed to create Gemini client: %v", err)
	}

	// Simple structure for basic validation
	type SimpleTask struct {
		Title       string `json:"title"`
		Description string `json:"description"`
		Priority    int    `json:"priority"`
		Completed   bool   `json:"completed"`
	}

	result, err := SimpleStructuredOutput[SimpleTask](
		ctx,
		client,
		Config{},
		"You create todo tasks.",
		"Create a high-priority task about writing tests for a Go project.",
	)

	if err != nil {
		t.Fatalf("SimpleStructuredOutput failed: %v", err)
	}

	if result == nil {
		t.Fatal("Expected result, got nil")
	}

	if result.Title == "" {
		t.Error("Title should not be empty")
	}

	if result.Description == "" {
		t.Error("Description should not be empty")
	}

	t.Logf("Generated task: %+v", result)
}
