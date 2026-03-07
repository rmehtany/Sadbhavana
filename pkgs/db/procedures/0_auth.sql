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
    --raise notice 'v_provider_name: %', v_provider_name;

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
/*
SELECT * FROM core.Authentication;
delete from core.Authentication;
insert into core.Authentication values ('google','{
  "auth_type" : "client_credentials",
  "client_credentials" : {
    "provider_type" : "google",
    "client_email" : "account1@sadbhavna-488112.iam.gserviceaccount.com",
    "private_key" : "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCxtJJIIeXM3L7p\n1NZf+USaFrunKNZ00FsYlh4q2ypPdVAuwEhWPYjRSSmcW1TbMDMtUOuvnOLgBzlo\n/Xf8wO51wR1hHDrYgocpjcx0yBA/YptokTHdUZ9UUIKVvjg8e4rWgXQIgVdgTWGB\nu0IR8GtqYs9cY0m39J0WdkMZJutrIpvmHPxn/G/xiyG7d1ThcF/zBgSqV+jv+Rrn\nLhJq3ZqR8mtD1ylAGLsfeKKs4vbEoHW1+KU873J7frO/HwFpXB75jSzM58+vNNOC\n50qZL2AyKxFBx8G1KdaFYyRewNkVrYv5Tc+T3TBhFbiKen+kgpCZ3RBylfg/uS2r\nURx79TcLAgMBAAECggEABthEtis6wGxUR4ofg8IvMUbk4tMWMkOq7pnW/vbtfJ1b\n1vZ9vXdQo3cPoj/RAexWXE18oTQIInGaICrQigIdwpgLUKfstarkF+an/xY3Af9Y\nqxYZ90NjQV/PLS4O2SLiaHwYrbyFqBDy9jNHSozvJkGOE9SYjKcLEfLA3OF8jzt3\n7F98EL0MsFiJN2hrxYR7pPNs+KuwwiYJGLUNbdWme2N9XmAYlEtkE95yY5cvKyQO\nlZdgoinpaeyipfG2jJEsSlYrVc7xH7sT5WU9PCiKcpoAbi/FspWqjvukv65Gr2Kc\nVPKOOYcJrqHQYLB/86IrTEOmj75FLxyz3Z27CUno4QKBgQDediF619lzZcK6JtGa\naKc/uX0G5VrwAzkWUYqjlDF/3d9lVX+CYLvBs8vb03bj+40cxHh9Knrv7OntCS81\n4LDQRo+DBP7iyNIzzWPRm4ikpQrnon7zU611MeJ8KQL13EcnK0BRygLHHxI4LwRo\nKtZl+m0gzHRkva4PmJaC1tWSmwKBgQDMfxXc4TAPKnijFPizJHxXAuZ307oy+629\nHVBUAmgxcyOcpPCe9N2hKj6DxxwVQQYxDl+Uh24p8E3ukyY0KeBTt9iLqd0RIzZp\ncF67I6uJ+s8QFLMzN3bJtzRr+Ljy6PMVCak+f5egW8ozvU2qEi9vgX3qO+9iWf8v\n0mgNL6i8UQKBgHapsKYkKRvC9iHxvvCMTlpRiP16rg1Eyti62ibzT4wTP6x/9KoJ\nC14BmAZEQDDP56+mpVauqDD+wLDtqz8kAWy3lqmeqo8x694x+sK+Ih8g4jY4mVsW\nEXpoB5WPEsMuos2j5oU6Kk0op8FMYx9lakOvVzKdnKB4BTbQf8h+7CFtAoGAVBIf\nK9qMRn/gbrNNd2CVmbQAidzKnPEpQSlO/+qpaUL7rgeFQORMRVi3sLdnzTkZUYum\nMcrnuGgpsd5fA2z/44sehHSGBOikEv72gxssB6LMA8Fu1qyDsnQWIhlz97FbVhfN\ns3sDHBMAcvrtdfDZ/Y6P9H9Fb/qt1bw7uMgSJ7ECgYAvtFUxGE9xe23ejp87fTea\n3P+4Im7mzcTH1JxGXi8IUKBZlUPn9XzEMy1FdXV+nrBE5g3CVx/RWtWpJUzeS6/w\nOLHl12YN38xXKoW99wGuVRBkzHcos8ewTaewJEj6pfbeLlwAMcfKuvhdsDD8rP7l\ncmI3bMg0I7dX48hdY/baGw==\n-----END PRIVATE KEY-----\n",
    "private_key_id" : "c51bd287934f20986c12c55124f45e738269cc6b",
    "scopes" : ["https://www.googleapis.com/auth/cloud-platform"]
  }
}',null)

CALL core.p_envelope(
    '{
        "schema_name": "core",
        "handler_name": "p_createauthforprovider",
        "request": {
            "provider_name": "google",
            "auth_config": {
                "auth_type": "client_credentials",
                "client_credentials": {
                    "provider_type": "google",
                    "client_email": "account1@sadbhavna-488112.iam.gserviceaccount.com",
                    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCxtJJIIeXM3L7p\n1NZf+USaFrunKNZ00FsYlh4q2ypPdVAuwEhWPYjRSSmcW1TbMDMtUOuvnOLgBzlo\n/Xf8wO51wR1hHDrYgocpjcx0yBA/YptokTHdUZ9UUIKVvjg8e4rWgXQIgVdgTWGB\nu0IR8GtqYs9cY0m39J0WdkMZJutrIpvmHPxn/G/xiyG7d1ThcF/zBgSqV+jv+Rrn\nLhJq3ZqR8mtD1ylAGLsfeKKs4vbEoHW1+KU873J7frO/HwFpXB75jSzM58+vNNOC\n50qZL2AyKxFBx8G1KdaFYyRewNkVrYv5Tc+T3TBhFbiKen+kgpCZ3RBylfg/uS2r\nURx79TcLAgMBAAECggEABthEtis6wGxUR4ofg8IvMUbk4tMWMkOq7pnW/vbtfJ1b\n1vZ9vXdQo3cPoj/RAexWXE18oTQIInGaICrQigIdwpgLUKfstarkF+an/xY3Af9Y\nqxYZ90NjQV/PLS4O2SLiaHwYrbyFqBDy9jNHSozvJkGOE9SYjKcLEfLA3OF8jzt3\n7F98EL0MsFiJN2hrxYR7pPNs+KuwwiYJGLUNbdWme2N9XmAYlEtkE95yY5cvKyQO\nlZdgoinpaeyipfG2jJEsSlYrVc7xH7sT5WU9PCiKcpoAbi/FspWqjvukv65Gr2Kc\nVPKOOYcJrqHQYLB/86IrTEOmj75FLxyz3Z27CUno4QKBgQDediF619lzZcK6JtGa\naKc/uX0G5VrwAzkWUYqjlDF/3d9lVX+CYLvBs8vb03bj+40cxHh9Knrv7OntCS81\n4LDQRo+DBP7iyNIzzWPRm4ikpQrnon7zU611MeJ8KQL13EcnK0BRygLHHxI4LwRo\nKtZl+m0gzHRkva4PmJaC1tWSmwKBgQDMfxXc4TAPKnijFPizJHxXAuZ307oy+629\nHVBUAmgxcyOcpPCe9N2hKj6DxxwVQQYxDl+Uh24p8E3ukyY0KeBTt9iLqd0RIzZp\ncF67I6uJ+s8QFLMzN3bJtzRr+Ljy6PMVCak+f5egW8ozvU2qEi9vgX3qO+9iWf8v\n0mgNL6i8UQKBgHapsKYkKRvC9iHxvvCMTlpRiP16rg1Eyti62ibzT4wTP6x/9KoJ\nC14BmAZEQDDP56+mpVauqDD+wLDtqz8kAWy3lqmeqo8x694x+sK+Ih8g4jY4mVsW\nEXpoB5WPEsMuos2j5oU6Kk0op8FMYx9lakOvVzKdnKB4BTbQf8h+7CFtAoGAVBIf\nK9qMRn/gbrNNd2CVmbQAidzKnPEpQSlO/+qpaUL7rgeFQORMRVi3sLdnzTkZUYum\nMcrnuGgpsd5fA2z/44sehHSGBOikEv72gxssB6LMA8Fu1qyDsnQWIhlz97FbVhfN\ns3sDHBMAcvrtdfDZ/Y6P9H9Fb/qt1bw7uMgSJ7ECgYAvtFUxGE9xe23ejp87fTea\n3P+4Im7mzcTH1JxGXi8IUKBZlUPn9XzEMy1FdXV+nrBE5g3CVx/RWtWpJUzeS6/w\nOLHl12YN38xXKoW99wGuVRBkzHcos8ewTaewJEj6pfbeLlwAMcfKuvhdsDD8rP7l\ncmI3bMg0I7dX48hdY/baGw==\n-----END PRIVATE KEY-----
",
                    "private_key_id": "c51bd287934f20986c12c55124f45e738269cc6b",
                    "scopes": [
                        "https://www.googleapis.com/auth/cloud-platform"
                    ]
                }
            }
        }
      }'::JSONB,
    NULL
);
CALL core.p_envelope(
    '{
        "schema_name": "core",
        "handler_name": "p_getauthforprovider",
        "request": {
            "provider_name": "google"
        }
    }'::JSONB,
    NULL
);
*/