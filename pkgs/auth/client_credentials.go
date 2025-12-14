package auth

import (
	"context"
	"errors"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/providers"
	"strings"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"golang.org/x/oauth2/jwt"
)

func NewClientCredentialsAuthorizer(config *db.ClientCredentialsConfig) (OAuth2, error) {
	if config == nil {
		return nil, errors.New("client credentials config is nil")
	}
	switch config.ProviderType {
	case providers.GOOGLE_PROVIDER:
		jwtConfig := jwt.Config{
			Email:        config.ClientEmail,
			PrivateKey:   []byte(strings.ReplaceAll(config.PrivateKey, "\\n", "\n")),
			PrivateKeyID: config.PrivateKeyId,
			Scopes:       config.Scopes,
			TokenURL:     google.JWTTokenURL,
		}
		if config.Subject != "" {
			jwtConfig.Subject = config.Subject
		}
		return &ClientCredentialsAuthorizerImpl{
			ClientCredentialConfig: &jwtConfig,
		}, nil
	}
	return nil, errors.New("unsupported provider type for client credentials: " + string(config.ProviderType))
}

type ClientCredentialsAuthorizerImpl struct {
	ClientCredentialConfig *jwt.Config
}

func (c *ClientCredentialsAuthorizerImpl) RefreshToken(ctx context.Context, refreshToken string) (*oauth2.Token, error) {
	return c.ClientCredentialConfig.TokenSource(ctx).Token()
}
