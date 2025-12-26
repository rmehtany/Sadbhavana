/*
CREATE TABLE IF NOT EXISTS U_Data (
    Idn SERIAL PRIMARY KEY,
    Name VARCHAR(64),
    Value FLOAT
);

-- 1. Create tables
CREATE TABLE IF NOT EXISTS U_RunLog (
    RunLogIdn SERIAL PRIMARY KEY,
    LogName VARCHAR(128),
    StartTs TIMESTAMP,
    EndTs TIMESTAMP,
    InputJson JSONB NULL,
    OutputJson JSONB
);

CREATE TABLE IF NOT EXISTS U_RunLogStep (
    RunLogStepIdn SERIAL PRIMARY KEY,
    RunLogIdn INT,
    Ts TIMESTAMP DEFAULT now(),
    Rc INT,
    Step VARCHAR(256)
);
*/
-- 2. Enable dblink
--CREATE EXTENSION IF NOT EXISTS dblink;

-- Create F_RunLogStart with single statement using RETURNING
CREATE OR REPLACE FUNCTION F_RunLogStart(
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
    SELECT result::int INTO v_RunLogIdn FROM dblink(
        'dbname=' || current_database() || ' user=' || current_user,
        format(
            'INSERT INTO U_RunLog (LogName, StartTs, InputJson) VALUES (%L, now(), %L) RETURNING RunLogIdn',
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
CREATE OR REPLACE PROCEDURE P_RunLogStep(
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
        format('INSERT INTO U_RunLogStep (RunLogIdn, Ts, Rc, Step) VALUES (%s, now(), %L, %L)',p_RunLogIdn,p_Rc,p_Step)
    );
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'P_RunLogStep failed: %', SQLERRM;
END;
$$;

-- 6. Create F_RunLogEnd function to mark completion
CREATE OR REPLACE FUNCTION F_RunLogEnd(
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
            'UPDATE U_RunLog SET EndTs = now(), OutputJson = %L WHERE RunLogIdn = %s',
            p_OutputJson::text,
            p_RunLogIdn
        )
    );
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'F_RunLogEnd failed: %', SQLERRM;
END;
$$;

-- 7. Create demo_proc using the function
CREATE OR REPLACE PROCEDURE demo_proc(
    IN InputJson JSONB,
    INOUT OutputJson JSONB DEFAULT NULL
)
LANGUAGE plpgsql AS
$$
DECLARE
    v_Rc INT;
    v_RunLogIdn INT;
    v_row_count INT;
BEGIN
    -- Start logging and get RunLogIdn
    v_RunLogIdn := F_RunLogStart('demo_proc', InputJson);
    
	INSERT INTO U_Data (Name,Value) VALUES ('A',10);
	GET DIAGNOSTICS v_row_count = ROW_COUNT;
    CALL P_RunLogStep(v_RunLogIdn, v_row_count, 'Step1');
    
	RAISE EXCEPTION 'Your error message here';

	INSERT INTO U_Data (Name,Value) VALUES ('B',20);
	GET DIAGNOSTICS v_row_count = ROW_COUNT;
    CALL P_RunLogStep(v_RunLogIdn, v_row_count, 'Step2');
    
    -- Set output JSON
    OutputJson := jsonb_build_object('status', 'success');
    CALL P_RunLogStep(v_RunLogIdn, NULL, 'Step 3: Completed successfully');

    -- Mark run as complete
    PERFORM F_RunLogEnd(v_RunLogIdn, OutputJson, TRUE);
    
EXCEPTION
    WHEN others THEN
        -- Log the error (this will survive the rollback)
        
        -- Mark run as failed
        IF v_RunLogIdn IS NOT NULL THEN
	        CALL P_RunLogStep(v_RunLogIdn, NULL, 'ERROR: ' || SQLERRM);
            PERFORM F_RunLogEnd(v_RunLogIdn,jsonb_build_object('status','failure','error',SQLERRM),FALSE);
		ELSE 
			RAISE;
        END IF;
END;
$$;

truncate table U_RunLog RESTART IDENTITY;
truncate table U_RunLogStep RESTART IDENTITY;

-- 8. Test the procedure
CALL demo_proc('{"test": "input data", "mode": "demo"}'::jsonb, NULL);

-- 9. View the results
SELECT RunLogIdn,LogName,
	to_char(StartTs, 'YYYY-MM-DD HH24:MI:SS') as started,
    to_char(EndTs, 'YYYY-MM-DD HH24:MI:SS') as ended,
    InputJson,
    OutputJson
FROM U_RunLog 
ORDER BY RunLogIdn DESC 
LIMIT 5;

SELECT RunLogStepIdn,RunLogIdn,to_char(Ts, 'HH24:MI:SS.MS') as time,Rc,Step
FROM U_RunLogStep 
--WHERE RunLogIdn=(SELECT MAX(RunLogIdn) FROM U_RunLog)
ORDER BY RunLogStepIdn;
