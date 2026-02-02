-- 4_tree.sql
-- create_tree_bulk
-- get_tree
-- search_tree
-- save_tree
-- delete_tree

-- CreateTreeBulk - Create trees for pledges in a project
CREATE OR REPLACE PROCEDURE stp.P_CreateTreeBulk(
    IN      P_AnchorTs      TIMESTAMPTZ,
    IN      P_UserIdn       INT,
    IN      P_RunLogIdn     INT,
    IN      p_InputJson     JSONB,
    INOUT   p_OutputJson    JSONB
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_CreateType        VARCHAR(32);
    v_MaxTreeNum        INT;
    v_ProjectId         VARCHAR(64);
    v_ProjectIdn        INT;
    v_Rc                INTEGER;
    v_DefaultTreeTypeIdn INT;
    v_PledgesWithPhotos TEXT;
    v_TotalPledgedTrees INT;
    v_CreditTreeCount   INT;
BEGIN
    -- Get and validate ProjectIdn
    v_ProjectIdn := NULLIF(p_InputJson->>'project_idn', '')::INT;
    IF v_ProjectIdn IS NULL THEN
        RAISE EXCEPTION 'project_idn is required';
    END IF;
    CALL core.P_Step(p_RunLogIdn, NULL, 'ProjectIdn: ' || v_ProjectIdn);

    -- Get CreateType
    v_CreateType := COALESCE(p_InputJson->>'create_type', 'Missing');
    CALL core.P_Step(p_RunLogIdn, NULL, 'CreateType: ' || v_CreateType);

    -- Validate project exists and get ProjectId
    SELECT ProjectId
    INTO v_ProjectId
    FROM stp.U_Project
    WHERE ProjectIdn = v_ProjectIdn;
    
    IF v_ProjectId IS NULL THEN
        RAISE EXCEPTION 'Project not found for ProjectIdn: %', v_ProjectIdn;
    END IF;
    CALL core.P_Step(p_RunLogIdn, NULL, 'Found Project: ' || v_ProjectId);

    -- Handle Clean option
    IF v_CreateType = 'Clean' THEN
        -- Check if any trees have photos
        SELECT string_agg(DISTINCT p.PledgeIdn::TEXT, ', ')
        INTO v_PledgesWithPhotos
        FROM stp.U_Pledge p
            JOIN stp.U_Tree t 
                ON p.PledgeIdn = t.PledgeIdn
            JOIN stp.U_TreePhoto tp 
                ON t.TreeIdn = tp.TreeIdn
        WHERE p.ProjectIdn = v_ProjectIdn;

        IF v_PledgesWithPhotos IS NOT NULL THEN
            RAISE EXCEPTION 'Cannot delete trees for pledge(s) % - trees have photos in U_TreePhoto', v_PledgesWithPhotos;
        END IF;

        -- Delete existing trees for this project
        DELETE FROM stp.U_Tree t
        USING stp.U_Pledge p
        WHERE t.PledgeIdn = p.PledgeIdn
          AND p.ProjectIdn = v_ProjectIdn;
        GET DIAGNOSTICS v_Rc = ROW_COUNT;
        CALL core.P_Step(p_RunLogIdn, v_Rc, 'DELETE stp.U_Tree (Clean mode)');
    END IF;

    -- Get the current max tree number for this project
    SELECT COALESCE(MAX(SUBSTRING(t.TreeId FROM LENGTH(v_ProjectId) + 1)::INT), 0)
    INTO v_MaxTreeNum
    FROM stp.U_Pledge p
        JOIN stp.U_Tree t 
            ON p.PledgeIdn = t.PledgeIdn
    WHERE p.ProjectIdn = v_ProjectIdn;
    CALL core.P_Step(p_RunLogIdn, NULL, 'Max TreeNum: ' || v_MaxTreeNum);

    -- Create tree records for project pledges
    INSERT INTO stp.U_Tree (TreeId, PledgeIdn, CreditName, TreeTypeIdn, TreeLocation, PropertyList)
	SELECT 
        v_ProjectId || LPAD((v_MaxTreeNum + row_number() OVER (ORDER BY p.PledgeIdn, pc.key, gs.n))::TEXT, 6, '0'),
		p.PledgeIdn,pc.key,NULL,NULL,'{}'::JSONB
	FROM 
		(SELECT p.PledgeIdn,p.DonorIdn,p.TreeCntPledged,p.PledgeCredit
	    FROM stp.U_Pledge p
	        LEFT JOIN stp.U_Tree t
		        ON p.PledgeIdn = t.PledgeIdn
	    WHERE p.ProjectIdn = v_ProjectIdn
	      AND t.TreeIdn IS NULL
		) AS t
	    CROSS JOIN LATERAL jsonb_each_text(t.PledgeCredit) AS pc
	    CROSS JOIN LATERAL generate_series(1, (pc.value)::INT) AS gs(n);
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT stp.U_Tree');

    -- Return summary
    p_OutputJson := jsonb_build_object(
        'project_idn', v_ProjectIdn,
        'project_id', v_ProjectId,
        'trees_created', v_Rc,
        'create_type', v_CreateType
    );
    CALL core.P_Step(p_RunLogIdn, null, 'prepare CreateTreeBulk json');
END;
$BODY$;

-- GetTree - Search trees by various criteria
CREATE OR REPLACE PROCEDURE stp.P_GetTree(
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
    v_PledgeIdn INT;
    v_ProjectIdn INT;
    v_DonorIdn INT;
    v_TreeIdPattern VARCHAR(128);
    v_CreditNamePattern VARCHAR(128);
BEGIN
    -- Extract search criteria
    v_PledgeIdn := NULLIF(p_InputJson->>'pledge_idn', '')::INT;
    v_ProjectIdn := NULLIF(p_InputJson->>'project_idn', '')::INT;
    v_DonorIdn := NULLIF(p_InputJson->>'donor_idn', '')::INT;
    v_TreeIdPattern := '%' || (p_InputJson->>'tree_id_pattern') || '%';
    v_CreditNamePattern := '%' || (p_InputJson->>'credit_name_pattern') || '%';
    
    RAISE NOTICE 'GetTree - PledgeIdn: %, ProjectIdn: %, DonorIdn: %, TreeIdPattern: %, CreditNamePattern: %', 
        v_PledgeIdn, v_ProjectIdn, v_DonorIdn, v_TreeIdPattern, v_CreditNamePattern;

    -- Build result JSON with related information
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'tree_idn', t.TreeIdn,
                'latitude', ST_Y(t.TreeLocation::geometry)::FLOAT,
                'longitude', ST_X(t.TreeLocation::geometry)::FLOAT
            ) ORDER BY t.TreeIdn
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Tree t
	    JOIN stp.U_Pledge p 
			ON t.PledgeIdn = p.PledgeIdn
	    JOIN stp.U_Project pr 
			ON p.ProjectIdn = pr.ProjectIdn
		    AND (v_ProjectIdn IS NULL OR pr.ProjectIdn = v_ProjectIdn)
	    JOIN stp.U_Donor d 
			ON p.DonorIdn = d.DonorIdn
		    AND (v_DonorIdn IS NULL OR p.DonorIdn = v_DonorIdn)
    WHERE (v_PledgeIdn IS NULL OR t.PledgeIdn = v_PledgeIdn)
      AND (v_TreeIdPattern IS NULL OR t.TreeId LIKE v_TreeIdPattern)
      AND (v_CreditNamePattern IS NULL OR t.CreditName LIKE v_CreditNamePattern);

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'prepare GetTree json');
END;
$BODY$;

CREATE OR REPLACE PROCEDURE stp.P_SaveTree(
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
    v_InvalidTreeIdns TEXT;
    v_InvalidTreeTypes TEXT;
BEGIN
    -- Create temp table for input trees (only editable fields)
    CREATE TEMP TABLE T_Tree (
        TreeIdn         INT,
        Lat             FLOAT,
        Lng             FLOAT,
        TreeTypeIdn     INT
    ) ON COMMIT DROP;

    -- Parse input JSON - only TreeIdn, location, and type are allowed
    INSERT INTO T_Tree (TreeIdn, Lat, Lng, TreeTypeIdn)
    SELECT 
        (T->>'tree_idn')::INT,
        NULLIF(T->>'latitude', '')::FLOAT,
        NULLIF(T->>'longitude', '')::FLOAT,
        NULLIF(T->>'tree_type_idn', '')::INT
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT T_Tree');

    -- Validate required field: TreeIdn
    IF EXISTS (SELECT 1 FROM T_Tree WHERE TreeIdn IS NULL) THEN
        RAISE EXCEPTION 'Missing required field: tree_idn is mandatory for updates';
    END IF;

    -- Validate at least one field is being updated
    IF NOT EXISTS (SELECT 1 FROM T_Tree WHERE Lat IS NOT NULL OR Lng IS NOT NULL OR TreeTypeIdn IS NOT NULL) THEN
        RAISE EXCEPTION 'At least one field must be provided for update: latitude, longitude, or tree_type_idn';
    END IF;

    -- Validate geographic coordinates (if provided)
    IF EXISTS (SELECT 1 FROM T_Tree WHERE (Lat IS NOT NULL AND (Lat < -90 OR Lat > 90)) OR (Lng IS NOT NULL AND (Lng < -180 OR Lng > 180))) THEN
        RAISE EXCEPTION 'Invalid coordinates: Latitude must be between -90 and 90, Longitude between -180 and 180';
    END IF;

    -- Validate both latitude and longitude provided together
    IF EXISTS (SELECT 1 FROM T_Tree WHERE (Lat IS NULL AND Lng IS NOT NULL) OR (Lat IS NOT NULL AND Lng IS NULL)) THEN
        RAISE EXCEPTION 'Both latitude and longitude must be provided together';
    END IF;

    -- Validate TreeIdns exist
    SELECT string_agg(DISTINCT tt.TreeIdn::TEXT, ', ')
    INTO v_InvalidTreeIdns
    FROM T_Tree tt
        LEFT JOIN stp.U_Tree ut 
            ON tt.TreeIdn = ut.TreeIdn
    WHERE ut.TreeIdn IS NULL;

    IF v_InvalidTreeIdns IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid tree_idn(s): %. Trees do not exist.', v_InvalidTreeIdns;
    END IF;

    -- Validate TreeTypeIdn exists (if provided)
    SELECT string_agg(DISTINCT tt.TreeTypeIdn::TEXT, ', ')
    INTO v_InvalidTreeTypes
    FROM T_Tree tt
    	LEFT JOIN stp.U_TreeType ttype 
			ON tt.TreeTypeIdn = ttype.TreeTypeIdn
    WHERE tt.TreeTypeIdn IS NOT NULL 
    AND tt.TreeTypeIdn != 0 
    AND ttype.TreeTypeIdn IS NULL;

    IF v_InvalidTreeTypes IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid tree_type_idn(s): %. Tree types do not exist.', v_InvalidTreeTypes;
    END IF;

    -- Update existing trees (only location and type)
    UPDATE stp.U_Tree ut
    SET TreeLocation = 
		CASE 
            WHEN tt.Lat IS NOT NULL AND tt.Lng IS NOT NULL 
            THEN ST_SetSRID(ST_MakePoint(tt.Lng, tt.Lat), 4326)::geography
            ELSE ut.TreeLocation
        END,
        TreeTypeIdn = COALESCE(tt.TreeTypeIdn, ut.TreeTypeIdn)
    FROM T_Tree tt
    WHERE ut.TreeIdn = tt.TreeIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'UPDATE stp.U_Tree');

    -- Return updated trees
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'tree_idn', t.TreeIdn,
                'tree_id', t.TreeId,
                'pledge_idn', t.PledgeIdn,
                'credit_name', t.CreditName,
                'tree_type_idn', t.TreeTypeIdn,
                'latitude', ST_Y(t.TreeLocation::geometry)::FLOAT,
                'longitude', ST_X(t.TreeLocation::geometry)::FLOAT,
                'property_list', t.PropertyList
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Tree t
    WHERE t.TreeIdn IN (SELECT TreeIdn FROM T_Tree);
    CALL core.P_Step(p_RunLogIdn, null, 'prepare SaveTree json');
END;
$BODY$;

-- DeleteTree - Delete trees by PledgeIdns with validation
CREATE OR REPLACE PROCEDURE stp.P_DeleteTree(
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
    v_DeletedTreeIdns TEXT;
    v_TreesWithPhotos TEXT;
    v_ForceDelete BOOLEAN;
BEGIN
    -- Get force_delete flag (default false)
    v_ForceDelete := COALESCE((p_InputJson->>'force_delete')::BOOLEAN, false);
    CALL core.P_Step(p_RunLogIdn, NULL, 'ForceDelete: ' || v_ForceDelete);

    -- Create temp table for delete requests
    CREATE TEMP TABLE T_TreeDelete (
        PledgeIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON - expecting array of pledge_idn values
    INSERT INTO T_TreeDelete (PledgeIdn)
    SELECT (T->>'pledge_idn')::INT
    FROM jsonb_array_elements(p_InputJson->'pledges') AS T;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT T_TreeDelete');

    IF v_Rc = 0 THEN
        RAISE EXCEPTION 'No valid pledge_idn values provided for tree deletion';
    END IF;

    -- Check if any trees have photos (unless force delete)
    IF NOT v_ForceDelete 
	THEN
        SELECT string_agg(DISTINCT t.TreeIdn::TEXT, ', ')
        INTO v_TreesWithPhotos
        FROM T_TreeDelete ttd
	        JOIN stp.U_Tree t 
				ON ttd.PledgeIdn = t.PledgeIdn
	        JOIN stp.U_TreePhoto tp 
				ON t.TreeIdn = tp.TreeIdn;

        IF v_TreesWithPhotos IS NOT NULL THEN
            RAISE EXCEPTION 'Cannot delete trees with photos (TreeIdns: %). Use force_delete=true to delete trees and their photos.', v_TreesWithPhotos;
        END IF;
    ELSE
        -- Force delete: remove photos first
        DELETE FROM stp.U_TreePhoto tp
        USING T_TreeDelete ttd
	        JOIN stp.U_Tree t 
				ON ttd.PledgeIdn = t.PledgeIdn
        WHERE tp.TreeIdn = t.TreeIdn;
        GET DIAGNOSTICS v_Rc = ROW_COUNT;
        CALL core.P_Step(p_RunLogIdn, v_Rc, 'DELETE stp.U_TreePhoto (force)');

        -- Also delete from donor send log
        DELETE FROM stp.U_DonorSendLog dsl
        USING T_TreeDelete ttd
	        JOIN stp.U_Tree t 
				ON ttd.PledgeIdn = t.PledgeIdn
        WHERE dsl.TreeIdn = t.TreeIdn;
        GET DIAGNOSTICS v_Rc = ROW_COUNT;
        CALL core.P_Step(p_RunLogIdn, v_Rc, 'DELETE stp.U_DonorSendLog (force)');
    END IF;

    -- Capture TreeIdns being deleted
    SELECT string_agg(t.TreeIdn::TEXT, ',')
    INTO v_DeletedTreeIdns
    FROM T_TreeDelete ttd
        JOIN stp.U_Tree t 
            ON ttd.PledgeIdn = t.PledgeIdn;

    -- Delete trees for the specified pledges
    DELETE FROM stp.U_Tree t
    USING T_TreeDelete ttd
    WHERE t.PledgeIdn = ttd.PledgeIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'DELETE stp.U_Tree');

    -- Return result
    p_OutputJson := jsonb_build_object(
        'deleted_count', v_Rc,
        'deleted_tree_idns', COALESCE(v_DeletedTreeIdns, ''),
        'force_delete', v_ForceDelete
    );
    CALL core.P_Step(p_RunLogIdn, null, 'prepare DeleteTree json');
END;
$BODY$;

CALL core.P_DbApi (
    '{
        "db_api_name": "RegisterDbApi",	
        "request": {
            "records": [
                {
                    "db_api_name": "CreateTreeBulk",
                    "schema_name": "stp",
                    "handler_name": "P_CreateTreeBulk",
                    "property_list": {
                        "description": "Creates tree records in bulk for pledges in a project",
                        "version": "1.0",
                        "permissions": ["write"]
                    }
                },
                {
                    "db_api_name": "GetTree",
                    "schema_name": "stp",
                    "handler_name": "P_GetTree",
                    "property_list": {
                        "description": "Searches trees by pledge, project, donor, tree ID, or credit name pattern",
                        "version": "1.0",
                        "permissions": ["read"]
                    }
                },
                {
                    "db_api_name": "SaveTree",
                    "schema_name": "stp",
                    "handler_name": "P_SaveTree",
                    "property_list": {
                        "description": "Updates tree location and type information",
                        "version": "1.0",
                        "permissions": ["write"]
                    }
                },
                {
                    "db_api_name": "DeleteTree",
                    "schema_name": "stp",
                    "handler_name": "P_DeleteTree",
                    "property_list": {
                        "description": "Deletes trees by pledge IDN with optional force delete",
                        "version": "1.0",
                        "permissions": ["write"]
                    }
                }
            ]
        }
    }'::jsonb,
    null
);

-- End of 4_tree.sql
select * from stp.U_Tree;

-- Example 1: Create trees for a project (incremental mode - default)
CALL core.P_DbApi (
    '{
        "db_api_name": "CreateTreeBulk",	
        "request": {
            "project_idn": "1",
            "create_type": "Missing"
        }
    }'::jsonb,
    NULL
);

-- Example 2: Create trees for a project (clean mode - deletes existing first)
CALL core.P_DbApi (
    '{
        "db_api_name": "CreateTreeBulk",	
        "request": {
            "project_idn": "1",
            "create_type": "Clean"
        }
    }'::jsonb,
    NULL
);

-- Example 3: Get all trees for a specific pledge
CALL core.P_DbApi (
    '{
        "db_api_name": "GetTree",	
        "request": {
            "pledge_idn": "1"
        }
    }'::jsonb,
    NULL
);

-- Example 4: Get all trees for a specific project
CALL core.P_DbApi (
    '{
        "db_api_name": "GetTree",	
        "request": {
            "project_idn": "1"
        }
    }'::jsonb,
    NULL
);

-- Example 5: Get all trees for a specific donor
CALL core.P_DbApi (
    '{
        "db_api_name": "GetTree",	
        "request": {
            "donor_idn": "1"
        }
    }'::jsonb,
    NULL
);

-- Example 6: Search trees by tree ID pattern
CALL core.P_DbApi (
    '{
        "db_api_name": "GetTree",	
        "request": {
            "tree_id_pattern": "PRJ001"
        }
    }'::jsonb,
    NULL
);

-- Example 7: Search trees by credit name pattern
CALL core.P_DbApi (
    '{
        "db_api_name": "GetTree",	
        "request": {
            "credit_name_pattern": "Sharma"
        }
    }'::jsonb,
    NULL
);

-- Example 8: Update tree location (latitude and longitude)
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveTree",
        "request": [
            {
                "tree_idn": "1",
                "latitude": "19.0760",
                "longitude": "72.8777"
            },
            {
                "tree_idn": "2",
                "latitude": "23.0225",
                "longitude": "72.5714"
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 9: Update tree type
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveTree",
        "request": [
            {
                "tree_idn": "1",
                "tree_type_idn": "5"
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 10: Update both location and tree type
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveTree",
        "request": [
            {
                "tree_idn": "3",
                "latitude": "18.5204",
                "longitude": "73.8567",
                "tree_type_idn": "7"
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 11: Delete trees for a single pledge (will fail if photos exist)
CALL core.P_DbApi(
    '{
        "db_api_name": "DeleteTree",
        "request": {
            "pledges": [
	            {
	                "pledge_idn": "5"
	            }
	        ]
		}
    }'::jsonb,
    NULL
);

-- Example 12: Delete trees for multiple pledges
CALL core.P_DbApi(
    '{
        "db_api_name": "DeleteTree",
        "request": {
            "pledges": [
	            {
	                "pledge_idn": "6"
	            },
	            {
	                "pledge_idn": "7"
	            }
	        ]
		}
    }'::jsonb,
    NULL
);

-- Example 13: Force delete trees (including photos and donor send logs)
CALL core.P_DbApi(
    '{
        "db_api_name": "DeleteTree",
        "request": {
            "force_delete": true,
            "pledges": [
                {
                    "pledge_idn": "8"
                }
            ]
        }
    }'::jsonb,
    NULL
);

select * from stp.U_Tree;
select * from core.V_RL ORDER BY RunLogIdn DESC;
select * from core.V_RLS WHERE RunLogIdn=(select MAX(RunLogIdn) from core.U_RunLog) order by Idn;
