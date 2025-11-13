package conf

import (
	"context"
	"fmt"
	"os"
	"sadbhavana/tree-project/pkgs/utils"
	"strings"

	"github.com/sethvargo/go-envconfig"
)

type Config struct {
	Version        int
	BaseConfig     BaseConfig
	PostgresConfig PostgresConfig
}

type BaseConfig struct {
	Port int `env:"PORT" validate:"required,min=1,max=65535"`
}

type PostgresConfig struct {
	Host           string `env:"DB_HOST,required" validate:"required"`
	Port           string `env:"DB_PORT,required" validate:"required"`
	User           string `env:"DB_USER,required" validate:"required"`
	Password       string `env:"DB_PASSWORD,required" validate:"required"`
	Database       string `env:"DB_NAME,required" validate:"required"`
	SSLMode        string `env:"DB_SSLMODE,required" validate:"required,oneof=disable require verify-ca verify-full"`
	ChannelBinding string `env:"DB_CHANNEL_BINDING"`
}

func (a *PostgresConfig) DBURI() string {
	if a.ChannelBinding != "" {
		return "postgres://" + a.User + ":" + a.Password + "@" + a.Host + ":" + a.Port + "/" + a.Database + "?sslmode=" + a.SSLMode + "&channel_binding=" + a.ChannelBinding
	}
	return "postgres://" + a.User + ":" + a.Password + "@" + a.Host + ":" + a.Port + "/" + a.Database + "?sslmode=" + a.SSLMode
}

var globalCfg *Config = &Config{}

// ConfigProvider defines the interface for configuration providers
type ConfigProvider interface {
	// Name returns the provider name for logging/debugging
	Name() string
	// Lookup returns the value for the given key, and whether it was found
	Lookup(ctx context.Context, key string) (string, bool)
}

// EnvProvider loads configuration from environment variables
type EnvProvider struct{}

func (e *EnvProvider) Name() string {
	return "environment"
}

func (e *EnvProvider) Lookup(ctx context.Context, key string) (string, bool) {
	value := os.Getenv(key)
	return value, value != ""
}

// DotEnvProvider loads configuration from .env files
type DotEnvProvider struct {
	envMap map[string]string
}

func NewDotEnvProvider(filePath string) *DotEnvProvider {
	provider := &DotEnvProvider{
		envMap: make(map[string]string),
	}
	provider.loadFromFile(filePath)
	return provider
}

func (d *DotEnvProvider) Name() string {
	return "dotenv"
}

func (d *DotEnvProvider) Lookup(ctx context.Context, key string) (string, bool) {
	value, found := d.envMap[key]
	return value, found
}

func (d *DotEnvProvider) loadFromFile(filePath string) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return // .env file is optional
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := strings.TrimSpace(parts[0])
			value := strings.TrimSpace(parts[1])
			// Remove quotes if present
			if len(value) >= 2 && ((value[0] == '"' && value[len(value)-1] == '"') || (value[0] == '\'' && value[len(value)-1] == '\'')) {
				value = value[1 : len(value)-1]
			}
			d.envMap[key] = value
		}
	}
}

// MultiProvider combines multiple providers with priority order
// Earlier providers in the slice have higher priority
type MultiProvider struct {
	providers []ConfigProvider
}

func NewMultiProvider(providers ...ConfigProvider) *MultiProvider {
	return &MultiProvider{providers: providers}
}

func (m *MultiProvider) Name() string {
	names := make([]string, len(m.providers))
	for i, p := range m.providers {
		names[i] = p.Name()
	}
	return "multi(" + strings.Join(names, ",") + ")"
}

func (m *MultiProvider) Lookup(ctx context.Context, key string) (string, bool) {
	for _, provider := range m.providers {
		if value, found := provider.Lookup(ctx, key); found {
			return value, true
		}
	}
	return "", false
}

// providerLookuper adapts our ConfigProvider interface to envconfig.Lookuper
type providerLookuper struct {
	provider ConfigProvider
}

func (p *providerLookuper) Lookup(key string) (string, bool) {
	return p.provider.Lookup(context.Background(), key)
}

// ConfigLoader handles the configuration loading process
type ConfigLoader struct {
	providers []ConfigProvider
}

func NewConfigLoader() *ConfigLoader {
	return &ConfigLoader{}
}

func (cl *ConfigLoader) AddProvider(provider ConfigProvider) *ConfigLoader {
	cl.providers = append(cl.providers, provider)
	return cl
}

func (cl *ConfigLoader) Load(cfg interface{}) error {
	ctx := context.Background()

	// Create a multi-provider with priority order (first has highest priority)
	multiProvider := NewMultiProvider(cl.providers...)

	// Create the lookuper adapter
	lookuper := &providerLookuper{provider: multiProvider}

	// Process the configuration using the correct envconfig API
	if err := envconfig.ProcessWith(ctx, &envconfig.Config{
		Target:   cfg,
		Lookuper: lookuper,
	}); err != nil {
		return err
	}

	// Validate the configuration
	if err := utils.Validate.Struct(cfg); err != nil {
		return err
	}

	return nil
}

func GetConfig() *Config {
	if globalCfg.Version == 0 {
		err := Load()
		if err != nil {
			panic(err)
		}
	}
	return globalCfg
}

// Load loads configuration with environment-aware providers
func Load() error {
	cfg := globalCfg

	// Get environment (defaults to development if not set)
	environment := os.Getenv("ENVIRONMENT")
	if environment == "" {
		environment = "development"
	}

	loader := NewConfigLoader().
		AddProvider(&EnvProvider{}) // Highest priority: environment variables

	// In development, also load from .env file
	// In production, rely solely on environment variables (set by Kamal)
	if environment == "development" {
		loader.AddProvider(NewDotEnvProvider(".env"))
	}

	err := loader.Load(cfg)
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	cfg.Version = 1

	return nil
}

// LoadWithCustomProviders allows loading with custom provider configuration
func LoadWithCustomProviders(providers ...ConfigProvider) error {
	cfg := GetConfig()

	loader := NewConfigLoader()
	for _, provider := range providers {
		loader.AddProvider(provider)
	}

	return loader.Load(cfg)
}

// LoadEnvFromFile loads environment variables from a specified file path
// This is primarily for testing purposes
func LoadEnvFromFile(filePath string) error {
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return fmt.Errorf("env file not found: %s", filePath)
	}

	dotEnvProvider := NewDotEnvProvider(filePath)
	loader := NewConfigLoader().AddProvider(dotEnvProvider)

	return loader.Load(globalCfg)
}

// LoadTestEnv loads environment variables specifically for the test environment
func LoadTestEnv() error {
	testEnvPath := ".env.test"
	if _, err := os.Stat(testEnvPath); os.IsNotExist(err) {
		// Fallback to development .env if test env doesn't exist
		testEnvPath = ".env"
	}
	return LoadEnvFromFile(testEnvPath)
}
