package locker

import (
	"context"
	"sadbhavana/tree-project/pkgs/conf"
	"time"

	"github.com/bsm/redislock"
	"github.com/redis/go-redis/v9"
)

type RedisLocker struct {
	client *redislock.Client
	prefix string
}

func NewRedisLocker(ctx context.Context, prefix string) *RedisLocker {
	cfg := conf.GetConfig()

	opt, err := redis.ParseURL(cfg.RedisConfig.URL)
	if err != nil {
		panic(err)
	}

	client := redis.NewClient(opt)

	if err := client.Ping(ctx).Err(); err != nil {
		panic(err)
	}

	return &RedisLocker{
		client: redislock.New(client),
		prefix: prefix,
	}
}

func (r *RedisLocker) Obtain(ctx context.Context, key string, expiry *time.Duration) (*redislock.Lock, error) {
	lockKey := r.prefix + key
	if expiry == nil {
		defaultExpiry := 30 * time.Second
		expiry = &defaultExpiry
	}
	lock, err := r.client.Obtain(ctx, lockKey, *expiry, nil)
	if err == redislock.ErrNotObtained {
		return nil, nil
	}
	return lock, err
}
