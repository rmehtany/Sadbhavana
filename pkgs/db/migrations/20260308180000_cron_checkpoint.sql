-- +goose Up
-- +goose StatementBegin
CREATE TABLE core.cron_job_checkpoint (
    job_idn VARCHAR(128) PRIMARY KEY,
    last_checkpoint_idn BIGINT,
    last_checkpoint_ts TIMESTAMP DEFAULT now(),
    checkpoint_data JSONB,
    updated_at TIMESTAMP DEFAULT now()
);

COMMENT ON TABLE core.cron_job_checkpoint IS 'Stores progress checkpoints for long-running or retry-able cron jobs';
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS core.cron_job_checkpoint;
-- +goose StatementEnd
