/*
-- 1. Create tables
DROP TABLE IF EXISTS core.U_RunLog;
CREATE TABLE core.U_RunLog (
    RunLogIdn SERIAL PRIMARY KEY,
    LogName VARCHAR(128),
    StartTs TIMESTAMP,
    EndTs TIMESTAMP,
    InputJson JSONB NULL,
    OutputJson JSONB
);

DROP TABLE IF EXISTS core.U_RunLogStep;
CREATE TABLE core.U_RunLogStep (
    Idn SERIAL PRIMARY KEY,
    RunLogIdn INT,
    Ts TIMESTAMP DEFAULT now(),
    Rc INT,
    Step VARCHAR(256)
);

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

CREATE OR REPLACE PROCEDURE core.P_DbApi(
    IN 		p_InputJson 	JSONB,
    INOUT 	p_OutputJson	JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_AnchorTs          TIMESTAMP=now();
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
    v_UserIdn := (p_InputJson->>'user_idn')::INT;

    -- Start logging and get RunLogIdn
    v_RunLogIdn := core.F_RunLogStart(v_HandlerName, p_InputJson);

    v_RequestJson = p_InputJson->'request';
    CALL core.P_RunLogStep(v_RunLogIdn, NULL, 'Extract request JSON');

	v_ProcedureCall = format('CALL %I.%I($1,$2,$3,$4,NULL)',v_SchemaName,v_HandlerName);
    EXECUTE v_ProcedureCall INTO v_ResultJson USING v_AnchorTs,v_UserIdn,v_RunLogIdn,v_RequestJson;
    CALL core.P_RunLogStep(v_RunLogIdn, NULL, 'Worker '||v_HandlerName||' executed successfully');

    SELECT jsonb_build_object('response',v_ResultJson,'meter','[{"ts":"12:03","action": "ran procedure"}]'::jsonb)
    INTO p_OutputJson;
    CALL core.P_RunLogStep(v_RunLogIdn, NULL, 'Built response JSON');

    -- Mark run as complete
    PERFORM core.F_RunLogEnd(v_RunLogIdn, p_OutputJson, TRUE);

EXCEPTION
    WHEN others THEN
        IF v_RunLogIdn IS NOT NULL THEN
	        CALL core.P_RunLogStep(v_RunLogIdn, NULL, 'ERROR: ' || SQLERRM);
            PERFORM core.F_RunLogEnd(v_RunLogIdn,jsonb_build_object('status','failure','error',SQLERRM),FALSE);
		ELSE 
			RAISE;
        END IF;
END;
$BODY$;
*/