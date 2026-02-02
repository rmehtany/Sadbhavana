-- +goose Up
-- +goose StatementBegin

CREATE OR REPLACE PROCEDURE core.P_CleanupSchema(
    IN p_SchemaName varchar(64)
)
LANGUAGE plpgsql AS
$$
DECLARE
    r record;   -- ← REQUIRED inside a PROCEDURE
BEGIN
    FOR r IN
        SELECT
            n.nspname AS schema_name,
            p.proname AS object_name,
            p.prokind AS kind,
            pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = p_SchemaName
          AND p.prokind IN ('f', 'p')
          AND p.proname != lower('P_CleanupSchema')
    LOOP
        IF r.kind = 'f' THEN
            EXECUTE format(
                'DROP FUNCTION IF EXISTS %I.%I(%s) CASCADE;',
                r.schema_name, r.object_name, r.args
            );
        ELSIF r.kind = 'p' THEN
            EXECUTE format(
                'DROP PROCEDURE IF EXISTS %I.%I(%s) CASCADE;',
                r.schema_name, r.object_name, r.args
            );
        END IF;
    END LOOP;
END;
$$;
call core.P_CleanupSchema('core');
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
SELECT 'down SQL query';
DROP PROCEDURE IF EXISTS core.P_CleanupSchema;
-- +goose StatementEnd
