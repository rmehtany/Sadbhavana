-- +goose Up
-- +goose StatementBegin
SELECT 'up SQL query';
CREATE TABLE core.U_RunLog (
    RunLogIdn SERIAL PRIMARY KEY,
    LogName VARCHAR(128),
    StartTs TIMESTAMP,
    EndTs TIMESTAMP,
    InputJson JSONB NULL,
    OutputJson JSONB
);

CREATE TABLE core.U_RunLogStep (
    Idn SERIAL PRIMARY KEY,
    RunLogIdn INT,
    Ts TIMESTAMP DEFAULT now(),
    Rc INT,
    Step VARCHAR(256)
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
SELECT 'down SQL query';
DROP TABLE IF EXISTS core.U_RunLogStep;
DROP TABLE IF EXISTS core.U_RunLog;
-- +goose StatementEnd
