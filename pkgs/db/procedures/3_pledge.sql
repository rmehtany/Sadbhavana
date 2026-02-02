-- 3_pledge.sql
    -- search_pledge
    -- SavePledge
    -- delete_pledge

-- GetPledge - Search pledges by DonorIdn or ProjectIdn
CREATE OR REPLACE PROCEDURE stp.P_GetPledge(
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
    v_DonorIdn INT;
    v_ProjectIdn INT;
BEGIN
    -- Extract search criteria
    v_ProjectIdn := NULLIF(p_InputJson->>'project_idn', '')::INT;
    v_DonorIdn := NULLIF(p_InputJson->>'donor_idn', '')::INT;
    
    -- Build result JSON
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'pledge_idn', p.PledgeIdn,
                'project_idn', p.ProjectIdn,
                'project_id', pr.ProjectId,
                'project_name', pr.ProjectName,
                'donor_idn', p.DonorIdn,
                'donor_name', d.DonorName,
                'pledge_ts', p.PledgeTs,
                'tree_cnt_pledged', p.TreeCntPledged,
                'tree_cnt_planted', p.TreeCntPlanted,
                'pledge_credit', p.PledgeCredit,
                'property_list', p.PropertyList
            ) ORDER BY p.PledgeIdn
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Pledge p
        JOIN stp.U_Project pr 
            ON p.ProjectIdn = pr.ProjectIdn
        JOIN stp.U_Donor d 
            ON p.DonorIdn = d.DonorIdn
    WHERE (v_DonorIdn IS NULL OR p.DonorIdn = v_DonorIdn)
    AND (v_ProjectIdn IS NULL OR p.ProjectIdn = v_ProjectIdn);

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'prepare GetPledge json');
END;
$BODY$;

-- SavePledge - Insert/Update pledges with validation
CREATE OR REPLACE PROCEDURE stp.P_SavePledge(
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
    v_InvalidProjects TEXT;
    v_InvalidDonors TEXT;
BEGIN
    -- Create temp table for input pledges
    CREATE TEMP TABLE T_Pledge (
        PledgeIdn       INT,
        ProjectIdn      INT,
        DonorIdn        INT,
        PledgeTs        TIMESTAMP,
        TreeCntPledged  INT,
        TreeCntPlanted  INT,
        PledgeCredit    JSONB,
        PropertyList    JSONB
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_Pledge (PledgeIdn, ProjectIdn, DonorIdn, PledgeTs, TreeCntPledged, TreeCntPlanted, PledgeCredit, PropertyList)
    SELECT
        NULLIF(T->>'pledge_idn', '')::INT,
        (T->>'project_idn')::INT,
        (T->>'donor_idn')::INT,
        COALESCE(NULLIF(T->>'pledge_ts', '')::TIMESTAMP, P_AnchorTs),
        COALESCE((T->>'tree_cnt_pledged')::INT, 0),
        COALESCE((T->>'tree_cnt_planted')::INT, 0),
        COALESCE(T->'pledge_credit', '{}'::jsonb),
        COALESCE(T->'property_list', '{}'::jsonb)
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT T_Pledge');

    -- Validate required fields
    IF EXISTS (SELECT 1 FROM T_Pledge WHERE ProjectIdn IS NULL OR DonorIdn IS NULL) THEN
        RAISE EXCEPTION 'Missing required fields: project_idn and donor_idn are mandatory';
    END IF;

    -- Validate TreeCntPlanted <= TreeCntPledged
    IF EXISTS (SELECT 1 FROM T_Pledge WHERE TreeCntPlanted > TreeCntPledged) THEN
        RAISE EXCEPTION 'tree_cnt_planted cannot exceed tree_cnt_pledged';
    END IF;

    -- Validate ProjectIdn exists
    SELECT string_agg(DISTINCT tp.ProjectIdn::TEXT, ', ')
    INTO v_InvalidProjects
    FROM T_Pledge tp
        LEFT JOIN stp.U_Project p 
            ON tp.ProjectIdn = p.ProjectIdn
    WHERE p.ProjectIdn IS NULL;

    IF v_InvalidProjects IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid project_idn(s): %. Projects do not exist.', v_InvalidProjects;
    END IF;

    -- Validate DonorIdn exists
    SELECT string_agg(DISTINCT tp.DonorIdn::TEXT, ', ')
    INTO v_InvalidDonors
    FROM T_Pledge tp
        LEFT JOIN stp.U_Donor d 
            ON tp.DonorIdn = d.DonorIdn
    WHERE d.DonorIdn IS NULL;

    IF v_InvalidDonors IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid donor_idn(s): %. Donors do not exist.', v_InvalidDonors;
    END IF;

    -- Update existing pledges
    UPDATE stp.U_Pledge up
    SET ProjectIdn = tp.ProjectIdn,
        DonorIdn = tp.DonorIdn,
        PledgeTs = tp.PledgeTs,
        TreeCntPledged = tp.TreeCntPledged,
        TreeCntPlanted = tp.TreeCntPlanted,
        PledgeCredit = tp.PledgeCredit,
        PropertyList = tp.PropertyList,
        UserIdn = P_UserIdn
    FROM T_Pledge tp
    WHERE up.PledgeIdn = tp.PledgeIdn
    AND tp.PledgeIdn IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'UPDATE stp.U_Pledge');

    -- Insert new pledges
    INSERT INTO stp.U_Pledge (ProjectIdn, DonorIdn, PledgeTs, TreeCntPledged, TreeCntPlanted, PledgeCredit, PropertyList, UserIdn)
    SELECT
        tp.ProjectIdn,
        tp.DonorIdn,
        tp.PledgeTs,
        tp.TreeCntPledged,
        tp.TreeCntPlanted,
        tp.PledgeCredit,
        tp.PropertyList,
        P_UserIdn
    FROM T_Pledge tp
    WHERE tp.PledgeIdn IS NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT stp.U_Pledge');

    -- Return saved pledges
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'pledge_idn', up.PledgeIdn,
                'project_idn', up.ProjectIdn,
                'donor_idn', up.DonorIdn,
                'pledge_ts', up.PledgeTs,
                'tree_cnt_pledged', up.TreeCntPledged,
                'tree_cnt_planted', up.TreeCntPlanted,
                'pledge_credit', up.PledgeCredit,
                'property_list', up.PropertyList
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Pledge up
    WHERE (up.ProjectIdn, up.DonorIdn) IN (SELECT ProjectIdn, DonorIdn FROM T_Pledge);
    CALL core.P_Step(p_RunLogIdn, null, 'prepare SavePledge json');
END;
$BODY$;

-- DeletePledge - Delete pledges with validation
CREATE OR REPLACE PROCEDURE stp.P_DeletePledge(
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
    v_CreateType VARCHAR(32);
    v_DeletedPledgeIdns TEXT;
    v_PledgesWithPhotos TEXT;
BEGIN
    -- Create temp table for delete requests
    CREATE TEMP TABLE T_PledgeDelete (
        PledgeIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_PledgeDelete (PledgeIdn)
    SELECT (T->>'pledge_idn')::INT
    FROM jsonb_array_elements(p_InputJson) AS T
    WHERE T->>'pledge_idn' IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT T_PledgeDelete');

    IF v_Rc = 0 THEN
        RAISE EXCEPTION 'No valid pledge_idn values provided for deletion';
    END IF;

    -- Capture PledgeIdns being deleted
    SELECT string_agg(PledgeIdn::TEXT, ',')
    INTO v_DeletedPledgeIdns
    FROM T_PledgeDelete;

    -- Delete pledges
    DELETE FROM stp.U_Pledge up
    USING T_PledgeDelete tpd
    WHERE up.PledgeIdn = tpd.PledgeIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'DELETE stp.U_Pledge');

    -- Return result
    p_OutputJson := jsonb_build_object(
        'deleted_count', v_Rc,
        'deleted_pledge_idns', COALESCE(v_DeletedPledgeIdns, '')
    );
    CALL core.P_Step(p_RunLogIdn, null, 'prepare DeletePledge json');
END;
$BODY$;

-- Register Pledge APIs
CALL core.P_DbApi (
    '{
        "db_api_name": "RegisterDbApi",	
        "request": {
            "records": [
                {
                    "db_api_name": "GetPledge",
                    "schema_name": "stp",
                    "handler_name": "P_GetPledge",
                    "property_list": {
                        "description": "Searches pledges by donor or project",
                        "version": "1.0",
                        "permissions": ["read"]
                    }
                },
                {
                    "db_api_name": "SavePledge",
                    "schema_name": "stp",
                    "handler_name": "P_SavePledge",
                    "property_list": {
                        "description": "Saves a new pledge or updates an existing one",
                        "version": "1.0",
                        "permissions": ["write"]
                    }
                },
                {
                    "db_api_name": "DeletePledge",
                    "schema_name": "stp",
                    "handler_name": "P_DeletePledge",
                    "property_list": {
                        "description": "Deletes a pledge by Idn",
                        "version": "1.0",
                        "permissions": ["write"]
                    }
                }
            ]
        }
    }'::jsonb,
    null
);

-- End of 3_pledge.sql
select * from stp.U_Pledge;

-- Example 1: Search pledges by donor
CALL core.P_DbApi (
    '{
        "db_api_name": "GetPledge",	
        "request": {
            "donor_idn": "1"
        }
    }'::jsonb,
    NULL
);

-- Example 2: Search pledges by project
CALL core.P_DbApi (
    '{
        "db_api_name": "GetPledge",	
        "request": {
            "project_idn": "1"
        }
    }'::jsonb,
    NULL
);

-- Example 3: Search all pledges
CALL core.P_DbApi (
    '{
        "db_api_name": "GetPledge",	
        "request": {}
    }'::jsonb,
    NULL
);

-- Example 4: Insert new pledges with required fields only
CALL core.P_DbApi(
    '{
        "db_api_name": "SavePledge",
        "request": [
            {
                "project_idn": "1",
                "donor_idn": "1",
                "tree_cnt_pledged": 100
            },
            {
                "project_idn": "2",
                "donor_idn": "2",
                "tree_cnt_pledged": 50
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 5: Insert new pledges with all optional fields
CALL core.P_DbApi(
    '{
        "db_api_name": "SavePledge",
        "request": [
            {
                "project_idn": "1",
                "donor_idn": "3",
                "pledge_ts": "2026-01-15 10:30:00",
                "tree_cnt_pledged": 200,
                "tree_cnt_planted": 50,
                "pledge_credit": {
                    "amount": 5000,
                    "currency": "INR",
                    "payment_method": "UPI"
                },
                "property_list": {
                    "campaign": "Winter 2026",
                    "notes": "Corporate donation"
                }
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 6: Update existing pledge (use actual pledge_idn from previous inserts)
CALL core.P_DbApi(
    '{
        "db_api_name": "SavePledge",
        "request": [
            {
                "pledge_idn": "1",
                "project_idn": "1",
                "donor_idn": "1",
                "tree_cnt_pledged": 150,
                "tree_cnt_planted": 25,
                "property_list": {
                    "updated": true,
                    "update_reason": "Donor increased pledge"
                }
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 7: Delete single pledge
CALL core.P_DbApi(
    '{
        "db_api_name": "DeletePledge",
        "request": [
            {
                "pledge_idn": "2"
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 8: Delete multiple pledges
CALL core.P_DbApi(
    '{
        "db_api_name": "DeletePledge",
        "request": [
            {
                "pledge_idn": "3"
            },
            {
                "pledge_idn": "4"
            }
        ]
    }'::jsonb,
    NULL
);

select * from stp.U_Pledge;
select * from core.V_RL ORDER BY RunLogIdn DESC;
select * from core.V_RLS WHERE RunLogIdn=(select MAX(RunLogIdn) from core.U_RunLog) order by Idn;
