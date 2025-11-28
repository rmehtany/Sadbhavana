-- Create the stored procedure with transaction management
CREATE OR REPLACE PROCEDURE P_GetTreeClusters(
    IN p_input_json JSONB,
    INOUT p_output_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_gridSize FLOAT;
	v_rows_affected INTEGER;
	v_zoom INTEGER;
	v_east_lng FLOAT8;
	v_west_lng FLOAT8;
	v_north_lat FLOAT8;
	v_south_lat FLOAT8;
BEGIN
	v_zoom = p_input_json->>'zoom';
	v_gridSize = 0.1 / power(2, v_zoom-8);
	v_east_lng = p_input_json->>'east_lng';
	v_west_lng = p_input_json->>'west_lng';
	v_north_lat = p_input_json->>'north_lat';
	v_south_lat = p_input_json->>'south_lat';

	WITH aggregated_trees AS (
	    SELECT 
	        ST_Y(ST_SnapToGrid(t.tree_location::geometry, v_gridSize, v_gridSize))::FLOAT AS grid_lat,
	        ST_X(ST_SnapToGrid(t.tree_location::geometry, v_gridSize, v_gridSize))::FLOAT AS grid_lng,
	        COUNT(*) AS tree_count,
	        ARRAY_AGG(t.id)::VARCHAR[] AS tree_ids
	    FROM core.tree t
	    WHERE t.tree_location && ST_MakeEnvelope(v_west_lng, v_south_lat, v_east_lng, v_north_lat, 4326)::geography
	    GROUP BY ST_SnapToGrid(t.tree_location::geometry, v_gridSize, v_gridSize)
	    HAVING COUNT(*) > 0
	)
	SELECT jsonb_agg(
	    jsonb_build_object(
	        'grid_lat', grid_lat,
	        'grid_lng', grid_lng,
	        'tree_count', tree_count,
	        'tree_ids', tree_ids
	    )
	)
	INTO p_output_json
	FROM aggregated_trees;

    -- Return empty array if no output
    IF p_output_json IS NULL THEN
        p_output_json := '[]'::jsonb;
    END IF;
    

EXCEPTION
    WHEN OTHERS THEN
        -- Rollback on any error
        ROLLBACK;
        
        -- Re-raise the exception with details
        RAISE EXCEPTION 'Transaction failed: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END;
$BODY$;

DO $RUN$
DECLARE
    v_output JSONB;
BEGIN
    CALL P_GetTreeClusters (
    '{
		  "zoom": 7,
		  "east_lng": 84.5947265625,
		  "west_lng": 63.50097656250001,
		  "north_lat": 25.423431426334247,
		  "south_lat": 16.0774858690887
    }'::jsonb,
    v_output
    );

    -- Display the output
    RAISE NOTICE 'Output: %', v_output;
END 
$RUN$;
