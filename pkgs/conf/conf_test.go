package conf

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestLoadEnvFile(t *testing.T) {
	filePath := filepath.Join("..", "..", ".env")
	provider := NewDotEnvProvider(filePath)
	assert.NotNil(t, provider)
}
