-- 7_provider.sql
-- get_provider
-- save_provider
-- delete_provider

-- 7_provider.sql
CREATE OR REPLACE PROCEDURE stp.p_get_provider(
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
    CALL core.p_step(p_RunLogIdn, v_Rc, 'SELECT Providers');
END;
$BODY$;