--truncate table U_RunLog RESTART IDENTITY;
--truncate table U_RunLogStep RESTART IDENTITY;
CALL core.P_DbApi (
    '{
		"schema_name": "stp",	
		"handler_name":"p_getproject",
		"request": {
			  "project_pattern": null
    	}
	}'::jsonb,
    NULL
    );

delete from stp.U_Project where ProjectId in ('PROJ001','PROJ002');
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
select * from Stp.U_Project;
select * from core.V_RL ORDER BY RunLogIdn DESC LIMIT 1;
select * from core.V_RLS WHERE RunLogIdn=(select MAX(RunLogIdn) from core.U_RunLog) order by Idn;
