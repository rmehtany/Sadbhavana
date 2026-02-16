-- 9_examplecalls.sql
-- Comprehensive examples for Sadbhavana Tree Project Database API
-- This file contains examples of how to call the STP handlers via core.P_DbApi

-- ============================================================================
-- 0. PREPARATION & REGISTRATION
-- ============================================================================

-- First, ensure all handlers are registered in core.U_DbApi
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
                    {"db_api_name": "SaveProject", "schema_name": "stp", "handler_name": "P_SaveProject", "property_list": {}},
                    {"db_api_name": "DeleteProject", "schema_name": "stp", "handler_name": "P_DeleteProject", "property_list": {}},
                    {"db_api_name": "GetDonor", "schema_name": "stp", "handler_name": "P_GetDonor", "property_list": {}},
                    {"db_api_name": "SaveDonor", "schema_name": "stp", "handler_name": "P_SaveDonor", "property_list": {}},
                    {"db_api_name": "DeleteDonor", "schema_name": "stp", "handler_name": "P_DeleteDonor", "property_list": {}},
                    {"db_api_name": "GetPledge", "schema_name": "stp", "handler_name": "P_GetPledge", "property_list": {}},
                    {"db_api_name": "SavePledge", "schema_name": "stp", "handler_name": "P_SavePledge", "property_list": {}},
                    {"db_api_name": "DeletePledge", "schema_name": "stp", "handler_name": "P_DeletePledge", "property_list": {}},
                    {"db_api_name": "CreateTreeBulk", "schema_name": "stp", "handler_name": "P_CreateTreeBulk", "property_list": {}},
                    {"db_api_name": "GetTree", "schema_name": "stp", "handler_name": "P_GetTree", "property_list": {}},
                    {"db_api_name": "SaveTree", "schema_name": "stp", "handler_name": "P_SaveTree", "property_list": {}},
                    {"db_api_name": "DeleteTree", "schema_name": "stp", "handler_name": "P_DeleteTree", "property_list": {}},
                    {"db_api_name": "UploadTreePhoto", "schema_name": "stp", "handler_name": "P_UploadTreePhoto", "property_list": {}},
                    {"db_api_name": "GetTreePhotos", "schema_name": "stp", "handler_name": "P_GetTreePhotos", "property_list": {}},
                    {"db_api_name": "GetDonorUpdate", "schema_name": "stp", "handler_name": "P_GetDonorUpdate", "property_list": {}},
                    {"db_api_name": "PostDonorUpdate", "schema_name": "stp", "handler_name": "P_PostDonorUpdate", "property_list": {}},
                    {"db_api_name": "GetProvider", "schema_name": "stp", "handler_name": "P_GetProvider", "property_list": {}},
                    {"db_api_name": "SaveProvider", "schema_name": "stp", "handler_name": "P_SaveProvider", "property_list": {}},
                    {"db_api_name": "DeleteProvider", "schema_name": "stp", "handler_name": "P_DeleteProvider", "property_list": {}}
                ]
            }
        }'::JSONB,
        v_OutputJson
    );
END $$;

-- Check registration status
SELECT * FROM core.U_DbApi WHERE SchemaName = 'stp';

-- ============================================================================
-- 1. PROJECT EXAMPLES
-- ============================================================================

-- 1.1 Save (Create) Projects
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveProject",
        "user_idn": 1,
        "request": [
            {
                "project_id": "TEST_PROJ_001",
                "project_name": "Example Plantation Site A",
                "latitude": 22.4707,
                "longitude": 70.0577,
                "tree_cnt_pledged": 500
            },
            {
                "project_id": "TEST_PROJ_002",
                "project_name": "Example Plantation Site B",
                "latitude": 22.3039,
                "longitude": 70.7867,
                "tree_cnt_pledged": 1000
            }
        ]
    }'::JSONB,
    NULL -- Output is logged in core.V_RL
);

-- 1.2 Get (Search) Projects
CALL core.P_DbApi(
    '{
        "db_api_name": "GetProject",
        "request": {
            "project_pattern": "Example"
        }
    }'::JSONB,
    NULL
);

-- ============================================================================
-- 2. DONOR EXAMPLES
-- ============================================================================

-- 2.1 Save (Create) Donors
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveDonor",
        "user_idn": 1,
        "request": [
            {
                "donor_name": "John Doe",
                "mobile_number": "+91-9999988888",
                "city": "Rajkot",
                "country": "India",
                "email_addr": "john.doe.example@gmail.com"
            }
        ]
    }'::JSONB,
    NULL
);

-- 2.2 Get Donors
CALL core.P_DbApi(
    '{
        "db_api_name": "GetDonor",
        "request": {
            "donor_pattern": "John"
        }
    }'::JSONB,
    NULL
);

-- ============================================================================
-- 3. PLEDGE EXAMPLES
-- ============================================================================

-- 3.1 Save (Create) Pledges
-- Note: Requires valid project_idn and donor_idn from previous steps
DO $$
DECLARE
    v_ProjectIdn INT;
    v_DonorIdn INT;
    v_OutputJson JSONB;
BEGIN
    SELECT ProjectIdn INTO v_ProjectIdn FROM stp.U_Project WHERE ProjectId = 'TEST_PROJ_001' LIMIT 1;
    SELECT DonorIdn INTO v_DonorIdn FROM stp.U_Donor WHERE MobileNumber = '+91-9999988888' LIMIT 1;

    CALL core.P_DbApi(
        jsonb_build_object(
            'db_api_name', 'SavePledge',
            'user_idn', 1,
            'request', jsonb_build_array(
                jsonb_build_object(
                    'project_idn', v_ProjectIdn,
                    'donor_idn', v_DonorIdn,
                    'tree_cnt_pledged', 5,
                    'pledge_credit', '{"Personal": 5}'::jsonb
                )
            )
        ),
        v_OutputJson
    );
END $$;

-- 3.2 Get Pledges
CALL core.P_DbApi(
    '{
        "db_api_name": "GetPledge",
        "request": {}
    }'::JSONB,
    NULL
);

-- ============================================================================
-- 4. TREE EXAMPLES
-- ============================================================================

-- 4.1 Create Trees Bulk (from Pledges)
DO $$
DECLARE
    v_ProjectIdn INT;
    v_OutputJson JSONB;
BEGIN
    SELECT ProjectIdn INTO v_ProjectIdn FROM stp.U_Project WHERE ProjectId = 'TEST_PROJ_001' LIMIT 1;

    CALL core.P_DbApi(
        jsonb_build_object(
            'db_api_name', 'CreateTreeBulk',
            'user_idn', 1,
            'request', jsonb_build_object(
                'project_idn', v_ProjectIdn,
                'create_type', 'Missing'
            )
        ),
        v_OutputJson
    );
END $$;

-- 4.2 Get Trees
CALL core.P_DbApi(
    '{
        "db_api_name": "GetTree",
        "request": {
            "tree_id_pattern": "TEST_PROJ"
        }
    }'::JSONB,
    NULL
);

-- 4.3 Save (Update) Tree Location
DO $$
DECLARE
    v_TreeIdn INT;
    v_OutputJson JSONB;
BEGIN
    SELECT TreeIdn INTO v_TreeIdn FROM stp.U_Tree WHERE TreeId LIKE 'TEST_PROJ_001%' LIMIT 1;

    CALL core.P_DbApi(
        jsonb_build_object(
            'db_api_name', 'SaveTree',
            'user_idn', 1,
            'request', jsonb_build_array(
                jsonb_build_object(
                    'tree_idn', v_TreeIdn,
                    'latitude', 22.4708,
                    'longitude', 70.0578,
                    'tree_type_idn', 1
                )
            )
        ),
        v_OutputJson
    );
END $$;

-- ============================================================================
-- 5. PHOTO EXAMPLES
-- ============================================================================

-- 5.1 Save Provider (if needed for uploads)
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveProvider",
        "user_idn": 1,
        "request": [
            {
                "provider_name": "LOCAL_STORAGE",
                "auth_type": "None"
            }
        ]
    }'::JSONB,
    NULL
);

-- 5.2 Upload Tree Photo
DO $$
DECLARE
    v_TreeId VARCHAR(64);
    v_OutputJson JSONB;
BEGIN
    SELECT TreeId INTO v_TreeId FROM stp.U_Tree WHERE TreeId LIKE 'TEST_PROJ_001%' LIMIT 1;

    CALL core.P_DbApi(
        jsonb_build_object(
            'db_api_name', 'UploadTreePhoto',
            'user_idn', 1,
            'request', jsonb_build_array(
                jsonb_build_object(
                    'tree_id', v_TreeId,
                    'provider_name', 'LOCAL_STORAGE',
                    'file_store_id', 'test_photo_123',
                    'file_path', '/tmp/photos',
                    'file_name', 'tree_test.jpg',
                    'file_type', 'image/jpeg',
                    'photo_latitude', 22.4709,
                    'photo_longitude', 70.0579
                )
            )
        ),
        v_OutputJson
    );
END $$;

-- 5.3 Get Tree Photos
DO $$
DECLARE
    v_TreeIdn INT;
    v_OutputJson JSONB;
BEGIN
    SELECT TreeIdn INTO v_TreeIdn FROM stp.U_Tree WHERE TreeId LIKE 'TEST_PROJ_001%' LIMIT 1;

    CALL core.P_DbApi(
        jsonb_build_object(
            'db_api_name', 'GetTreePhotos',
            'request', jsonb_build_object(
                'tree_idn', v_TreeIdn
            )
        ),
        v_OutputJson
    );
END $$;

-- ============================================================================
-- 6. DONOR UPDATE EXAMPLES
-- ============================================================================

-- 6.1 Get Pending Donor Updates
-- This retrieves a batch of pending notifications (default batch size 100)
CALL core.P_DbApi(
    '{
        "db_api_name": "GetDonorUpdate",
        "request": {}
    }'::JSONB,
    NULL
);

-- 6.2 Get Donor Updates with Custom Batch Size
CALL core.P_DbApi(
    '{
        "db_api_name": "GetDonorUpdate",
        "request": {
            "batch_size": 10
        }
    }'::JSONB,
    NULL
);

-- 6.3 Post Donor Update Status (Sent/Failed)
-- Note: Replace idn values with actual ones from GetDonorUpdate output
CALL core.P_DbApi(
    '{
        "db_api_name": "PostDonorUpdate",
        "request": [
            {"idn": 1, "send_status": "sent"},
            {"idn": 2, "send_status": "failed"}
        ]
    }'::JSONB,
    NULL
);

-- ============================================================================
-- 7. PROVIDER EXAMPLES
-- ============================================================================

-- 7.1 Get All Providers
CALL core.P_DbApi(
    '{
        "db_api_name": "GetProvider",
        "request": {}
    }'::JSONB,
    NULL
);

-- 7.2 Get Specific Provider
-- Note: Requires valid provider_idn
DO $$
DECLARE
    v_ProviderIdn INT;
    v_OutputJson JSONB;
BEGIN
    SELECT ProviderIdn INTO v_ProviderIdn FROM stp.U_Provider WHERE ProviderName = 'LOCAL_STORAGE' LIMIT 1;

    IF v_ProviderIdn IS NOT NULL THEN
        CALL core.P_DbApi(
            jsonb_build_object(
                'db_api_name', 'GetProvider',
                'request', jsonb_build_object('provider_idn', v_ProviderIdn)
            ),
            v_OutputJson
        );
    END IF;
END $$;

-- 7.3 Delete Provider
-- Note: Provider cannot be deleted if it has associated files
-- This example is for illustration; usually run at the end of cleanup
-- CALL core.P_DbApi(
--     '{
--         "db_api_name": "DeleteProvider",
--         "request": [{"provider_idn": 1}]
--     }'::JSONB,
--     NULL
-- );

-- ============================================================================
-- 8. DELETE EXAMPLES (CLEANUP)
-- ============================================================================

-- 8.1 Delete Donor (Standard - fails if pledges exist)
DO $$
DECLARE
    v_DonorIdn INT;
    v_OutputJson JSONB;
BEGIN
    -- This will fail if the donor has pledges, unless cascade is used
    SELECT DonorIdn INTO v_DonorIdn FROM stp.U_Donor WHERE MobileNumber = '+91-9999988888' LIMIT 1;
    
    IF v_DonorIdn IS NOT NULL THEN
        CALL core.P_DbApi(
            jsonb_build_object(
                'db_api_name', 'DeleteDonor',
                'request', jsonb_build_object(
                    'donors', jsonb_build_array(jsonb_build_object('donor_idn', v_DonorIdn)),
                    'cascade', false
                )
            ),
            v_OutputJson
        );
    END IF;
END $$;

-- 8.2 Delete Pledge (Standard - fails if trees exist)
DO $$
DECLARE
    v_PledgeIdn INT;
    v_OutputJson JSONB;
BEGIN
    SELECT PledgeIdn INTO v_PledgeIdn FROM stp.U_Pledge p JOIN stp.U_Project pr ON p.ProjectIdn = pr.ProjectIdn WHERE pr.ProjectId = 'TEST_PROJ_001' LIMIT 1;

    IF v_PledgeIdn IS NOT NULL THEN
        CALL core.P_DbApi(
            jsonb_build_object(
                'db_api_name', 'DeletePledge',
                'request', jsonb_build_object(
                    'pledges', jsonb_build_array(jsonb_build_object('pledge_idn', v_PledgeIdn)),
                    'cascade', false
                )
            ),
            v_OutputJson
        );
    END IF;
END $$;

-- 8.3 Delete Tree (by Pledge)
DO $$
DECLARE
    v_PledgeIdn INT;
    v_OutputJson JSONB;
BEGIN
    SELECT PledgeIdn INTO v_PledgeIdn FROM stp.U_Pledge p JOIN stp.U_Project pr ON p.ProjectIdn = pr.ProjectIdn WHERE pr.ProjectId = 'TEST_PROJ_002' LIMIT 1;
    IF v_PledgeIdn IS NOT NULL THEN
        CALL core.P_DbApi(
            jsonb_build_object(
                'db_api_name', 'DeleteTree',
                'request', jsonb_build_object(
                    'pledges', jsonb_build_array(jsonb_build_object('pledge_idn', v_PledgeIdn)),
                    'force_delete', true
                )
            ),
            v_OutputJson
        );
    END IF;
END $$;

-- 8.4 Cascade Delete Project (and all related data)
DO $$
DECLARE
    v_ProjectIdn INT;
    v_OutputJson JSONB;
BEGIN
    SELECT ProjectIdn INTO v_ProjectIdn FROM stp.U_Project WHERE ProjectId = 'TEST_PROJ_001' LIMIT 1;
    
    IF v_ProjectIdn IS NOT NULL THEN
        CALL core.P_DbApi(
            jsonb_build_object(
                'db_api_name', 'DeleteProject',
                'request', jsonb_build_object(
                    'projects', jsonb_build_array(jsonb_build_object('project_idn', v_ProjectIdn)),
                    'cascade', true
                )
            ),
            v_OutputJson
        );
    END IF;
END $$;

-- ============================================================================
-- 9. MONITORING RUN LOGS
-- ============================================================================

-- View summary of recent runs
SELECT * FROM core.V_RL ORDER BY runlogidn DESC LIMIT 20;

-- View detailed steps of the very last run
SELECT * FROM core.V_RLS 
WHERE runlogidn = (SELECT MAX(runlogidn) FROM core.u_runlog)
ORDER BY idn;

-- View errors only
SELECT * FROM core.V_RLS 
WHERE runlogidn = (SELECT MAX(runlogidn) FROM core.u_runlog)
  AND step LIKE 'ERROR%'
ORDER BY idn;
