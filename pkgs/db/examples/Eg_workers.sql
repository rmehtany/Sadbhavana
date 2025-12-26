--truncate table U_RunLog RESTART IDENTITY;
--truncate table U_RunLogStep RESTART IDENTITY;

--DO $RUN$
--DECLARE
--    v_output JSONB;
--BEGIN
--    CALL core.P_DbApi (
--    '{
--		"schema_name": "stp",	
--		"handler_name":"p_getproject",
--		"request": {
--			  "project_pattern": null
--    	}
--	}'::jsonb,
--    v_output
--    );
--
--    --RAISE NOTICE 'Output: %', v_output;
--END 
--$RUN$;
--

-- Insert new projects (ProjectIdn is null or not provided)
CALL core.P_DbApi(
    '{
		"schema_name": "stp",	
		"handler_name":"p_saveproject",
        "request": [
            {
                "project_id": "PROJ001",
                "project_name": "Forest Restoration Alpha",
                "tree_cnt_pledged": 1000,
                "tree_cnt_planted": 500,
                "latitude": 40.7128,
                "longitude": -74.0060
            },
            {
                "project_id": "PROJ002",
                "project_name": "Coastal Mangrove Initiative",
                "tree_cnt_pledged": 2000,
                "tree_cnt_planted": 750,
                "latitude": 25.7617,
                "longitude": -80.1918
            }
        ]
    }'::jsonb,
    NULL
);
select * from STP.U_Project;
-- Update existing projects (ProjectIdn is provided)
CALL STP.P_SaveProject(
    '{
        "items": [
            {
                "project_idn": 8,
                "project_id": "PROJ001",
                "project_name": "Forest Restoration Alpha - Updated",
                "tree_cnt_pledged": 1500,
                "tree_cnt_planted": 800,
                "latitude": 40.7128,
                "longitude": -74.0060
            }
        ]
    }'::jsonb,
    NULL
);

-- Mix of insert and update
CALL STP.P_SaveProject(
    '{
        "items": [
            {
                "project_idn": 8,
                "project_id": "PROJ001",
                "project_name": "Updated Project",
                "tree_cnt_pledged": 1500,
                "tree_cnt_planted": 800,
                "latitude": 40.7128,
                "longitude": -74.0060
            },
            {
                "project_id": "PROJ003",
                "project_name": "New Project",
                "tree_cnt_pledged": 500,
                "tree_cnt_planted": 100,
                "latitude": 34.0522,
                "longitude": -118.2437
            }
        ]
    }'::jsonb,
    NULL
);
select * from Stp.U_Project;
select * from core.V_RL ORDER BY RunLogIdn DESC LIMIT 1;
select * from core.V_RLS WHERE RunLogIdn=(select MAX(RunLogIdn) from core.U_RunLog) order by Idn;
