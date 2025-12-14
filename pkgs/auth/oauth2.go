package auth

import (
	"context"
	"sadbhavana/tree-project/pkgs/db"

	"golang.org/x/oauth2"
)

type UserOAuth2 interface {
	AuthCodeUrl(state db.OAuth2Config) (string, error)
	ExchangeCode(ctx context.Context, code string) (*oauth2.Token, error)
	OAuth2
}

type OAuth2 interface {
	RefreshToken(ctx context.Context, refreshToken string) (*oauth2.Token, error)
}
