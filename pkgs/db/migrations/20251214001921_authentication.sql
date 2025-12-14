-- +goose Up
-- +goose StatementBegin
SELECT 'up SQL query';
CREATE TABLE IF NOT EXISTS core.Authentication (
    provider_name VARCHAR(64) PRIMARY KEY,
    auth_config JSONB NOT NULL,
    active_token JSONB
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
SELECT 'down SQL query';
DROP TABLE IF EXISTS core.Authentication;
-- +goose StatementEnd
