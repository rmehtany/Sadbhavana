package auth

import (
	"errors"
	"sadbhavana/tree-project/pkgs/db"
)

func GetOAuth2Client(auth *db.AuthConfig) (OAuth2, error) {
	if auth == nil {
		return nil, errors.New("auth is nil")
	}
	switch auth.AuthType {
	case db.AuthTypeClientCredentials:
		return NewClientCredentialsAuthorizer(auth.ClientCredentialsConfig)
	default:
		return nil, errors.New("auth type currently unsupported: " + string(auth.AuthType))
	}
}
