-- GetProject
-- SaveProject
-- DeleteProject
-- GetDonor (get donor information and all the pledges made by donor)
-- SaveDonor
-- DeleteDonor
-- MergeDonor
-- GetPledge
-- SavePledge
-- DeletePledge

-- DownloadProjectPlank

-- UploadPhotoInfo
-- SendDonorUpdate
-- ConfirmDonorUpdate

-- GetProject 
CREATE OR REPLACE PROCEDURE STP.P_GetProject(
    IN 		p_InputJson 	JSONB,
    INOUT 	p_OutputJson 	JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
	v_Rc INTEGER;
    v_ProjectPattern varchar(128);
BEGIN
	v_ProjectPattern = '%' || (p_InputJson->>'project_pattern') || '%';
	raise notice 'ProjectPattern: %',v_ProjectPattern;

	SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'project_id',ProjectId,
                'project_name',ProjectName,
                'TreeCntPledged',TreeCntPledged,
                'TreeCntPlanted',TreeCntPlanted,
                'latitude',Lat,
                'longitude',Lng
            )
        ),'[]'::jsonb
    )
	INTO p_OutputJson
	FROM 
		(SELECT 
		    ProjectId,
		    ProjectName,
		    TreeCntPledged,
		    TreeCntPlanted,
		    ST_Y(ProjectLocation::geometry)::FLOAT as Lat,
		    ST_X(ProjectLocation::geometry)::FLOAT as Lng
		FROM stp.U_Project
		WHERE (v_ProjectPattern IS NULL 
				OR ProjectId LIKE v_ProjectPattern 
				OR ProjectName LIKE v_ProjectPattern)
		);
END;
$BODY$;
-- SaveProject with Insert/Update and Duplicate Key Validation
CREATE OR REPLACE PROCEDURE STP.P_SaveProject(
    IN      p_InputJson     JSONB,
    INOUT   p_OutputJson    JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_Rc INTEGER;
    v_DuplicateProjectIds TEXT;
BEGIN
    -- Create temp table to hold input projects
    CREATE TEMP TABLE t_project (
        ProjectIdn      INT,
        ProjectId       VARCHAR(64),
        ProjectName     VARCHAR(128),
        TreeCntPledged  INT,
        TreeCntPlanted  INT,
        Lat             FLOAT,
        Lng             FLOAT
    ) ON COMMIT DROP;

    -- Parse input JSON array into temp table
    INSERT INTO t_project (ProjectIdn,ProjectId,ProjectName,TreeCntPledged,TreeCntPlanted,Lat,Lng)
    SELECT 
        NULLIF(T->>'project_idn','')::INT,
        T->>'project_id',
        T->>'project_name',
        COALESCE((T->>'tree_cnt_pledged')::INT,0),
        COALESCE((T->>'tree_cnt_planted')::INT,0),
        (T->>'latitude')::FLOAT,
        (T->>'longitude')::FLOAT
    FROM jsonb_array_elements(p_InputJson->'items') AS T;

    -- Validate: Check for duplicate ProjectId in existing records (excluding current record for updates)
    SELECT string_agg(DISTINCT tp.ProjectId,',')
    INTO v_DuplicateProjectIds
    FROM t_project tp
    	INNER JOIN stp.U_Project up 
     	   ON tp.ProjectId = up.ProjectId
     	   AND (tp.ProjectIdn IS NULL OR tp.ProjectIdn != up.ProjectIdn);

    -- If duplicates found,raise exception
    IF v_DuplicateProjectIds IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate ProjectId(s) found: %. ProjectId must be unique.',v_DuplicateProjectIds;
    END IF;

    -- Validate: Check for duplicate ProjectId within input batch
    SELECT string_agg(DISTINCT ProjectId,',')
    INTO v_DuplicateProjectIds
    FROM (
        SELECT ProjectId
        FROM t_project
        GROUP BY ProjectId
        HAVING COUNT(*) > 1
    ) dups;

    IF v_DuplicateProjectIds IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate ProjectId(s) in input batch: %. ProjectId must be unique.',v_DuplicateProjectIds;
    END IF;

    -- Update existing projects where ProjectIdn is specified
    UPDATE stp.U_Project up
    SET 
        ProjectId = tp.ProjectId,
        ProjectName = tp.ProjectName,
        TreeCntPledged = tp.TreeCntPledged,
        TreeCntPlanted = tp.TreeCntPlanted,
        ProjectLocation = ST_SetSRID(ST_MakePoint(tp.Lng,tp.Lat),4326)::geography,
        Ts = CURRENT_TIMESTAMP
    FROM t_project tp
    WHERE up.ProjectIdn = tp.ProjectIdn
    AND tp.ProjectIdn IS NOT NULL;

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    RAISE NOTICE 'Updated % project(s)',v_Rc;

    -- Insert new projects where ProjectIdn is not specified
    INSERT INTO stp.U_Project (ProjectId,ProjectName,TreeCntPledged,TreeCntPlanted,ProjectLocation,StartDt,PropertyList,UserId,Ts)
    SELECT 
        tp.ProjectId,
        tp.ProjectName,
        tp.TreeCntPledged,
        tp.TreeCntPlanted,
        ST_SetSRID(ST_MakePoint(tp.Lng,tp.Lat),4326)::geography,
        CURRENT_TIMESTAMP,
		'','',
        CURRENT_TIMESTAMP
    FROM t_project tp
    WHERE tp.ProjectIdn IS NULL;

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    RAISE NOTICE 'Inserted % project(s)',v_Rc;

    -- Return the saved projects (both updated and inserted)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'project_idn',up.ProjectIdn,
                'project_id',up.ProjectId,
                'project_name',up.ProjectName,
                'tree_cnt_pledged',up.TreeCntPledged,
                'tree_cnt_planted',up.TreeCntPlanted,
                'latitude',ST_Y(up.ProjectLocation::geometry)::FLOAT,
                'longitude',ST_X(up.ProjectLocation::geometry)::FLOAT
            )
        ),'[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Project up
    WHERE up.ProjectId IN (SELECT ProjectId FROM t_project);
END;
$BODY$;

--Example Usage:

-- Insert new projects (ProjectIdn is null or not provided)
CALL STP.P_SaveProject(
    '{
        "items": [
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

-- Update existing projects (ProjectIdn is provided)
CALL STP.P_SaveProject(
    '{
        "items": [
            {
                "project_idn": 1,
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
                "project_idn": 1,
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
