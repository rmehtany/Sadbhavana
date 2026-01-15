create or replace view core.V_RL
AS
SELECT RunLogIdn,LogName,
	to_char(StartTs, 'YYYY-MM-DD HH24:MI:SS') as started,
    to_char(EndTs, 'YYYY-MM-DD HH24:MI:SS') as ended,
    InputJson,
    OutputJson
FROM core.U_RunLog;

create or replace view core.V_RLS
AS
SELECT RL.RunLogIdn,RL.LogName,RLS.Idn,to_char(RLS.Ts, 'HH24:MI:SS.MS') as time,RLS.Rc,RLS.Step
FROM core.U_RunLog as RL
	join core.U_RunLogStep as RLS
		on RL.RunLogIdn=RLS.RunLogIdn;

CREATE OR REPLACE FUNCTION core.F_RunLogStart(
    IN p_LogName VARCHAR(128), 
    IN p_InputJson JSONB
)
RETURNS INT
LANGUAGE plpgsql AS
$$
DECLARE
    v_RunLogIdn INT;
BEGIN
    -- Insert and get RunLogIdn in a single statement using RETURNING
    SELECT result::int 
	INTO v_RunLogIdn 
	FROM dblink(
        'dbname=' || current_database() || ' user=' || current_user,
        format(
            'INSERT INTO core.U_RunLog (LogName, StartTs, InputJson) VALUES (%L, now(), %L) RETURNING RunLogIdn',
            p_LogName, p_InputJson::text
        	)
    	) AS t(result text);

    RETURN v_RunLogIdn;
    
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'F_RunLogStart failed: %', SQLERRM;
        RETURN NULL;
END;
$$;

-- 5. Create P_RunLogStep procedure
CREATE OR REPLACE PROCEDURE core.P_RunLogStep(
    IN p_RunLogIdn INT,
    IN p_Rc INT, 
    IN p_Step VARCHAR(256)
)
LANGUAGE plpgsql AS
$$
BEGIN
    -- Autonomous logging using dblink
    PERFORM dblink_exec(
        'dbname=' || current_database() || ' user=' || current_user,
        format('INSERT INTO core.U_RunLogStep (RunLogIdn, Ts, Rc, Step) VALUES (%s, now(), %L, %L)',p_RunLogIdn,p_Rc,p_Step)
    );
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'P_RunLogStep failed: %', SQLERRM;
END;
$$;

-- 6. Create F_RunLogEnd function to mark completion
CREATE OR REPLACE FUNCTION core.F_RunLogEnd(
    IN p_RunLogIdn INT,
    IN p_OutputJson JSONB,
    IN p_IsSuccess BOOLEAN DEFAULT TRUE
)
RETURNS VOID
LANGUAGE plpgsql AS
$$
BEGIN
    -- Update the run log with end time and output (autonomous transaction)
    PERFORM dblink_exec(
        'dbname=' || current_database() || ' user=' || current_user,
        format(
            'UPDATE core.U_RunLog SET EndTs = now(), OutputJson = %L WHERE RunLogIdn = %s',
            p_OutputJson::text,
            p_RunLogIdn
        )
    );
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'F_RunLogEnd failed: %', SQLERRM;
END;
$$;

-- 6. Create F_RunLogEnd function to mark completion
CREATE OR REPLACE FUNCTION core.F_BuildMeterJson(
    IN p_RunLogIdn INT
)
RETURNS JSONB
LANGUAGE plpgsql AS
$$
DECLARE
    v_MeterJson JSONB;
BEGIN
    -- Update the run log with end time and output (autonomous transaction)
    SELECT jsonb_agg(
		jsonb_build_object(
			'step', step,
			'rc', rc,	
			'ms', ms
			) ORDER BY Idn ASC 
		)
	INTO v_MeterJson
	FROM
		(SELECT step,rc,ts,
        	round(extract(EPOCH FROM (ts - LAG(ts) OVER (ORDER BY Idn))) * 1000) AS ms,
        	Idn
		FROM core.U_RunLogStep
		WHERE RunLogIdn=p_RunLogIdn
		) AS T;

	RETURN v_MeterJson;
END;
$$;

CREATE OR REPLACE PROCEDURE core.P_DbApi(
    IN 		p_InputJson 	JSONB,
    INOUT 	p_OutputJson	JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_AnchorTs          TIMESTAMPTZ=clock_timestamp();
	v_HandlerName		VARCHAR(64);
	v_ProcedureCall		VARCHAR(256);
    v_Rc 				INTEGER;
	v_RequestJson 		JSONB;
    v_ResultJson 		JSONB;
    v_RunLogIdn 		INT;
	v_SchemaName		VARCHAR(64);
    v_UserIdn           INT;  
BEGIN
	v_SchemaName = p_InputJson->>'schema_name';
    v_HandlerName = p_InputJson->>'handler_name';
    v_UserIdn := coalesce((p_InputJson->>'user_idn')::INT,0);

    -- Start logging and get RunLogIdn
    v_RunLogIdn := core.F_RunLogStart(v_HandlerName, p_InputJson);

    v_RequestJson = p_InputJson->'request';
    CALL core.P_RunLogStep(v_RunLogIdn, NULL, 'Extract request JSON');

	v_ProcedureCall = format('CALL %I.%I($1,$2,$3,$4,NULL)',v_SchemaName,v_HandlerName);
    EXECUTE v_ProcedureCall INTO v_ResultJson USING v_AnchorTs,v_UserIdn,v_RunLogIdn,v_RequestJson;
    CALL core.P_RunLogStep(v_RunLogIdn, NULL, 'Worker '||v_HandlerName||' executed successfully');

    SELECT jsonb_build_object(
			'status', 'success',
			'schema_name', v_SchemaName,	
			'handler_name', v_HandlerName,
			'user_idn', v_UserIdn,
			'start_ts', v_AnchorTs,
			'duration_ms', round(extract(epoch FROM (clock_timestamp() - v_AnchorTs)) * 1000),
			'response', v_ResultJson,
			'meter', core.F_BuildMeterJson(v_RunLogIdn)
		)
    INTO p_OutputJson;
    CALL core.P_RunLogStep(v_RunLogIdn, NULL, 'Built response JSON');

    -- Mark run as complete
    PERFORM core.F_RunLogEnd(v_RunLogIdn, p_OutputJson, TRUE);

EXCEPTION
    WHEN others THEN
        IF v_RunLogIdn IS NOT NULL THEN
	        CALL core.P_RunLogStep(v_RunLogIdn, NULL, 'ERROR: ' || SQLERRM);
		    SELECT jsonb_build_object(
					'status', 'failure',
					'error_msg', SQLERRM,
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
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'Prepare Result JSON');
END;
$BODY$;

/*
-- Example usage:

truncate table core.U_RunLog RESTART IDENTITY;
truncate table core.U_RunLogStep RESTART IDENTITY;

CALL core.p_dbapi (
	'{
		"schema_name": "core",	
		"handler_name":"p_sampledbapi",
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
    CALL core.p_dbapi (
    '{
		"schema_name": "core",	
		"handler_name":"p_sampledbapi",
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
*/
