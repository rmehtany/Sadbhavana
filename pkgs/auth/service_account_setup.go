package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/providers"
)

// SetupGoogleServiceAccountFromEnv loads service account credentials from
// GOOGLE_SERVICE_ACCOUNT_JSON environment variable and stores in database.
// This is useful for automated deployment and testing environments.
//
// The environment variable should contain the full JSON content of the
// service account key file downloaded from Google Cloud Console.
//
// Example usage:
//
//	export GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"...","private_key":"..."}'
//	err := auth.SetupGoogleServiceAccountFromEnv(ctx, queries)
func SetupGoogleServiceAccountFromEnv(ctx context.Context, q *db.Queries) error {
	jsonData := os.Getenv("GOOGLE_SERVICE_ACCOUNT_JSON")
	if jsonData == "" {
		return fmt.Errorf("GOOGLE_SERVICE_ACCOUNT_JSON environment variable not set")
	}

	var serviceAccount struct {
		ClientEmail  string `json:"client_email"`
		PrivateKey   string `json:"private_key"`
		PrivateKeyID string `json:"private_key_id"`
	}

	if err := json.Unmarshal([]byte(jsonData), &serviceAccount); err != nil {
		return fmt.Errorf("failed to parse service account JSON: %w", err)
	}

	authData := db.AuthData{
		ProviderName: string(providers.GOOGLE_PROVIDER),
		AuthConfig: &db.AuthConfig{
			AuthType: db.AuthTypeClientCredentials,
			ClientCredentialsConfig: &db.ClientCredentialsConfig{
				ProviderType: providers.GOOGLE_PROVIDER,
				ClientEmail:  serviceAccount.ClientEmail,
				PrivateKey:   serviceAccount.PrivateKey,
				PrivateKeyId: serviceAccount.PrivateKeyID,
				Scopes:       []string{"https://www.googleapis.com/auth/drive"},
			},
		},
	}

	return db.CreateAuthForProvider(ctx, q, authData)
}

// SetupGoogleServiceAccountFromFile loads service account credentials from
// a JSON file and stores in database.
//
// Example usage:
//
//	err := auth.SetupGoogleServiceAccountFromFile(ctx, queries, "service-account.json")
func SetupGoogleServiceAccountFromFile(ctx context.Context, q *db.Queries, filepath string) error {
	jsonData, err := os.ReadFile(filepath)
	if err != nil {
		return fmt.Errorf("failed to read service account file: %w", err)
	}

	var serviceAccount struct {
		ClientEmail  string `json:"client_email"`
		PrivateKey   string `json:"private_key"`
		PrivateKeyID string `json:"private_key_id"`
	}

	if err := json.Unmarshal(jsonData, &serviceAccount); err != nil {
		return fmt.Errorf("failed to parse service account JSON: %w", err)
	}

	authData := db.AuthData{
		ProviderName: string(providers.GOOGLE_PROVIDER),
		AuthConfig: &db.AuthConfig{
			AuthType: db.AuthTypeClientCredentials,
			ClientCredentialsConfig: &db.ClientCredentialsConfig{
				ProviderType: providers.GOOGLE_PROVIDER,
				ClientEmail:  serviceAccount.ClientEmail,
				PrivateKey:   serviceAccount.PrivateKey,
				PrivateKeyId: serviceAccount.PrivateKeyID,
				Scopes:       []string{"https://www.googleapis.com/auth/drive"},
			},
		},
	}

	return db.CreateAuthForProvider(ctx, q, authData)
}
