package auth

import (
	"context"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/pkgs/locker"
	"sadbhavana/tree-project/pkgs/providers"

	"github.com/juju/errors"
	"golang.org/x/oauth2"
)

var ActiveTokens map[providers.ProviderType]*oauth2.Token

const tokenLockKey = "auth_token_lock:"

func GetActiveToken(ctx context.Context, q *db.Queries, providerType providers.ProviderType) (oauth2.Token, error) {
	token, ok := ActiveTokens[providerType]
	if ok {
		return *token, nil
	}

	providerName := string(providerType)

	getAuthForProviderOutput, err := db.GetAuthForProvider(ctx, q, providerName)
	if err != nil {
		return oauth2.Token{}, errors.Annotatef(err, "failed to get auth for provider %s", providerType)
	}

	if getAuthForProviderOutput.ActiveToken != nil && getAuthForProviderOutput.ActiveToken.Valid() {
		ActiveTokens[providerType] = getAuthForProviderOutput.ActiveToken
		return *getAuthForProviderOutput.ActiveToken, nil
	}

	redisLocker := locker.NewRedisLocker(ctx, tokenLockKey)
	redisLock, err := redisLocker.Obtain(ctx, providerName, nil)
	if err != nil {
		return oauth2.Token{}, errors.Annotatef(err, "failed to obtain redis lock")
	}
	defer redisLock.Release(ctx)

	// Re-check if another process has already refreshed the token
	token, ok = ActiveTokens[providerType]
	if ok && token.Valid() {
		return *token, nil
	}

	oauth2Client, err := GetOAuth2Client(getAuthForProviderOutput.AuthConfig)
	if err != nil {
		return oauth2.Token{}, errors.Annotatef(err, "failed to get OAuth2 client")
	}

	// Use the oauth2Client to refresh the token
	newToken, err := oauth2Client.RefreshToken(ctx, getAuthForProviderOutput.ActiveToken.RefreshToken)
	if err != nil {
		return oauth2.Token{}, errors.Annotatef(err, "failed to refresh token")
	}
	if newToken == nil {
		return oauth2.Token{}, errors.New("refreshed token is nil")
	}

	updateParams := db.UpdateAuthTokenParams{
		ProviderName: providerName,
		NewToken:     *newToken,
	}

	err = db.UpdateTokenForProvider(ctx, q, updateParams)
	if err != nil {
		return oauth2.Token{}, errors.Annotatef(err, "failed to update token for provider %s", providerType)
	}

	ActiveTokens[providerType] = newToken
	return *newToken, nil
}
