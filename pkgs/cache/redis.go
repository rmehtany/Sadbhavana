package cache

import (
	"context"
	"encoding/json"
	"sadbhavana/tree-project/pkgs/conf"
	"sadbhavana/tree-project/pkgs/utils"
	"time"

	"github.com/juju/errors"
	"github.com/redis/go-redis/v9"
)

func NewRedisFromEnv[T any]() (Cache[T], error) {
	cfg := conf.GetConfig()
	connStr := cfg.RedisConfig.URL
	if connStr == "" {
		return nil, errors.New("REDIS_URL is not set")
	}
	// Use the connection string to create the Redis client

	return NewRedisFromConnectionString[T](connStr)
}

func NewRedisFromConnectionString[T any](connStr string) (Cache[T], error) {
	opt, err := redis.ParseURL(connStr)

	if err != nil {
		return nil, errors.Annotatef(err, "failed to parse redis url")
	}

	rdb := redis.NewClient(opt)

	if rdb == nil {
		return nil, errors.New("failed to create redis client")
	}

	// Test the connection
	_, err = rdb.Ping(context.Background()).Result()
	if err != nil {
		return nil, err
	}

	return RedisImpl[T]{
		client:         rdb,
		ExpirationTime: &DefaultDuration,
	}, nil
}

// Set stores a value in Redis with JSON serialization
func (r RedisImpl[T]) Set(ctx context.Context, key string, val T, duration *time.Duration) error {

	err := utils.ValidateStruct(val)

	if err != nil {
		return errors.Annotatef(err, "validator failed the struct %v", val)
	}

	// Serialize the value to JSON
	data, err := json.Marshal(val)
	if err != nil {
		return err
	}

	// Store in Redis with expiration
	return r.client.Set(ctx, key, data, DefaultDuration).Err()
}

// Get retrieves and deserializes a value from Redis
func (r RedisImpl[T]) Get(ctx context.Context, key string) (*T, error) {
	// Get the JSON data from Redis
	data, err := r.client.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			// Key doesn't exist
			return nil, nil
		}
		return nil, err
	}

	// Deserialize from JSON
	var val T
	if err := json.Unmarshal([]byte(data), &val); err != nil {
		return nil, err
	}

	return &val, nil
}

// Close closes the Redis connection
func (r RedisImpl[T]) Close() error {
	return r.client.Close()
}
