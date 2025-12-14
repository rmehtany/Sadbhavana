package db

import (
	"context"
	"sadbhavana/tree-project/pkgs/providers"

	"golang.org/x/oauth2"
)

type AuthType string

const (
	AuthTypeBasic             AuthType = "basic"
	AuthTypeUserOAuth2        AuthType = "user_oauth2"
	AuthTypeClientCredentials AuthType = "client_credentials"
)

type AuthConfig struct {
	AuthType                AuthType                 `json:"auth_type" validate:"required,oneof=basic oauth2 client_credentials"`
	BasicAuthConfig         *BasicAuthConfig         `json:"basic,omitempty"`
	Oauth2Config            *OAuth2Config            `json:"oauth2,omitempty"`
	ClientCredentialsConfig *ClientCredentialsConfig `json:"client_credentials,omitempty"`
}

type BasicAuthConfig struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type OAuth2Config struct {
	ProviderType string   `json:"provider_type"`
	ClientId     string   `json:"client_id"`
	ClientSecret string   `json:"client_secret"`
	RedirectUri  string   `json:"redirect_uri"`
	Scopes       []string `json:"scopes"`
}

type ClientCredentialsConfig struct {
	Subject      string                 `json:"subject,omitempty"`
	ProviderType providers.ProviderType `json:"provider_type"`
	ClientEmail  string                 `json:"client_email"`
	PrivateKey   string                 `json:"private_key"`
	PrivateKeyId string                 `json:"private_key_id"`
	Scopes       []string               `json:"scopes"`
}

type AuthData struct {
	ProviderName string        `json:"provider_name,omitempty"`
	AuthConfig   *AuthConfig   `json:"auth_config,omitempty"`
	ActiveToken  *oauth2.Token `json:"active_token,omitempty"`
}

type UpdateAuthTokenParams struct {
	ProviderName string       `json:"provider_name"`
	NewToken     oauth2.Token `json:"new_token"`
}

func CreateAuthForProvider(ctx context.Context, q *Queries, authData AuthData) error {
	_, err := callProcedureWithJSON[AuthData, struct{}](ctx, q, "core", "P_CreateAuthForProvider", authData)
	return err
}

func GetAuthForProvider(ctx context.Context, q *Queries, providerName string) (AuthData, error) {
	return callProcedureWithJSON[string, AuthData](ctx, q, "core", "P_GetAuthForProvider", providerName)
}

func UpdateTokenForProvider(ctx context.Context, q *Queries, params UpdateAuthTokenParams) error {
	_, err := callProcedureWithJSON[UpdateAuthTokenParams, struct{}](ctx, q, "core", "P_UpdateTokenForProvider", params)
	return err
}
