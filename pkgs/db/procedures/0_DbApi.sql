-- core dbapi procedures and views
-- core.V_RL - view for run log summary
-- core.V_RLS - view for run log steps
-- core.P_RegisterDbApi - procedure to register a dbapi
-- core.P_UnregisterDbApi - procedure to unregister a dbapi
-- core.F_ValidateEmail - function to validate email format
-- core.F_ValidatePhone - function to validate phone number format
-- core.F_RunLogStart - function to start a run log
-- core.P_Step - procedure to log a step in the run log
-- core.F_RunLogEnd - function to end a run log
-- core.F_BuildMeterJson - function to build meter json from run log steps
-- core.P_DbApi - main dbapi procedure to route requests
-- core.P_SampleDbApi - sample dbapi procedure
-- core.F_GetConfig - function to get configuration value
-- core.P_SetConfig - procedure to set configuration value 
-- core.F_GetControl - function to get control value
-- core.P_SetControl - procedure to set control value

-- 1. create V_RL view for summary of runs
drop view if exists core.V_RL;
create or replace view core.V_RL
as
select runlogidn,logname,
	to_char(startts, 'YYYY-MM-DD HH24:MI:SS') as started,
    to_char(endts, 'YYYY-MM-DD HH24:MI:SS') as ended,
    inputjson,
    outputjson
from core.u_runlog;

-- 2. create V_RLS view for detailed steps
drop view if exists core.V_RLS;
create or replace view core.V_RLS
as
select rl.runlogidn,rl.logname,rls.idn,rls.step,rls.rc,
   	round(extract(epoch from (rls.ts - lag(rls.ts) over (partition by rl.runlogidn order by rls.idn))) * 1000) as ms,
   	round(100*extract(epoch from (rls.ts - lag(rls.ts) over (partition by rl.runlogidn order by rls.idn)))
		/nullif(extract(epoch from (rl.endts - rl.startts)), 0), 2) as pct
from core.u_runlog as rl
	join core.u_runlogstep as rls
		on rl.runlogidn = rls.runlogidn;

create or replace function core.F_ValidateEmail(p_email varchar)
returns boolean
language plpgsql
as $$
begin
    return p_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
end;
$$;

create or replace function core.F_ValidatePhone(p_phone varchar)
returns boolean
language plpgsql
as $$
begin
    -- adjust regex based on your phone format requirements
    return p_phone ~* '^\+?[0-9]{10,15}$';
end;
$$;

-- 3. create F_RunLogStart function to initiate logging
create or replace function core.F_RunLogStart(
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
        raise notice 'F_RunLogStart failed: %', sqlerrm;
        return null;
end;
$$;

-- 4. create p_step procedure
create or replace procedure core.P_Step(
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
        raise notice 'core.P_Step failed: %', sqlerrm;
end;
$$;

-- 5. create F_RunLogEnd function to mark completion
create or replace function core.F_RunLogEnd(
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
        raise notice 'F_RunLogEnd failed: %', sqlerrm;
end;
$$;

-- 6. create F_BuildMeterJson function to build meter json
create or replace function core.F_BuildMeterJson(
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

-- 7. create P_DbApi procedure
create or replace procedure core.P_DbApi(
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

    SELECT lower(SchemaName), lower(HandlerName)
    INTO v_SchemaName, v_HandlerName
    FROM core.U_DbApi
    WHERE lower(DbApiName) = lower(v_DbApiName);
    IF v_SchemaName IS NULL OR v_HandlerName IS NULL THEN
        RAISE EXCEPTION 'DbApiName % not registered', v_DbApiName;
    END IF;

    v_UserIdn := coalesce((p_InputJson->>'user_idn')::INT,0);

    -- Start logging and get RunLogIdn
    v_RunLogIdn := core.F_RunLogStart(v_HandlerName, v_UserIdn, p_InputJson);

    v_RequestJson = p_InputJson->'request';
    CALL core.P_Step(v_RunLogIdn, NULL, 'Extract request JSON');

	v_ProcedureCall = format('CALL %I.%I($1, $2, $3, $4, $5)', v_SchemaName, v_HandlerName);

	EXECUTE v_ProcedureCall 
    USING v_AnchorTs, v_UserIdn, v_RunLogIdn, v_RequestJson, v_ResultJson
    INTO v_ResultJson;

    CALL core.P_Step(v_RunLogIdn, NULL, 'Worker '||v_HandlerName||' executed successfully');

    SELECT jsonb_build_object(
			'status', 'success',
			'db_api_name', v_DbApiName,	
			'schema_name', v_SchemaName,	
			'handler_name', v_HandlerName,
			'user_idn', v_UserIdn,
			'start_ts', v_AnchorTs,
			'duration_ms', round(extract(epoch FROM (clock_timestamp() - v_AnchorTs)) * 1000),
			'response', v_ResultJson,
			'meter', core.F_BuildMeterJson(v_RunLogIdn)
		)
    INTO p_OutputJson;
    CALL core.P_Step(v_RunLogIdn, NULL, 'Built response JSON');

    -- Mark run as complete
    PERFORM core.F_RunLogEnd(v_RunLogIdn, p_OutputJson, TRUE);

EXCEPTION
    WHEN others THEN
        IF v_RunLogIdn IS NOT NULL THEN
	        CALL core.P_Step(v_RunLogIdn, NULL, 'ERROR: ' || SQLERRM);
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
					'meter', core.F_BuildMeterJson(v_RunLogIdn)
				)
		    INTO p_OutputJson;

            PERFORM core.F_RunLogEnd(v_RunLogIdn,p_OutputJson,FALSE);
		ELSE 
			RAISE;
        END IF;
END;
$BODY$;

-- 8. Create P_RegisterDbApi procedure
CREATE OR REPLACE PROCEDURE core.P_RegisterDbApi(
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
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'Register/Update DbApi');

    p_OutputJson := jsonb_build_object(
        'registered_count', v_Rc
    );
END;
$BODY$;

-- 9. Create P_UnregisterDbApi procedure
CREATE OR REPLACE PROCEDURE core.P_UnregisterDbApi(
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
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'Unregister DbApi');

    p_OutputJson := jsonb_build_object(
        'unregistered_count', v_Rc
    );
END;
$BODY$;

-- 10. Create P_SampleDbApi procedure
CREATE OR REPLACE PROCEDURE core.P_SampleDbApi(
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
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'Prepare Result JSON');
END;
$BODY$;

-- 11. Create F_GetConfig function to retrieve configuration
CREATE OR REPLACE FUNCTION core.F_GetConfig(
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

-- 12. Create P_SetConfig procedure to save configuration
CREATE OR REPLACE PROCEDURE core.P_SetConfig(
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

-- 13. Create P_GetControl function to retrieve control configuration
CREATE OR REPLACE FUNCTION core.F_GetControl(
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

-- 14. Create P_SetControl procedure to save control configuration
CREATE OR REPLACE PROCEDURE core.P_SetControl(
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

DELETE from core.U_DbApi WHERE DbApiName = 'RegisterDbApi';
DELETE from core.U_DbApi WHERE DbApiName = 'UnregisterDbApi';

INSERT INTO core.U_DbApi (DbApiName, SchemaName, HandlerName, PropertyList, UserIdn, Ts)
VALUES ('RegisterDbApi', 'core', 'P_RegisterDbApi', '{}', 1, now());

INSERT INTO core.U_DbApi (DbApiName, SchemaName, HandlerName, PropertyList, UserIdn, Ts)
VALUES ('UnregisterDbApi', 'core', 'P_UnregisterDbApi', '{}', 1, now());

CALL core.P_DbApi (
    '{
        "db_api_name": "registerDbApi",
        "request": {
            "records": [
                {
                    "db_api_name": "SampleDbApi",
                    "schema_name": "core",
                    "handler_name": "P_SampleDbApi",
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

/*
-- Example usage:

-- Clear run logs (for testing)
TRUNCATE TABLE core.U_RunLog RESTART IDENTITY CASCADE;
TRUNCATE TABLE core.U_RunLogStep RESTART IDENTITY CASCADE;

-- View recent runs
SELECT * FROM core.V_RL ORDER BY RunLogIdn DESC LIMIT 10;

-- View steps for a specific run
SELECT * FROM core.V_RLS 
WHERE RunLogIdn = (SELECT MAX(RunLogIdn) FROM core.U_RunLog) 
ORDER BY Idn;

-- Check configuration values
SELECT core.F_GetConfig('DonorUpdHwm');

-- Set configuration value
CALL core.P_SetConfig(
    'DonorUpdHwm',
    '{"idn": 0, "updated_ts": "2026-01-24T12:00:00Z"}'::jsonb,
    1
);

-- Check control values
SELECT core.P_GetControl('DonorUpdHwm');

-- Set control value
CALL core.P_SetControl(
    'DonorUpdHwm',
    '{"idn": 0, "updated_ts": "2026-01-24T12:00:00Z"}'::jsonb,
    1
);

CALL core.P_DbApi (
    '{
        "db_api_name": "UnregisterDbApi",	
        "request": {
            "records": [
                {
                    "db_api_name": "SampleDbApi"
                }
            ]
        }
    }'::jsonb,
    null
);

CALL core.P_DbApi (
	'{
		"db_api_name": "SampleDbApi",	
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
    CALL core.P_DbApi (
    '{
		"db_api_name": "SampleDbApi",	
		"request": {
			  "test_param": "Hello"
    	}
	}'::jsonb,
    v_output
    );

    RAISE NOTICE 'Output: %', v_output;
END 
$RUN$;

select * from core.V_RL ORDER BY RunLogIdn DESC LIMIT 1;
select * from core.V_RLS WHERE RunLogIdn=(select MAX(RunLogIdn) from core.U_RunLog) order by Idn;

delete from core.U_DbApi where schemaname='stp';
select * from core.U_DbApi where schemaname='stp';

DO $$
DECLARE
    v_OutputJson JSONB;
BEGIN
    CALL core.P_DbApi(
        '{
            "db_api_name": "RegisterDbApi",
            "user_idn": 1,
            "request": {
                "records": [
                    {"db_api_name": "GetProject", "schema_name": "stp", "handler_name": "P_GetProject", "property_list": {}},
                    {"db_api_name": "SearchProject", "schema_name": "stp", "handler_name": "P_SearchProject", "property_list": {}},
                    {"db_api_name": "SaveProject", "schema_name": "stp", "handler_name": "P_SaveProject", "property_list": {}},
                    {"db_api_name": "DeleteProject", "schema_name": "stp", "handler_name": "P_DeleteProject", "property_list": {}},
                    {"db_api_name": "GetDonor", "schema_name": "stp", "handler_name": "P_GetDonor", "property_list": {}},
                    {"db_api_name": "SaveDonor", "schema_name": "stp", "handler_name": "P_SaveDonor", "property_list": {}},
                    {"db_api_name": "DeleteDonor", "schema_name": "stp", "handler_name": "P_DeleteDonor", "property_list": {}},
                    {"db_api_name": "GetPledge", "schema_name": "stp", "handler_name": "P_GetPledge", "property_list": {}},
                    {"db_api_name": "SavePledge", "schema_name": "stp", "handler_name": "P_SavePledge", "property_list": {}},
                    {"db_api_name": "DeletePledge", "schema_name": "stp", "handler_name": "P_DeletePledge", "property_list": {}},
                    {"db_api_name": "CreateTreeBulk", "schema_name": "stp", "handler_name": "P_CreateTreeBulk", "property_list": {}},
                    {"db_api_name": "GetTree", "schema_name": "stp", "handler_name":"P_GetTree","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "SaveTree", "schema_name":"stp","handler_name":"P_SaveTree","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "DeleteTree","schema_name":"stp","handler_name":"P_DeleteTree","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "UploadTreePhoto","schema_name":"stp","handler_name":"P_UploadTreePhoto","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "GetDonorUpdate","schema_name":"stp","handler_name":"P_GetDonorUpdate","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "PostDonorUpdate","schema_name":"stp","handler_name":"P_PostDonorUpdate","property_list":{"description":"sample DbApi for testing"}},
                    {"db_api_name": "GetProvider", "schema_name": "stp", "handler_name": "P_GetProvider", "property_list": {}}
                ]
            }
        }'::JSONB,
        v_OutputJson
    );
    
    RAISE NOTICE 'STP procedures registration result: %', v_OutputJson;
END $$;
select * from core.U_DbApi;


*/
