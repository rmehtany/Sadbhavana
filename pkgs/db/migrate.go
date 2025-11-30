package db

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sadbhavana/tree-project/pkgs/conf"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
)

func GooseMigrateUp(cfg conf.PostgresConfig) error {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host,
		cfg.Port,
		cfg.User,
		cfg.Password,
		cfg.Database,
		cfg.SSLMode,
	)

	// Open database connection with pgx driver
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer db.Close()

	// Verify connection
	if err := db.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %w", err)
	}

	// Set dialect (postgres, mysql, sqlite3, etc.)
	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("failed to set goose dialect: %w", err)
	}

	// Run migrations
	migrationsDir := "pkgs/db/migrations"
	if err := goose.Up(db, migrationsDir); err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}
	log.Printf("✅ Database migrations applied successfully")

	// Execute stored procedures
	proceduresDir := "pkgs/db/procedures"
	if err := executeSQLFiles(db, proceduresDir); err != nil {
		return fmt.Errorf("failed to create stored procedures: %w", err)
	}
	log.Printf("✅ Stored procedures created/updated successfully")

	return nil
}

func executeSQLFiles(db *sql.DB, dir string) error {
	// Read all .sql files from the directory
	files, err := filepath.Glob(filepath.Join(dir, "*.sql"))
	if err != nil {
		return fmt.Errorf("failed to read SQL files: %w", err)
	}

	// Execute each SQL file
	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			return fmt.Errorf("failed to read file %s: %w", file, err)
		}

		if _, err := db.Exec(string(content)); err != nil {
			return fmt.Errorf("failed to execute %s: %w", file, err)
		}
		log.Printf("  Executed: %s", filepath.Base(file))
	}

	return nil
}
