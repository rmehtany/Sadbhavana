package main

import (
	"context"
	"fmt"
	"os"
	"sadbhavana/tree-project/pkgs/conf"

	"github.com/jackc/pgx/v5"
)

func main() {
	ctx := context.Background()
	conf.LoadEnvFromFile(".env.test")

	connStr := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=%s",
		os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_NAME"),
		os.Getenv("DB_SSLMODE"),
	)

	conn, err := pgx.Connect(ctx, connStr)
	if err != nil {
		fmt.Printf("Unable to connect to database: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close(ctx)

	sqlFile := "pkgs/db/procedures/3_pledge.sql"
	content, err := os.ReadFile(sqlFile)
	if err != nil {
		fmt.Printf("Unable to read SQL file: %v\n", err)
		os.Exit(1)
	}

	_, err = conn.Exec(ctx, string(content))
	if err != nil {
		fmt.Printf("Failed to execute SQL: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("SQL applied successfully!")
}
