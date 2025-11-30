-- Create the stored procedure with transaction management
CREATE OR REPLACE PROCEDURE P_GetProjectTreeCnts(
    IN p_input_json JSONB,
    INOUT p_output_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
	v_rows_affected INTEGER;
	v_east_lng FLOAT8;
	v_west_lng FLOAT8;
	v_north_lat FLOAT8;
	v_south_lat FLOAT8;
BEGIN
	v_east_lng = p_input_json->>'east_lng';
	v_west_lng = p_input_json->>'west_lng';
	v_north_lat = p_input_json->>'north_lat';
	v_south_lat = p_input_json->>'south_lat';

	SELECT jsonb_agg(
	    jsonb_build_object(
	        'project_code', project_code,
	        'project_name', project_name,
	        'tree_count', tree_count,
	        'center_lat', center_lat,
	        'center_lng', center_lng
	    )
	)
	INTO p_output_json
	FROM 
		(SELECT 
		    t.project_code,
		    min(tw.project_name) AS project_name,
		    COUNT(*) as tree_count,
		    AVG(ST_Y(t.tree_location::geometry))::FLOAT as center_lat,
		    AVG(ST_X(t.tree_location::geometry))::FLOAT as center_lng
		FROM core.tree t
			JOIN core.project tw 
				ON t.project_code=tw.project_code
		WHERE ST_Y(t.tree_location::geometry) BETWEEN v_south_lat AND v_north_lat
		AND ST_X(t.tree_location::geometry) BETWEEN v_west_lng AND v_east_lng
		GROUP BY t.project_code
		);
	
    -- Return empty array if no output
--    IF p_output_json IS NULL THEN
--        p_output_json := '[]'::jsonb;
--    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Rollback on any error
        ROLLBACK;
        
        -- Re-raise the exception with details
        RAISE EXCEPTION 'Transaction failed: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END;
$BODY$;

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

    SELECT jsonb_build_object(
        'clusters',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'grid_lat', grid_lat,
                    'grid_lng', grid_lng,
                    'tree_count', tree_count,
                    'tree_ids', tree_ids
                )
            ),
            '[]'::jsonb
        )
    )
    INTO p_output_json
    FROM 
    (SELECT 
            ST_Y(ST_SnapToGrid(t.tree_location::geometry, v_gridSize, v_gridSize))::FLOAT AS grid_lat,
            ST_X(ST_SnapToGrid(t.tree_location::geometry, v_gridSize, v_gridSize))::FLOAT AS grid_lng,
            COUNT(*) AS tree_count,
            ARRAY_AGG(t.id)::VARCHAR[] AS tree_ids
        FROM core.tree t
        WHERE t.tree_location && ST_MakeEnvelope(v_west_lng,v_south_lat,v_east_lng,v_north_lat, 4326)::geography
        GROUP BY ST_SnapToGrid(t.tree_location::geometry, v_gridSize, v_gridSize)
        HAVING COUNT(*)>0
    ) subquery;

EXCEPTION
    WHEN OTHERS THEN
        -- Rollback on any error
        ROLLBACK;
        
        -- Re-raise the exception with details
        RAISE EXCEPTION 'Transaction failed: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END;
$BODY$;
