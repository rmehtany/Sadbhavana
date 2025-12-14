package cache

import (
	"context"
	"log"
	"sadbhavana/tree-project/pkgs/conf"
	"testing"

	"github.com/stretchr/testify/assert"
)

type TestStruct struct {
	A string `json:"a"`
}

func TestRedisCache(t *testing.T) {
	// create redis cache

	ctx := context.Background()
	err := conf.LoadEnvFromFile("../../.env")
	assert.NoError(t, err, "Should load env file")
	cfg := conf.GetConfig()
	log.Printf("Redis URL: %s", cfg.RedisConfig.URL)

	ch, error := NewRedisFromConnectionString[TestStruct](cfg.RedisConfig.URL)

	assert.NoError(t, error, "Should not error")

	err = ch.Set(ctx, "test", TestStruct{
		A: "test",
	}, nil)

	assert.NoError(t, err)

	v, err := ch.Get(ctx, "test")

	assert.NoError(t, err)

	assert.NotNil(t, v)
	assert.Equal(t, "test", v.A)
}
