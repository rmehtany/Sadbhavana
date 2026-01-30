-- +goose Up
-- +goose StatementBegin
SELECT 'up SQL query';
DROP VIEW IF EXISTS core.V_RL;
DROP VIEW IF EXISTS core.V_RLS;

DROP TABLE IF EXISTS core.U_RunLog;
CREATE TABLE core.U_RunLog (
    RunLogIdn       SERIAL PRIMARY KEY,
    LogName         VARCHAR(128) NOT NULL,
    UserIdn       	INT NOT NULL,
    StartTs         TIMESTAMP NOT NULL,
    EndTs           TIMESTAMP,
    InputJson       JSONB,
    OutputJson      JSONB
);

DROP TABLE IF EXISTS core.U_RunLogStep;
CREATE TABLE core.U_RunLogStep (
    Idn             SERIAL PRIMARY KEY,
    RunLogIdn       INT NOT NULL,
    Step            VARCHAR(256) NOT NULL,
    Ts              TIMESTAMP NOT NULL,
    Rc              INT,
    ErrMsg          VARCHAR(512),
    OtherInfo       JSONB
);

DROP TABLE IF EXISTS core.U_DbApi;
CREATE TABLE core.U_DbApi (
    DbApiName		VARCHAR(64) PRIMARY KEY,
	SchemaName		VARCHAR(64),
	HandlerName		VARCHAR(64),
    Propertylist    JSONB,
    UserIdn       	INT,
    Ts              TIMESTAMPTZ
);

DROP TABLE IF EXISTS core.U_Config;
CREATE TABLE core.U_Config (
    ConfigName		VARCHAR(64) PRIMARY KEY,
	ConfigValue		JSONB,
    UserIdn       	INT,
    Ts              TIMESTAMPTZ
);

DROP TABLE IF EXISTS core.U_Control;
CREATE TABLE core.U_Control (
    ControlName		VARCHAR(64) PRIMARY KEY,
	ControlValue	JSONB,
    UserIdn       	INT,
    Ts              TIMESTAMPTZ
);

DROP TABLE IF EXISTS core.U_User;
CREATE TABLE core.U_User (
    UserIdn         SERIAL PRIMARY KEY,
    UserName        VARCHAR(128) NOT NULL,
    MobileNumber    VARCHAR(64) NOT NULL,
    EmailAddr       VARCHAR(64),
    Ts              TIMESTAMPTZ NOT NULL
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
SELECT 'down SQL query';
DROP TABLE IF EXISTS core.U_RunLogStep;
DROP TABLE IF EXISTS core.U_RunLog;
DROP TABLE IF EXISTS core.U_DbApi;
DROP TABLE IF EXISTS core.U_Config;
DROP TABLE IF EXISTS core.U_Control;
DROP TABLE IF EXISTS core.U_User;
-- +goose StatementEnd
