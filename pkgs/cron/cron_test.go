package cron

import (
	"sadbhavana/tree-project/pkgs/conf"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewScheduler(t *testing.T) {
	cfg := conf.CronConfig{
		Enabled: true,
		Jobs: map[string]string{
			"SampleJob": "*/1 * * * *",
		},
	}

	scheduler := NewScheduler(cfg, nil) // nil pool for unit test
	assert.NotNil(t, scheduler)
	assert.Equal(t, cfg, scheduler.cfg)
}

func TestSchedulerStartRegistry(t *testing.T) {
	cfg := conf.CronConfig{
		Enabled: true,
		Jobs: map[string]string{
			"TreeDetectionJob": "*/1 * * * *",
			"UnknownJob":       "0 0 * * *", // This should be skipped
		},
	}

	scheduler := NewScheduler(cfg, nil)
	scheduler.Start()

	// Check entries count (only SampleJob should be added)
	assert.Equal(t, 1, len(scheduler.cron.Entries()))

	scheduler.Stop()
}
