-- core dbapi procedures and views
-- core.v_rl - view for run log summary
-- core.v_rls - view for run log steps
-- core.p_register_db_api - procedure to register a dbapi
-- core.p_unregister_db_api - procedure to unregister a dbapi
-- core.f_validate_email - function to validate email format
-- core.f_validate_phone - function to validate phone number format
-- core.f_run_log_start - function to start a run log
-- core.p_step - procedure to log a step in the run log
-- core.f_run_log_end - function to end a run log
-- core.f_build_meter_json - function to build meter json from run log steps
-- core.p_db_api - main dbapi procedure to route requests
-- core.p_sample_db_api - sample dbapi procedure
-- core.f_get_config - function to get configuration value
-- core.p_set_config - procedure to set configuration value 
-- core.f_get_control - function to get control value
-- core.p_set_control - procedure to set control value

-- 1. create v_rl view for summary of runs
drop view if exists core.v_rl;
create or replace view core.v_rl
as
select runlogidn,logname,
	to_char(startts, 'YYYY-MM-DD HH24:MI:SS') as started,
    to_char(endts, 'YYYY-MM-DD HH24:MI:SS') as ended,
    inputjson,
    outputjson
from core.u_runlog;

-- 2. create v_rls view for detailed steps
drop view if exists core.v_rls;
create or replace view core.v_rls
as
select rl.runlogidn,rl.logname,rls.idn,rls.step,rls.rc,
   	round(extract(epoch from (rls.ts - lag(rls.ts) over (partition by rl.runlogidn order by rls.idn))) * 1000) as ms,
   	round(100*extract(epoch from (rls.ts - lag(rls.ts) over (partition by rl.runlogidn order by rls.idn)))
		/nullif(extract(epoch from (rl.endts - rl.startts)), 0), 2) as pct
from core.u_runlog as rl
	join core.u_runlogstep as rls
		on rl.runlogidn = rls.runlogidn;

create or replace function core.f_validate_email(p_email varchar)
returns boolean
language plpgsql
as $$
begin
    return p_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
end;
$$;

create or replace function core.f_validate_phone(p_phone varchar)
returns boolean
language plpgsql
as $$
begin
    -- adjust regex based on your phone format requirements
    return p_phone ~* '^\+?[0-9]{10,15}$';
end;
$$;

-- 3. create f_run_log_start function to initiate logging
create or replace function core.f_run_log_start(
    in p_logname varchar(128),
    in p_useridn int, 
    in p_inputjson jsonb
)
returns int
language plpgsql as
$$
declare
    v_runlogidn int;
begin
    -- insert and get runlogidn in a single statement using returning
    select result::int 
	into v_runlogidn 
	from dblink(
        'dbname=' || current_database() || ' user=' || current_user,
        format(
            'insert into core.u_runlog (logname, useridn, startts, inputjson) values (%L, %L, now(), %L) returning runlogidn',
            p_logname, p_useridn, p_inputjson::text
        	)
    	) as t(result text);

    return v_runlogidn;
    
exception
    when others then
        raise notice 'f_run_log_start failed: %', sqlerrm;
        return null;
end;
$$;

-- 4. create p_step procedure
create or replace procedure core.p_step(
    in p_runlogidn int,
    in p_rc int, 
    in p_step varchar(256)
)
language plpgsql as
$$
begin
    -- autonomous logging using dblink
    perform dblink_exec(
        'dbname=' || current_database() || ' user=' || current_user,
        format('insert into core.u_runlogstep (runlogidn, ts, rc, step) values (%s, now(), %L, %L)',p_runlogidn,p_rc,p_step)
    );
exception
    when others then
        raise notice 'p_step failed: %', sqlerrm;
end;
$$;

-- 5. create f_run_log_end function to mark completion
create or replace function core.f_run_log_end(
    in p_runlogidn int,
    in p_outputjson jsonb,
    in p_issuccess boolean default true
)
returns void
language plpgsql as
$$
begin
    -- update the run log with end time and output (autonomous transaction)
    perform dblink_exec(
        'dbname=' || current_database() || ' user=' || current_user,
        format(
            'update core.u_runlog set endts = now(), outputjson = %L where runlogidn = %s',
            p_outputjson::text,
            p_runlogidn
        )
    );
exception
    when others then
        raise notice 'f_run_log_end failed: %', sqlerrm;
end;
$$;

-- 6. create f_build_meter_json function to build meter json
create or replace function core.f_build_meter_json(
    in p_runlogidn int
)
returns jsonb
language plpgsql as
$$
declare
    v_meterjson jsonb;
begin
    -- build meter json from run log steps
    select jsonb_agg(
		jsonb_build_object(
			'step', step,
			'rc', rc,	
			'ms', ms
			) order by idn asc 
		)
	into v_meterjson
	from
		(select step,rc,ts,
        	round(extract(epoch from (ts - lag(ts) over (order by idn))) * 1000) as ms,
        	idn
		from core.u_runlogstep
		where runlogidn=p_runlogidn
		) as t;

	return v_meterjson;
end;
$$;

-- 7. create p_db_api procedure
create or replace procedure core.p_db_api(
    in 		p_inputjson 	jsonb,
    inout 	p_outputjson	jsonb default null
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_AnchorTs          TIMESTAMPTZ=clock_timestamp();
	v_DbApiName			VARCHAR(64);
	v_HandlerName		VARCHAR(64);
	v_ProcedureCall		VARCHAR(256);
    v_Rc 				INTEGER;
	v_RequestJson 		JSONB;
    v_ResultJson 		JSONB;
    v_RunLogIdn 		INT;
	v_SchemaName		VARCHAR(64);
    v_UserIdn           INT;  
BEGIN
	v_DbApiName = p_InputJson->>'db_api_name';
    IF v_DbApiName IS NULL THEN
        RAISE EXCEPTION 'Missing parameter db_api_name';
    END IF;

    SELECT SchemaName, HandlerName
    INTO v_SchemaName, v_HandlerName
    FROM core.U_DbApi
    WHERE DbApiName = v_DbApiName;
    IF v_SchemaName IS NULL OR v_HandlerName IS NULL THEN
        RAISE EXCEPTION 'DbApiName % not registered', v_DbApiName;
    END IF;

    v_UserIdn := coalesce((p_InputJson->>'user_idn')::INT,0);

    -- Start logging and get RunLogIdn
    v_RunLogIdn := core.F_run_log_start(v_HandlerName, v_UserIdn, p_InputJson);

    v_RequestJson = p_InputJson->'request';
    CALL core.p_step(v_RunLogIdn, NULL, 'Extract request JSON');

	v_ProcedureCall = format('CALL %I.%I($1,$2,$3,$4,$5)',v_SchemaName,v_HandlerName);
    EXECUTE v_ProcedureCall USING v_AnchorTs,v_UserIdn,v_RunLogIdn,v_RequestJson,v_ResultJson;
    CALL core.p_step(v_RunLogIdn, NULL, 'Worker '||v_HandlerName||' executed successfully');

    SELECT jsonb_build_object(
			'status', 'success',
			'db_api_name', v_DbApiName,	
			'schema_name', v_SchemaName,	
			'handler_name', v_HandlerName,
			'user_idn', v_UserIdn,
			'start_ts', v_AnchorTs,
			'duration_ms', round(extract(epoch FROM (clock_timestamp() - v_AnchorTs)) * 1000),
			'response', v_ResultJson,
			'meter', core.f_build_meter_json(v_RunLogIdn)
		)
    INTO p_OutputJson;
    CALL core.p_step(v_RunLogIdn, NULL, 'Built response JSON');

    -- Mark run as complete
    PERFORM core.f_run_log_end(v_RunLogIdn, p_OutputJson, TRUE);

EXCEPTION
    WHEN others THEN
        IF v_RunLogIdn IS NOT NULL THEN
	        CALL core.p_step(v_RunLogIdn, NULL, 'ERROR: ' || SQLERRM);
		    SELECT jsonb_build_object(
					'status', 'failure',
					'error_msg', SQLERRM,
			        'db_api_name', v_DbApiName,	
					'schema_name', v_SchemaName,	
					'handler_name', v_HandlerName,
					'user_idn', v_UserIdn,
					'start_ts', v_AnchorTs,
					'duration_ms', round(extract(epoch FROM (clock_timestamp() - v_AnchorTs)) * 1000),
					'response', null,
					'meter', core.f_build_meter_json(v_RunLogIdn)
				)
		    INTO p_OutputJson;

            PERFORM core.f_run_log_end(v_RunLogIdn,p_OutputJson,FALSE);
		ELSE 
			RAISE;
        END IF;
END;
$BODY$;

-- 8. Create p_register_db_api procedure
CREATE OR REPLACE PROCEDURE core.p_register_db_api(
    IN      p_AnchorTs      TIMESTAMPTZ,
    IN      p_UserIdn       INT,
    IN      p_RunLogIdn     INT,
    IN      p_InputJson     JSONB,
    INOUT   p_OutputJson    JSONB
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_Rc INTEGER;
BEGIN
    INSERT INTO core.U_DbApi (DbApiName, SchemaName, HandlerName, PropertyList, UserIdn, Ts)
    SELECT 
        elem->>'db_api_name',
        elem->>'schema_name',
        elem->>'handler_name',
        elem->'property_list',
        p_UserIdn,
        p_AnchorTs
    FROM jsonb_array_elements(p_InputJson->'records') AS elem
    ON CONFLICT (DbApiName) 
    DO UPDATE SET
        SchemaName = EXCLUDED.SchemaName,
        HandlerName = EXCLUDED.HandlerName,
        PropertyList = EXCLUDED.PropertyList,
        UserIdn = EXCLUDED.UserIdn,
        Ts = EXCLUDED.Ts;

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'Register/Update DbApi');

    p_OutputJson := jsonb_build_object(
        'registered_count', v_Rc
    );
END;
$BODY$;

-- 9. Create P_unregister_db_api procedure
CREATE OR REPLACE PROCEDURE core.p_unregister_db_api(
    IN      p_AnchorTs      TIMESTAMPTZ,
    IN      p_UserIdn       INT,
    IN      p_RunLogIdn     INT,
    IN      p_InputJson     JSONB,
    INOUT   p_OutputJson    JSONB
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_Rc INTEGER;
BEGIN
    DELETE FROM core.U_DbApi
    WHERE DbApiName IN (
        SELECT elem->>'db_api_name'
        FROM jsonb_array_elements(p_InputJson->'records') AS elem
    );

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'Unregister DbApi');

    p_OutputJson := jsonb_build_object(
        'unregistered_count', v_Rc
    );
END;
$BODY$;

-- 10. Create p_sample_db_api procedure
CREATE OR REPLACE PROCEDURE core.p_sample_db_api(
    IN      p_AnchorTs      TIMESTAMPTZ,
    IN      p_UserIdn       INT,
    IN      p_RunLogIdn     INT,
    IN      p_InputJson     JSONB,
    INOUT   p_OutputJson    JSONB
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_Rc INTEGER;
    v_TestParam VARCHAR(128);
BEGIN
    -- Extract and prepare search pattern
    v_TestParam := '%' || COALESCE(p_InputJson->>'test_param', '') || '%';
    RAISE NOTICE 'TestParam: %', v_TestParam;

    -- Build result JSON
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', Id,
                'name', Name
            ) ORDER BY Id
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM (VALUES (1, 'one'),(2, 'two'),(3, 'three')) AS t (Id, Name);

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'Prepare Result JSON');
END;
$BODY$;

-- 11. Create f_get_config function to retrieve configuration
CREATE OR REPLACE FUNCTION core.f_get_config(
    IN p_ConfigName     VARCHAR(64)
)
RETURNS JSONB
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_ConfigValue JSONB;
BEGIN
    -- Get configuration value
    SELECT ConfigValue
    INTO v_ConfigValue
    FROM core.U_Config  
    WHERE ConfigName = p_ConfigName;

    RETURN v_ConfigValue;
END;
$BODY$;

-- 12. Create p_set_config procedure to save configuration
CREATE OR REPLACE PROCEDURE core.p_set_config(
    IN p_ConfigName     VARCHAR(64),
    IN p_ConfigValue    JSONB,
    IN p_UserIdn        INT
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_Rc INTEGER;
BEGIN
    -- Update or insert configuration value
    UPDATE core.U_Config
    SET ConfigValue = p_ConfigValue,
        UserIdn = p_UserIdn,
        Ts = now() 
    WHERE ConfigName = p_ConfigName;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    IF v_Rc = 0 THEN
        INSERT INTO core.U_Config (ConfigName, ConfigValue, UserIdn, Ts)
        VALUES (p_ConfigName, p_ConfigValue, p_UserIdn, now());
    END IF;
END;
$BODY$;

-- 13. Create f_get_control function to retrieve control configuration
CREATE OR REPLACE FUNCTION core.f_get_control(
    IN p_ControlName     VARCHAR(64)
)
RETURNS JSONB
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_ControlValue JSONB;
BEGIN
    -- Get control value
    SELECT ControlValue
    INTO v_ControlValue
    FROM core.U_Control  
    WHERE ControlName = p_ControlName;

    RETURN v_ControlValue;
END;
$BODY$;

-- 14. Create p_set_control procedure to save control configuration
CREATE OR REPLACE PROCEDURE core.p_set_control(
    IN p_ControlName     VARCHAR(64),
    IN p_ControlValue    JSONB,
    IN p_UserIdn        INT
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_Rc INTEGER;
BEGIN
    -- Update or insert control value
    UPDATE core.U_Control
    SET ControlValue = p_ControlValue,
        UserIdn = p_UserIdn,
        Ts = now() 
    WHERE ControlName = p_ControlName;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    IF v_Rc = 0 THEN
        INSERT INTO core.U_Control (ControlName, ControlValue, UserIdn, Ts)
        VALUES (p_ControlName, p_ControlValue, p_UserIdn, now());
    END IF;
END;
$BODY$;

/*
-- Example usage:

-- Clear run logs (for testing)
TRUNCATE TABLE core.U_RunLog RESTART IDENTITY CASCADE;
TRUNCATE TABLE core.U_RunLogStep RESTART IDENTITY CASCADE;

-- View recent runs
SELECT * FROM core.v_rl ORDER BY RunLogIdn DESC LIMIT 10;

-- View steps for a specific run
SELECT * FROM core.v_rls 
WHERE RunLogIdn = (SELECT MAX(RunLogIdn) FROM core.U_RunLog) 
ORDER BY Idn;

-- Check configuration values
SELECT core.f_get_config('donor_update_high_water_mark');

-- Set configuration value
CALL core.p_set_config(
    'donor_update_high_water_mark',
    '{"idn": 0, "updated_ts": "2026-01-24T12:00:00Z"}'::jsonb,
    1
);

-- Check control values
SELECT core.f_get_control('donor_update_high_water_mark');

-- Set control value
CALL core.p_set_control(
    'donor_update_high_water_mark',
    '{"idn": 0, "updated_ts": "2026-01-24T12:00:00Z"}'::jsonb,
    1
);

TRUNCATE TABLE core.U_DbApi;
DELETE from core.U_DbApi WHERE DbApiName = 'register_db_api';
DELETE from core.U_DbApi WHERE DbApiName = 'unregister_db_api';

INSERT INTO core.U_DbApi (DbApiName, SchemaName, HandlerName, PropertyList, UserIdn, Ts)
VALUES ('register_db_api', 'core', 'p_register_db_api', '{}', 1, now());

INSERT INTO core.U_DbApi (DbApiName, SchemaName, HandlerName, PropertyList, UserIdn, Ts)
VALUES ('unregister_db_api', 'core', 'p_unregister_db_api', '{}', 1, now());

CALL core.p_db_api (
    '{
        "db_api_name": "unregister_db_api",	
        "request": {
            "records": [
                {
                    "db_api_name": "sample_db_api"
                }
            ]
        }
    }'::jsonb,
    null
);

CALL core.p_db_api (
    '{
        "db_api_name": "register_db_api",
        "request": {
            "records": [
                {
                    "db_api_name": "sample_db_api",
                    "schema_name": "core",
                    "handler_name": "p_sample_db_api",
                    "property_list": {
                        "description": "sample DbApi for testing",
                        "version": "1.0",
                        "permissions": ["read"]
                    }
                }
            ]
        }
    }'::jsonb,
    null
);

CALL core.p_db_api (
	'{
		"db_api_name": "sample_db_api",	
		"request": {
			  "test_param": "Hello"
		}
	}'::jsonb,
	null
	);

DO $RUN$
DECLARE
    v_output JSONB;
BEGIN
    CALL core.p_db_api (
    '{
		"db_api_name": "sample_db_api",	
		"request": {
			  "test_param": "Hello"
    	}
	}'::jsonb,
    v_output
    );

    RAISE NOTICE 'Output: %', v_output;
END 
$RUN$;

select * from core.v_rl ORDER BY RunLogIdn DESC LIMIT 1;
select * from core.v_rls WHERE RunLogIdn=(select MAX(RunLogIdn) from core.U_RunLog) order by Idn;

delete from core.U_DbApi where schemaname='stp';
select * from core.U_DbApi where schemaname='stp';

DO $$
DECLARE
    v_OutputJson JSONB;
BEGIN
    CALL core.p_db_api(
        '{
            "db_api_name": "register_db_api",
            "user_idn": 1,
            "request": {
                "records": [
                    {"db_api_name": "get_project", "schema_name": "stp", "handler_name": "p_get_project", "property_list": {}},
                    {"db_api_name": "search_project", "schema_name": "stp", "handler_name": "p_search_project", "property_list": {}},
                    {"db_api_name": "save_project", "schema_name": "stp", "handler_name": "p_save_project", "property_list": {}},
                    {"db_api_name": "delete_project", "schema_name": "stp", "handler_name": "p_delete_project", "property_list": {}},
                    {"db_api_name": "get_donor", "schema_name": "stp", "handler_name": "p_get_donor", "property_list": {}},
                    {"db_api_name": "save_donor", "schema_name": "stp", "handler_name": "p_save_donor", "property_list": {}},
                    {"db_api_name": "delete_donor", "schema_name": "stp", "handler_name": "p_delete_donor", "property_list": {}},
                    {"db_api_name": "get_pledge", "schema_name": "stp", "handler_name": "p_get_pledge", "property_list": {}},
                    {"db_api_name": "save_pledge", "schema_name": "stp", "handler_name": "p_save_pledge", "property_list": {}},
                    {"db_api_name": "delete_pledge", "schema_name": "stp", "handler_name": "p_delete_pledge", "property_list": {}},
                    {"db_api_name": "create_tree_bulk", "schema_name": "stp", "handler_name": "p_create_tree_bulk", "property_list": {}},
                    {"db_api_name": "get_tree", "schema_name": "stp", 	"handler_name":"p_get_tree","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "save_tree", 	"schema_name":"stp","handler_name":"p_save_tree","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "delete_tree","schema_name":"stp","handler_name":"p_delete_tree","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "upload_tree_photo","schema_name":"stp","handler_name":"p_upload_tree_photo","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "get_donor_update","schema_name":"stp","handler_name":"p_get_donor_update","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "post_donor_update","schema_name":"stp","handler_name":"p_post_donor_update","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "get_provider", "schema_name": "stp", "handler_name": "p_get_provider", "property_list": {}}
                ]
            }
        }'::JSONB,
        v_OutputJson
    );
    
    RAISE NOTICE 'STP procedures registration result: %', v_OutputJson;
END $$;
select * from core.U_DbApi;


*/
