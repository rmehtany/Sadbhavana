DO $RUN$
DECLARE
    v_output JSONB;
BEGIN
    CALL core.P_Envelope (
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