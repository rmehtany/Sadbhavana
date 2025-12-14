package cache

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

type Cache[T any] interface {
	Set(ctx context.Context, key string, val T, duration *time.Duration) error
	Get(ctx context.Context, key string) (*T, error)
	Close() error
}

var DefaultDuration time.Duration = time.Hour * 24

// Redis
type RedisImpl[T any] struct {
	client         *redis.Client
	ExpirationTime *time.Duration
}

type RedisOpts struct {
	IsTls bool
}
