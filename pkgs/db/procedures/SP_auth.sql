CREATE OR REPLACE PROCEDURE core.P_CreateAuthForProvider(
    IN p_input_json JSONB,
    OUT p_output_json JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_provider_name VARCHAR(64) := p_input_json->>'provider_name';
    v_auth_config JSONB := p_input_json->'auth_config';
    v_active_token JSONB := p_input_json->'active_token';
BEGIN
    -- Query the table for the provider
    INSERT INTO core.Authentication (provider_name, auth_config, active_token)
    VALUES (v_provider_name, v_auth_config, v_active_token)
    ON CONFLICT (provider_name) DO UPDATE
    SET auth_config = EXCLUDED.auth_config,
        active_token = EXCLUDED.active_token;

    p_output_json := '{}'::JSONB;
END;
$$;

CREATE OR REPLACE PROCEDURE core.P_GetAuthForProvider(
    IN p_input_json JSONB,
    OUT p_output_json JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_provider_name VARCHAR(64) := p_input_json->>'provider_name';
    v_auth_config JSONB;
    v_active_token JSONB;
BEGIN
    -- Query the table for the provider
    SELECT auth_config, active_token
    INTO v_auth_config, v_active_token
    FROM core.Authentication
    WHERE core.Authentication.provider_name = v_provider_name;
    
    -- Check if row was found
    IF v_auth_config IS NULL THEN
        p_output_json := '{}'::JSONB;
    ELSE
        -- Row found, assemble the output JSON
        p_output_json := jsonb_build_object(
            'auth_config', v_auth_config,
            'active_token', v_active_token
        );
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE core.P_UpdateTokenForProvider(
    IN p_input_json JSONB,
    OUT p_output_json JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_provider_name VARCHAR(64) := p_input_json->>'provider_name';
    v_new_token JSONB := p_input_json->'new_token';
BEGIN

    p_output_json := '{}'::JSONB;
    -- Query the table for the provider
    UPDATE core.Authentication
    SET active_token = v_new_token
    WHERE core.Authentication.provider_name = v_provider_name;
END;
$$;