package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"sadbhavana/tree-project/pkgs/conf"
	"sadbhavana/tree-project/pkgs/db"
	"sadbhavana/tree-project/web"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humachi"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func main() {
	err := conf.Load()
	if err != nil {
		panic(err)
	}

	cfg := conf.GetConfig()

	err = db.GooseMigrateUp(cfg.PostgresConfig)
	if err != nil {
		log.Fatalf("Failed to run database migrations: %v", err)
	}
	// Create router
	router := chi.NewRouter()

	// Add middleware
	router.Use(middleware.Logger)
	router.Use(middleware.Recoverer)
	router.Use(middleware.Compress(5))

	// Serve static files
	fs := http.FileServer(http.Dir("./static"))
	router.Handle("/static/*", http.StripPrefix("/static/", fs))

	// Serve index.html at root
	router.Get("/map", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/index.html")
	})

	// Create Huma API
	api := humachi.New(router, huma.DefaultConfig("Tree Map API", "1.0.0"))

	// Register API handlers
	if err := web.RegisterMapHandlers(api); err != nil {
		log.Fatalf("Failed to register API handlers: %v", err)
	}

	if err := web.RegisterWhatsappHandlers(router); err != nil {
		log.Fatalf("Failed to register WhatsApp handlers: %v", err)
	}

	log.Println("✅ API handlers registered successfully")

	// Server configuration
	port := cfg.BaseConfig.Port
	if port == 0 {
		port = 8080
	}

	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", port),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Printf("🌳 Tree Map Server starting on http://localhost:%d", port)
		log.Printf("📍 Open http://localhost:%d in your browser", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server stopped")
}
