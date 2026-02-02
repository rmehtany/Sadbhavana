-- +goose Up
-- +goose StatementBegin
CALL core.P_CleanupSchema('stp');
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
SELECT 'down SQL query';
-- +goose StatementEnd
