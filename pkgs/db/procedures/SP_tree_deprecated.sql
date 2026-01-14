-- GetTreesByProjectCluster 
CREATE OR REPLACE PROCEDURE core.P_GetTreesByProjectCluster(
    IN p_input_json JSONB,
    INOUT p_output_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
	v_rows_affected INTEGER;
    v_donor_id varchar(21);
	v_east_lng FLOAT8;
	v_west_lng FLOAT8;
	v_north_lat FLOAT8;
	v_south_lat FLOAT8;
BEGIN
	v_donor_id = p_input_json->>'donor_id';
	v_east_lng = p_input_json->>'east_lng';
	v_west_lng = p_input_json->>'west_lng';
	v_north_lat = p_input_json->>'north_lat';
	v_south_lat = p_input_json->>'south_lat';

	SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'project_code', project_code,
                'project_name', project_name,
                'tree_count', tree_count,
                'center_lat', center_lat,
                'center_lng', center_lng
            )
        ), '[]'::jsonb
    )
	INTO p_output_json
	FROM 
		(SELECT 
		    t.project_code,
		    min(tw.project_name) AS project_name,	-- Fake AGGR
		    COUNT(*) as tree_count,
		    AVG(ST_Y(t.tree_location::geometry))::FLOAT as center_lat,
		    AVG(ST_X(t.tree_location::geometry))::FLOAT as center_lng
		FROM core.tree t
			JOIN core.project tw 
				ON t.project_code=tw.project_code
		WHERE t.donor_id = COALESCE(v_donor_id, t.donor_id) 
        AND ST_Y(t.tree_location::geometry) BETWEEN v_south_lat AND v_north_lat
		AND ST_X(t.tree_location::geometry) BETWEEN v_west_lng AND v_east_lng
		GROUP BY t.project_code
		);
END;
$BODY$;

-- Create the stored procedure with transaction management
CREATE OR REPLACE PROCEDURE core.P_GetTreesByGridCluster(
    IN p_input_json JSONB,
    INOUT p_output_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_gridSize FLOAT;
    v_rows_affected INTEGER;
    v_donor_id varchar(21);
    v_zoom INTEGER;
    v_east_lng FLOAT8;
    v_west_lng FLOAT8;
    v_north_lat FLOAT8;
    v_south_lat FLOAT8;
BEGIN
    v_donor_id = p_input_json->>'donor_id';
    v_zoom = p_input_json->>'zoom';
    v_gridSize = 0.1 / power(2, v_zoom-10);
    v_east_lng = p_input_json->>'east_lng';
    v_west_lng = p_input_json->>'west_lng';
    v_north_lat = p_input_json->>'north_lat';
    v_south_lat = p_input_json->>'south_lat';

    SELECT COALESCE(
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
    INTO p_output_json
    FROM 
    (SELECT 
            ST_Y(ST_SnapToGrid(t.tree_location::geometry, v_gridSize, v_gridSize))::FLOAT AS grid_lat,
            ST_X(ST_SnapToGrid(t.tree_location::geometry, v_gridSize, v_gridSize))::FLOAT AS grid_lng,
            COUNT(*) AS tree_count,
            ARRAY_AGG(t.id)::VARCHAR[] AS tree_ids
        FROM core.tree t
        WHERE t.donor_id = COALESCE(v_donor_id, t.donor_id)
        AND t.tree_location && ST_MakeEnvelope(v_west_lng,v_south_lat,v_east_lng,v_north_lat, 4326)::geography
        GROUP BY ST_SnapToGrid(t.tree_location::geometry, v_gridSize, v_gridSize)
        HAVING COUNT(*)>0
    ) subquery;
END;
$BODY$;

-- Create the stored procedure with transaction management
CREATE OR REPLACE PROCEDURE core.P_GetIndividualTrees(
    IN p_input_json JSONB,
    INOUT p_output_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_rows_affected INTEGER;
    v_donor_id varchar(21);
    v_east_lng FLOAT8;
    v_west_lng FLOAT8;
    v_north_lat FLOAT8;
    v_south_lat FLOAT8;
BEGIN
    v_donor_id = p_input_json->>'donor_id';
    v_east_lng = p_input_json->>'east_lng';
    v_west_lng = p_input_json->>'west_lng';
    v_north_lat = p_input_json->>'north_lat';
    v_south_lat = p_input_json->>'south_lat';

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'latitude', latitude,
                'longitude', longitude,
                'id', id
            )
        ),
        '[]'::jsonb
    )
    INTO p_output_json
    FROM 
        (SELECT 
            ST_Y(tree_location::geometry)::FLOAT as latitude,
            ST_X(tree_location::geometry)::FLOAT as longitude,
            id
        FROM core.tree
        WHERE donor_id = COALESCE(v_donor_id, donor_id) 
            AND ST_Y(tree_location::geometry) BETWEEN v_south_lat AND v_north_lat
            AND ST_X(tree_location::geometry) BETWEEN v_west_lng AND v_east_lng
        ) subquery;
END;
$BODY$;

-- Create the stored procedure with transaction management
CREATE OR REPLACE PROCEDURE core.P_GetTreeByID(
    IN p_input_json JSONB,
    INOUT p_output_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_rows_affected INTEGER;
    v_tree_id varchar(21);
BEGIN
    v_tree_id = p_input_json->>'tree_id';

    SELECT COALESCE(
        jsonb_build_object(
            'id', id,
            'project_code', project_code, 
            'tree_number', tree_number,
            'donor_id', donor_id,
            'latitude', latitude,
            'longitude', longitude,
            'planted_at', planted_at,
            'created_at', created_at,
            'metadata', metadata,
            'donor_name', donor_name,
            'donor_phone_number', donor_phone_number,
            'project_name', project_name,
            'project_metadata', project_metadata
        ),
        '{}'::jsonb
    )
    INTO p_output_json
    FROM 
        (SELECT 
            t.id,
            t.project_code,
            t.tree_number,
            t.donor_id,
            ST_Y(t.tree_location::geometry)::FLOAT as latitude,
            ST_X(t.tree_location::geometry)::FLOAT as longitude,
            t.planted_at,
            t.created_at,
            t.metadata,
            d.donor_name,
            d.phone_number as donor_phone_number,
            tw.project_name,
            tw.metadata as project_metadata
        FROM core.tree t
            JOIN core.donor d 
                ON t.donor_id = d.id
            JOIN core.project tw 
                ON t.project_code = tw.project_code
        WHERE t.id = v_tree_id
        ) subquery;
END;
$BODY$;
