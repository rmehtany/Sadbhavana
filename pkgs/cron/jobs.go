package cron

import (
	"context"
	"encoding/json"
	"log"
	"sadbhavana/tree-project/pkgs/service"
	"time"

	"github.com/jackc/pgx/v5"
)

// JobFunc defines the signature for cron job functions.
// It receives a database connection and the job name.
type JobFunc func(ctx context.Context, tx pgx.Tx, jobName string) error

// JobRegistry maps job names (from config) to their implementation functions.
var JobRegistry = map[string]JobFunc{
	"TreeDetectionJob": TreeDetectionJob,
	"PhotoSenderJob":   PhotoSenderJob,
}

// TreeDetectionJob is a job that detects trees and stores them in the database.
func TreeDetectionJob(ctx context.Context, tx pgx.Tx, jobName string) error {
	log.Printf("⏰ Cron Job: %s executed successfully", jobName)
	log.Printf("Start time %v", time.Now())
	err := service.PhotoDetectionAndStorage(ctx)
	if err != nil {
		return err
	}
	log.Printf("End time %v", time.Now())
	// Example: Increment a counter in checkpoint
	checkpoint, err := GetCheckpoint(ctx, tx, jobName)
	if err != nil {
		return err
	}

	var data map[string]interface{}
	if checkpoint.CheckpointData != nil {
		json.Unmarshal(checkpoint.CheckpointData, &data)
	} else {
		data = make(map[string]interface{})
	}

	count := 0.0
	if val, ok := data["run_count"]; ok {
		count = val.(float64)
	}
	data["run_count"] = count + 1

	return SaveCheckpoint(ctx, tx, jobName, 0, data)
}

// SampleJob is a demonstration job that logs a message and saves a checkpoint.
func PhotoSenderJob(ctx context.Context, tx pgx.Tx, jobName string) error {
	log.Printf("⏰ Cron Job: %s executed successfully", jobName)

	// Example: Increment a counter in checkpoint
	checkpoint, err := GetCheckpoint(ctx, tx, jobName)
	if err != nil {
		return err
	}

	var data map[string]interface{}
	if checkpoint.CheckpointData != nil {
		json.Unmarshal(checkpoint.CheckpointData, &data)
	} else {
		data = make(map[string]interface{})
	}

	count := 0.0
	if val, ok := data["run_count"]; ok {
		count = val.(float64)
	}
	data["run_count"] = count + 1

	return SaveCheckpoint(ctx, tx, jobName, 0, data)
}

// Helper functions for checkpointing (could be moved to a repository file later)

type Checkpoint struct {
	JobIdn            string
	LastCheckpointIdn int64
	CheckpointData    []byte
}

func GetCheckpoint(ctx context.Context, tx pgx.Tx, jobName string) (*Checkpoint, error) {
	var cp Checkpoint
	err := tx.QueryRow(ctx, "SELECT job_idn, last_checkpoint_idn, checkpoint_data FROM core.cron_job_checkpoint WHERE job_idn = $1", jobName).
		Scan(&cp.JobIdn, &cp.LastCheckpointIdn, &cp.CheckpointData)

	if err == pgx.ErrNoRows {
		// Initialize if not exists
		_, err = tx.Exec(ctx, "INSERT INTO core.cron_job_checkpoint (job_idn, last_checkpoint_idn) VALUES ($1, 0)", jobName)
		if err != nil {
			return nil, err
		}
		return &Checkpoint{JobIdn: jobName, LastCheckpointIdn: 0}, nil
	}

	if err != nil {
		return nil, err
	}
	return &cp, nil
}

func SaveCheckpoint(ctx context.Context, tx pgx.Tx, jobName string, lastId int64, data interface{}) error {
	jsonData, err := json.Marshal(data)
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx, `
		UPDATE core.cron_job_checkpoint 
		SET last_checkpoint_idn = $2, checkpoint_data = $3, updated_at = now() 
		WHERE job_idn = $1`,
		jobName, lastId, jsonData)

	return err
}
