truncate table U_RunLog RESTART IDENTITY;
truncate table U_RunLogStep RESTART IDENTITY;

DO $RUN$
DECLARE
    v_output JSONB;
BEGIN
    CALL core.P_DbApi (
    '{
		"schema_name": "core",	
		"handler_name":"p_gettreesbyprojectcluster",
		"request": {
			  "east_lng": 84.5947265625,
			  "west_lng": 63.50097656250001,
			  "north_lat": 25.423431426334247,
			  "south_lat": 16.0774858690887
    	}
	}'::jsonb,
    v_output
    );

    RAISE NOTICE 'Output: %', v_output;
END 
$RUN$;

select * from core.V_RL ORDER BY RunLogIdn DESC LIMIT 1;
select * from core.V_RLS WHERE RunLogIdn=(select MAX(RunLogIdn) from core.U_RunLog) order by Idn;

