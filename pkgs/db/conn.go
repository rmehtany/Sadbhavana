package db

import (
	"context"
	"fmt"
	"log"
	"sadbhavana/tree-project/pkgs/conf"

	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	dbtx     DBTX
	poolOnce sync.Once
	poolErr  error
	dbConf   *DatabaseConfig
)

// DatabaseConfig holds the database connection configuration
type DatabaseConfig struct {
	Host           string
	Port           string
	User           string
	Password       string
	Database       string
	SSLMode        string
	ChannelBinding string
}

// NewDatabaseConfig creates a new database configuration from environment variables
func NewDatabaseConfig() *DatabaseConfig {
	cfg := conf.GetConfig()
	return &DatabaseConfig{
		Host:           cfg.PostgresConfig.Host,
		Port:           cfg.PostgresConfig.Port,
		User:           cfg.PostgresConfig.User,
		Password:       cfg.PostgresConfig.Password,
		Database:       cfg.PostgresConfig.Database,
		SSLMode:        cfg.PostgresConfig.SSLMode,
		ChannelBinding: cfg.PostgresConfig.ChannelBinding,
	}
}

func SetDatabaseConfig(cfg *DatabaseConfig) {
	dbConf = cfg
}

// ConnectionString returns the PostgreSQL connection string
func (cfg *DatabaseConfig) ConnectionString() string {
	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.Database, cfg.SSLMode)
}

// getConn returns the singleton database pool instance
// This ensures the pool is only created once across the entire application
func getConn(ctx context.Context) (DBTX, error) {
	if dbConf == nil {
		dbConf = NewDatabaseConfig()
	}

	poolOnce.Do(func() {
		log.Println("Creating connection pool...")
		dbtx, poolErr = createConnectionPool(ctx, dbConf)
	})
	return dbtx, poolErr
}

// createConnectionPool creates a new pgx connection pool (internal function)
func createConnectionPool(ctx context.Context, config *DatabaseConfig) (DBTX, error) {
	poolConfig, err := pgxpool.ParseConfig(config.ConnectionString())
	if err != nil {
		return nil, fmt.Errorf("failed to parse database config: %w", err)
	}

	// Configure pool settings
	poolConfig.MaxConns = 30
	poolConfig.MinConns = 5
	poolConfig.MaxConnLifetime = time.Hour
	poolConfig.MaxConnIdleTime = time.Minute * 30
	poolConfig.HealthCheckPeriod = time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create connection pool: %w", err)
	}

	// Test the connection
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return pool, nil
}

// NewQueries creates a new Queries instance with the singleton connection pool
func NewQueries(ctx context.Context) (*Queries, error) {
	pool, err := getConn(ctx)
	if err != nil {
		return nil, err
	}
	return New(pool), nil
}

func NewQueriesWithTx(ctx context.Context) (*Queries, pgx.Tx, error) {
	conn, err := getConn(ctx)
	if err != nil {
		return nil, nil, err
	}

	var tx pgx.Tx
	switch c := conn.(type) {
	case *pgx.Conn:
		tx, err = c.Begin(ctx)
	case *pgxpool.Pool:
		tx, err = c.Begin(ctx)
	default:
		return nil, nil, fmt.Errorf("unsupported connection type: %T", conn)
	}

	if err != nil {
		return nil, nil, fmt.Errorf("failed to begin transaction: %w", err)
	}

	queries := New(conn)
	qtx := queries.WithTx(tx)

	return qtx, tx, nil
}
