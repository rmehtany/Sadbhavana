-- 7_provider.sql
-- GetProvider
-- SaveProvider
-- DeleteProvider

-- GetProvider - Retrieve providers by ProviderIdn or all providers
CREATE OR REPLACE PROCEDURE stp.P_GetProvider(
    IN      P_AnchorTs      TIMESTAMPTZ,
    IN      P_UserIdn       INT,
    IN      P_RunLogIdn     INT,
    IN      p_InputJson     JSONB,
    INOUT   p_OutputJson    JSONB
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_Rc INTEGER;
    v_ProviderIdn INT;
BEGIN
    v_ProviderIdn := NULLIF(p_InputJson->>'provider_idn', '')::INT;
    
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'provider_idn', ProviderIdn,
                'provider_name', ProviderName,
                'auth_type', AuthType,
                'auth_config', AuthConfig,
                'token_config', TokenConfig
            ) ORDER BY ProviderName
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Provider
    WHERE v_ProviderIdn IS NULL OR ProviderIdn = v_ProviderIdn;

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'SELECT Providers');
END;
$BODY$;

-- SaveProvider - Insert/Update providers with validation
CREATE OR REPLACE PROCEDURE stp.P_SaveProvider(
    IN      P_AnchorTs      TIMESTAMPTZ,
    IN      P_UserIdn       INT,
    IN      P_RunLogIdn     INT,
    IN      p_InputJson     JSONB,
    INOUT   p_OutputJson    JSONB
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_Rc INTEGER;
    v_DuplicateProviderNames TEXT;
BEGIN
    -- Create temp table for input providers
    CREATE TEMP TABLE T_Provider (
        ProviderIdn     INT,
        ProviderName    VARCHAR(64),
        AuthType        VARCHAR(64),
        AuthConfig      JSONB,
        TokenConfig     JSONB
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_Provider (ProviderIdn, ProviderName, AuthType, AuthConfig, TokenConfig)
    SELECT 
        NULLIF(T->>'provider_idn', '')::INT,
        T->>'provider_name',
        T->>'auth_type',
        COALESCE(T->'auth_config', '{}'::jsonb),
        COALESCE(T->'token_config', '{}'::jsonb)
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT T_Provider');

    -- Validate required fields
    IF EXISTS (SELECT 1 FROM T_Provider WHERE ProviderName IS NULL OR AuthType IS NULL) THEN
        RAISE EXCEPTION 'Missing required fields: provider_name and auth_type are mandatory';
    END IF;

    -- Check for duplicate ProviderName within input batch
    SELECT string_agg(DISTINCT ProviderName, ', ')
    INTO v_DuplicateProviderNames
    FROM 
        (SELECT ProviderName
        FROM T_Provider
        GROUP BY ProviderName
        HAVING COUNT(*) > 1
    ) dups;

    IF v_DuplicateProviderNames IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate ProviderName(s) in input batch: %. ProviderName must be unique.', v_DuplicateProviderNames;
    END IF;

    -- Check for duplicate ProviderName in existing records (excluding current record for updates)
    SELECT string_agg(DISTINCT tp.ProviderName, ', ')
    INTO v_DuplicateProviderNames
    FROM T_Provider tp
        JOIN stp.U_Provider up 
            ON tp.ProviderName = up.ProviderName
            AND (tp.ProviderIdn IS NULL OR tp.ProviderIdn != up.ProviderIdn);

    IF v_DuplicateProviderNames IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate ProviderName(s) already exist: %. ProviderName must be unique.', v_DuplicateProviderNames;
    END IF;

    -- Update existing providers
    UPDATE stp.U_Provider up
    SET ProviderName = tp.ProviderName,
        AuthType = tp.AuthType,
        AuthConfig = tp.AuthConfig,
        TokenConfig = tp.TokenConfig
    FROM T_Provider tp
    WHERE up.ProviderIdn = tp.ProviderIdn
      AND tp.ProviderIdn IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'UPDATE stp.U_Provider');

    -- Insert new providers
    INSERT INTO stp.U_Provider (ProviderName, AuthType, AuthConfig, TokenConfig)
    SELECT 
        tp.ProviderName,
        tp.AuthType,
        tp.AuthConfig,
        tp.TokenConfig
    FROM T_Provider tp
    WHERE tp.ProviderIdn IS NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT stp.U_Provider');

    -- Return saved providers
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'provider_idn', up.ProviderIdn,
                'provider_name', up.ProviderName,
                'auth_type', up.AuthType,
                'auth_config', up.AuthConfig,
                'token_config', up.TokenConfig
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Provider up
    WHERE up.ProviderName IN (SELECT ProviderName FROM T_Provider);
END;
$BODY$;

-- DeleteProvider - Delete providers with validation
CREATE OR REPLACE PROCEDURE stp.P_DeleteProvider(
    IN      P_AnchorTs      TIMESTAMPTZ,
    IN      P_UserIdn       INT,
    IN      P_RunLogIdn     INT,
    IN      p_InputJson     JSONB,
    INOUT   p_OutputJson    JSONB
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_Rc INTEGER;
    v_ProviderNames TEXT;
    v_DeletedProviderIdns TEXT;
BEGIN
    -- Create temp table for delete requests
    CREATE TEMP TABLE T_ProviderDelete (
        ProviderIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_ProviderDelete (ProviderIdn)
    SELECT (T->>'provider_idn')::INT
    FROM jsonb_array_elements(p_InputJson) AS T
    WHERE T->>'provider_idn' IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT T_ProviderDelete');

    IF v_Rc = 0 THEN
        RAISE EXCEPTION 'No valid provider_idn values provided for deletion';
    END IF;

    -- Check for providers with existing files
    SELECT string_agg(DISTINCT tpd.ProviderIdn::VARCHAR, ', ')
    INTO v_ProviderNames
    FROM T_ProviderDelete tpd
        JOIN stp.U_File uf
            ON tpd.ProviderIdn = uf.ProviderIdn;

    IF v_ProviderNames IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot delete provider(s) with existing files: %', v_ProviderNames;
    END IF;

    -- Capture ProviderIdns being deleted
    SELECT string_agg(ProviderIdn::TEXT, ', ')
    INTO v_DeletedProviderIdns
    FROM T_ProviderDelete;

    -- Delete providers
    DELETE FROM stp.U_Provider up
    USING T_ProviderDelete tpd
    WHERE up.ProviderIdn = tpd.ProviderIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'DELETE stp.U_Provider');

    -- Return result
    p_OutputJson := jsonb_build_object(
        'deleted_count', v_Rc,
        'deleted_provider_idns', COALESCE(v_DeletedProviderIdns, '')
    );
END;
$BODY$;

CALL core.P_DbApi (
    '{
        "db_api_name": "RegisterDbApi",	
        "request": {
            "records": [
                {
                    "db_api_name": "GetProvider",
                    "schema_name": "stp",
                    "handler_name": "P_GetProvider",
                    "property_list": {
                        "description": "Retrieves providers by ProviderIdn or all providers",
                        "version": "1.0",
                        "permissions": ["read"]
                    }
                },
                {
                    "db_api_name": "SaveProvider",
                    "schema_name": "stp",
                    "handler_name": "P_SaveProvider",
                    "property_list": {
                        "description": "Saves a new provider or updates an existing one",
                        "version": "1.0",
                        "permissions": ["write"]
                    }
                },
                {
                    "db_api_name": "DeleteProvider",
                    "schema_name": "stp",
                    "handler_name": "P_DeleteProvider",
                    "property_list": {
                        "description": "Deletes a provider by ProviderIdn",
                        "version": "1.0",
                        "permissions": ["write"]
                    }
                }
            ]
        }
    }'::jsonb,
    null
);
/*
-- End of 7_provider.sql
select * from stp.U_Provider;

-- Example 1: Get all providers
CALL core.P_DbApi (
    '{
        "db_api_name": "GetProvider",	
        "request": {}
    }'::jsonb,
    NULL
);

-- Example 2: Get specific provider by provider_idn
CALL core.P_DbApi (
    '{
        "db_api_name": "GetProvider",	
        "request": {
            "provider_idn": "1"
        }
    }'::jsonb,
    NULL
);

-- Example 3: Insert new provider with OAuth2
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveProvider",
        "request": [
            {
                "provider_name": "GoogleDrive",
                "auth_type": "OAuth2",
                "auth_config": {
                    "client_id": "your-client-id",
                    "client_secret": "your-client-secret",
                    "auth_url": "https://accounts.google.com/o/oauth2/auth",
                    "token_url": "https://oauth2.googleapis.com/token"
                },
                "token_config": {
                    "scope": "https://www.googleapis.com/auth/drive.file",
                    "redirect_uri": "http://localhost:8080/callback"
                }
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 4: Insert new provider with API Key
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveProvider",
        "request": [
            {
                "provider_name": "Dropbox",
                "auth_type": "APIKey",
                "auth_config": {
                    "api_key_header": "Authorization",
                    "api_key_prefix": "Bearer"
                },
                "token_config": {
                    "api_endpoint": "https://api.dropboxapi.com/2"
                }
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 5: Insert multiple providers
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveProvider",
        "request": [
            {
                "provider_name": "OneDrive",
                "auth_type": "OAuth2",
                "auth_config": {
                    "client_id": "onedrive-client-id",
                    "client_secret": "onedrive-secret"
                },
                "token_config": {
                    "scope": "files.readwrite"
                }
            },
            {
                "provider_name": "AmazonS3",
                "auth_type": "AWSSignature",
                "auth_config": {
                    "access_key_id": "aws-access-key",
                    "secret_access_key": "aws-secret-key",
                    "region": "us-east-1"
                },
                "token_config": {
                    "bucket_name": "tree-photos"
                }
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 6: Update existing provider
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveProvider",
        "request": [
            {
                "provider_idn": "1",
                "provider_name": "GoogleDrive",
                "auth_type": "OAuth2",
                "auth_config": {
                    "client_id": "updated-client-id",
                    "client_secret": "updated-client-secret",
                    "auth_url": "https://accounts.google.com/o/oauth2/auth",
                    "token_url": "https://oauth2.googleapis.com/token"
                },
                "token_config": {
                    "scope": "https://www.googleapis.com/auth/drive.file",
                    "redirect_uri": "http://localhost:8080/callback"
                }
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 7: Delete single provider
CALL core.P_DbApi(
    '{
        "db_api_name": "DeleteProvider",
        "request": [
            {
                "provider_idn": "2"
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 8: Delete multiple providers
CALL core.P_DbApi(
    '{
        "db_api_name": "DeleteProvider",
        "request": [
            {
                "provider_idn": "3"
            },
            {
                "provider_idn": "4"
            }
        ]
    }'::jsonb,
    NULL
);

select * from stp.U_Provider;
select * from core.V_RL ORDER BY RunLogIdn DESC;
select * from core.V_RLS WHERE RunLogIdn=(select MAX(RunLogIdn) from core.U_RunLog) order by Idn;
*/