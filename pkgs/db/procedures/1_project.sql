-- 1_project.sql
-- GetProject
-- SearchProject
-- SaveProject
-- DeleteProject

-- Rename to SearchProject: GetProject - Searches by pattern matching on project name or project id
CREATE OR REPLACE PROCEDURE STP.P_GetProject(
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
    v_ProjectPattern VARCHAR(128);
BEGIN
    -- Extract and prepare search pattern
    v_ProjectPattern := '%' || COALESCE(p_InputJson->>'project_pattern', '') || '%';
    RAISE NOTICE 'ProjectPattern: %', v_ProjectPattern;

    -- Build result JSON
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'project_idn', ProjectIdn,
                'project_id', ProjectId,
                'project_name', ProjectName,
                'start_dt', StartDt,
                'tree_cnt_pledged', TreeCntPledged,
                'tree_cnt_planted', TreeCntPlanted,
                'latitude', ST_Y(ProjectLocation::geometry)::FLOAT,
                'longitude', ST_X(ProjectLocation::geometry)::FLOAT,
                'property_list', PropertyList
            ) ORDER BY ProjectId
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Project
    WHERE (p_InputJson->>'project_pattern' IS NULL 
           OR ProjectId LIKE v_ProjectPattern 
           OR ProjectName LIKE v_ProjectPattern);

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'query data');
END;
$BODY$;

-- SaveProject - Insert/Update projects with validation
CREATE OR REPLACE PROCEDURE STP.P_SaveProject(
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
    v_DuplicateProjectIds TEXT;
BEGIN
    -- Create temp table for input projects
    CREATE TEMP TABLE T_Project (
        ProjectIdn      INT,
        ProjectId       VARCHAR(64),
        ProjectName     VARCHAR(128),
        StartDt         DATE,
        TreeCntPledged  INT,
        TreeCntPlanted  INT,
        Lat             FLOAT,
        Lng             FLOAT,
        PropertyList    JSONB
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_Project (ProjectIdn, ProjectId, ProjectName, StartDt, TreeCntPledged, TreeCntPlanted, Lat, Lng, PropertyList)
    SELECT 
        NULLIF(T->>'project_idn', '')::INT,
        T->>'project_id',
        T->>'project_name',
        COALESCE(NULLIF(T->>'start_dt', '')::DATE, P_AnchorTs::DATE),
        COALESCE((T->>'tree_cnt_pledged')::INT, 0),
        COALESCE((T->>'tree_cnt_planted')::INT, 0),
        (T->>'latitude')::FLOAT,
        (T->>'longitude')::FLOAT,
        COALESCE(T->'property_list', '{}'::jsonb)
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT T_Project');

    -- Validate required fields
    IF EXISTS (SELECT 1 FROM T_Project WHERE ProjectId IS NULL OR ProjectName IS NULL) THEN
        RAISE EXCEPTION 'Missing required fields: project_id, project_name are mandatory';
    END IF;

    -- Validate geographic coordinates
    IF EXISTS (SELECT 1 FROM T_Project WHERE Lat < -90 OR Lat > 90 OR Lng < -180 OR Lng > 180) THEN
        RAISE EXCEPTION 'Invalid coordinates: Latitude must be between -90 and 90, Longitude between -180 and 180';
    END IF;

    -- Check for duplicate ProjectId within input batch
    SELECT string_agg(DISTINCT ProjectId, ', ')
    INTO v_DuplicateProjectIds
    FROM 
        (SELECT ProjectId
        FROM T_Project
        GROUP BY ProjectId
        HAVING COUNT(*) > 1
        ) dups;

    IF v_DuplicateProjectIds IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate ProjectId(s) in input batch: %. ProjectId must be unique.', v_DuplicateProjectIds;
    END IF;

    -- Check for duplicate ProjectId in existing records (excluding current record for updates)
    SELECT string_agg(DISTINCT tp.ProjectId, ', ')
    INTO v_DuplicateProjectIds
    FROM T_Project tp
        JOIN stp.U_Project up 
            ON tp.ProjectId = up.ProjectId
            AND (tp.ProjectIdn IS NULL OR tp.ProjectIdn != up.ProjectIdn);

    IF v_DuplicateProjectIds IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate ProjectId(s) already exist: %. ProjectId must be unique.', v_DuplicateProjectIds;
    END IF;

    -- Update existing projects
    UPDATE stp.U_Project up
    SET ProjectId = tp.ProjectId,
        ProjectName = tp.ProjectName,
        StartDt = tp.StartDt,
        TreeCntPledged = tp.TreeCntPledged,
        TreeCntPlanted = tp.TreeCntPlanted,
        ProjectLocation = ST_SetSRID(ST_MakePoint(tp.Lng, tp.Lat), 4326)::geography,
        PropertyList = tp.PropertyList,
        UserIdn = P_UserIdn,
        Ts = P_AnchorTs
    FROM T_Project tp
    WHERE up.ProjectIdn = tp.ProjectIdn
      AND tp.ProjectIdn IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'UPDATE stp.U_Project');

    -- Insert new projects
    INSERT INTO stp.U_Project (ProjectId, ProjectName, StartDt, TreeCntPledged, TreeCntPlanted, ProjectLocation, PropertyList, UserIdn, Ts)
    SELECT ProjectId,ProjectName,StartDt,TreeCntPledged,TreeCntPlanted,
        ST_SetSRID(ST_MakePoint(Lng, Lat), 4326)::geography,
        PropertyList,p_UserIdn,p_AnchorTs
	FROM T_Project
    WHERE ProjectIdn IS NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT stp.U_Project');

    -- Return saved projects
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'project_idn', ProjectIdn,
                'project_id', ProjectId,
                'project_name', ProjectName,
                'start_dt', StartDt,
                'tree_cnt_pledged', TreeCntPledged,
                'tree_cnt_planted', TreeCntPlanted,
                'latitude', ST_Y(ProjectLocation::geometry)::FLOAT,
                'longitude', ST_X(ProjectLocation::geometry)::FLOAT,
                'property_list', PropertyList
            ) ORDER BY ProjectId
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Project
    WHERE ProjectId IN (SELECT ProjectId FROM T_Project);
    CALL core.P_RunLogStep(p_RunLogIdn, null, 'build response json');
END;
$BODY$;

-- DeleteProject - Delete projects with validation
CREATE OR REPLACE PROCEDURE STP.P_DeleteProject(
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
    v_ProjectIds TEXT;
    v_DeletedProjectIdns TEXT;
BEGIN
    -- Create temp table for delete requests
    CREATE TEMP TABLE T_ProjectDelete (
        ProjectIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_ProjectDelete (ProjectIdn)
    SELECT (T->>'project_idn')::INT
    FROM jsonb_array_elements(p_InputJson) AS T
    WHERE T->>'project_idn' IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT T_ProjectDelete');
    IF v_Rc = 0 THEN
        RAISE EXCEPTION 'No valid project_idn values provided for deletion';
    END IF;

    -- Check for projects with existing pledges
    SELECT string_agg(DISTINCT up.ProjectId, ', ')
    INTO v_ProjectIds
    FROM T_ProjectDelete tpd
    	JOIN stp.U_Project up
     	   ON tpd.ProjectIdn=up.ProjectIdn
    	JOIN stp.U_Pledge p
     	   ON tpd.ProjectIdn=p.ProjectIdn;

    IF v_ProjectIds IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot delete project(s) with existing pledges: %', v_ProjectIds;
    END IF;

    -- Capture ProjectIdns being deleted
    SELECT string_agg(ProjectIdn::TEXT, ',')
    INTO v_DeletedProjectIdns
    FROM T_ProjectDelete;

    -- Delete projects
    DELETE FROM stp.U_Project up
    USING T_ProjectDelete tpd
    WHERE up.ProjectIdn = tpd.ProjectIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'DELETE stp.U_Project');

    -- Return result
    p_OutputJson := jsonb_build_object(
        'deleted_count', v_Rc,
        'deleted_project_idns', COALESCE(v_DeletedProjectIdns, '')
    );
END;
$BODY$;

-- End of 1_project.sql
/*
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
*/