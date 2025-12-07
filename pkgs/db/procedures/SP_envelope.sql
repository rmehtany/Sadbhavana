CREATE OR REPLACE PROCEDURE core.P_Envelope(
    IN p_input_json JSONB,
    INOUT p_output_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
	v_schema_name	VARCHAR(64);
	v_handler_name	VARCHAR(64);
	v_procedure_call VARCHAR(256);
	v_request 		JSONB;
    v_result 		JSONB;
    v_rows_affected INTEGER;
BEGIN
	v_schema_name = p_input_json->>'schema_name';
    v_handler_name = p_input_json->>'handler_name';
    v_request = p_input_json->'request';

	v_procedure_call = format('CALL %I.%I($1, NULL)', v_schema_name, v_handler_name);
    EXECUTE v_procedure_call INTO v_result USING v_request;

    SELECT jsonb_build_object('response', v_result, 'meter', '[{"ts":"12:03", "action": "ran procedure"}]'::jsonb)
    INTO p_output_json;

EXCEPTION
    WHEN OTHERS THEN
        -- Rollback on any error
        ROLLBACK;
        
        -- Re-raise the exception with details
        RAISE EXCEPTION 'Transaction failed: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END;
$BODY$;