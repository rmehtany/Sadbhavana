package cron

import (
	"context"
	"encoding/json"
	"log"
	"sadbhavana/tree-project/pkgs/conf"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/robfig/cron/v3"
)

// Scheduler manages the cron jobs.
type Scheduler struct {
	cron *cron.Cron
	cfg  conf.CronConfig
	db   *pgxpool.Pool
}

// NewScheduler creates a new cron scheduler.
func NewScheduler(cfg conf.CronConfig, db *pgxpool.Pool) *Scheduler {
	return &Scheduler{
		cron: cron.New(),
		cfg:  cfg,
		db:   db,
	}
}

// Start registers and starts the cron jobs.
func (s *Scheduler) Start() {
	if !s.cfg.Enabled {
		log.Println("⏸️ Cron scheduler is disabled")
		return
	}

	for jobName, schedule := range s.cfg.Jobs {
		jobFunc, ok := JobRegistry[jobName]
		if !ok {
			log.Printf("⚠️ Job '%s' not found in registry, skipping", jobName)
			continue
		}

		log.Printf("🚀 Registering cron job: %s with schedule: %s", jobName, schedule)

		// Capture variables for closure
		name := jobName
		fn := jobFunc

		_, err := s.cron.AddFunc(schedule, func() {
			s.runJob(name, fn)
		})
		if err != nil {
			log.Printf("❌ Failed to add job '%s' to cron: %v", name, err)
		}
	}

	s.cron.Start()
	log.Println("✅ Cron scheduler started successfully")
}

// runJob handles the execution of a job within a transaction and logs it to U_RunLog.
func (s *Scheduler) runJob(name string, fn JobFunc) {
	// Add a 30-minute timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
	defer cancel() // ensure resources are freed

	startTs := time.Now()
	useridn := 1

	log.Printf("🕒 Starting job: %s", name)

	// Create run log entry
	var runLogId int
	err := s.db.QueryRow(ctx,
		"INSERT INTO core.U_RunLog (LogName, useridn, StartTs, InputJson) VALUES ($1, $2, $3, $4) RETURNING RunLogIdn",
		name, useridn, startTs, json.RawMessage("{}")).Scan(&runLogId)

	if err != nil {
		log.Printf("❌ Failed to create run log for job '%s': %v", name, err)
		return
	}

	// Execute job within a transaction
	tx, err := s.db.Begin(ctx)
	if err != nil {
		log.Printf("❌ Failed to begin transaction for job '%s': %v", name, err)
		return
	}
	defer tx.Rollback(ctx)

	err = fn(ctx, tx, name)
	if err == nil {
		if commitErr := tx.Commit(ctx); commitErr != nil {
			err = commitErr
		}
	}

	endTs := time.Now()
	output := map[string]interface{}{
		"duration": endTs.Sub(startTs).String(),
	}
	if err != nil {
		output["error"] = err.Error()
		log.Printf("❌ Job '%s' failed: %v", name, err)
	} else {
		output["status"] = "success"
		log.Printf("✅ Job '%s' completed successfully", name)
	}

	outputJson, _ := json.Marshal(output)

	// Update run log entry
	_, logErr := s.db.Exec(ctx,
		"UPDATE core.U_RunLog SET EndTs = $1, OutputJson = $2 WHERE RunLogIdn = $3",
		endTs, outputJson, runLogId)

	if logErr != nil {
		log.Printf("❌ Failed to update run log for job '%s': %v", name, logErr)
	}
}

// Stop stops the cron scheduler.
func (s *Scheduler) Stop() {
	log.Println("🛑 Stopping cron scheduler...")
	ctx := s.cron.Stop()
	select {
	case <-ctx.Done():
		log.Println("✅ Cron scheduler stopped")
	case <-time.After(10 * time.Second):
		log.Println("⚠️ Cron scheduler stop timed out")
	}
}

// JobSchedule info for future inspects
type JobSchedule struct {
	Name    string    `json:"name"`
	NextRun time.Time `json:"next_run"`
	PrevRun time.Time `json:"prev_run"`
}

// GetFutureSchedules returns the next scheduled run times for all registered jobs.
func (s *Scheduler) GetFutureSchedules() []JobSchedule {
	entries := s.cron.Entries()
	schedules := make([]JobSchedule, 0, len(entries))

	// Since we map entries to jobs, we might need a way to correlate.
	// robfig/cron/v3 entries have IDs. We could store IDs if we need exact matching,
	// but for now we'll just return what's there.
	for _, entry := range entries {
		schedules = append(schedules, JobSchedule{
			NextRun: entry.Next,
			PrevRun: entry.Prev,
		})
	}
	return schedules
}

func (s *Scheduler) GetStatus() string {
	if s.cfg.Enabled {
		return "running"
	}
	return "disabled"
}
