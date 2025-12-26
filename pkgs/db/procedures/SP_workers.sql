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
    IN      P_AnchorTs      TIMESTAMP,
    IN      P_UserIdn       INT,
    IN      P_RunLogIdn     INT,
    IN 		p_InputJson 	JSONB,
    INOUT 	p_OutputJson 	JSONB
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
	v_Rc INTEGER;
    v_ProjectPattern varchar(128);
BEGIN
	v_ProjectPattern='%' || (p_InputJson->>'project_pattern') || '%';
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
    IN      P_AnchorTs      TIMESTAMP,
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
    -- Create temp table to hold input projects
    CREATE TEMP TABLE T_Project (
        ProjectIdn      INT,
        ProjectId       VARCHAR(64),
        ProjectName     VARCHAR(128),
        TreeCntPledged  INT,
        TreeCntPlanted  INT,
        Lat             FLOAT,
        Lng             FLOAT
    ) ON COMMIT DROP;

    -- Parse input JSON array into temp table
    INSERT INTO T_Project (ProjectIdn,ProjectId,ProjectName,TreeCntPledged,TreeCntPlanted,Lat,Lng)
    SELECT 
        NULLIF(T->>'project_idn','')::INT,
        T->>'project_id',
        T->>'project_name',
        COALESCE((T->>'tree_cnt_pledged')::INT,0),
        COALESCE((T->>'tree_cnt_planted')::INT,0),
        (T->>'latitude')::FLOAT,
        (T->>'longitude')::FLOAT
    FROM jsonb_array_elements(p_InputJson) AS T;
    CALL core.P_RunLogStep(p_RunLogIdn, NULL, 'INSERT T_Project');

    -- Validate: Check for duplicate ProjectId within input batch
    SELECT string_agg(DISTINCT ProjectId,',')
    INTO v_DuplicateProjectIds
    FROM 
        (SELECT ProjectId
        FROM T_Project
        GROUP BY ProjectId
        HAVING COUNT(*)>1
        ) dups;

    IF v_DuplicateProjectIds IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate ProjectId(s) in input batch: %. ProjectId must be unique.',v_DuplicateProjectIds;
    END IF;

    -- Validate: Check for duplicate ProjectId in existing records (excluding current record for updates)
    SELECT string_agg(DISTINCT tp.ProjectId,',')
    INTO v_DuplicateProjectIds
    FROM T_Project tp
    	INNER JOIN stp.U_Project up 
     	   ON tp.ProjectId=up.ProjectId
     	   AND (tp.ProjectIdn IS NULL OR tp.ProjectIdn!=up.ProjectIdn);

    -- If duplicates found,raise exception
    IF v_DuplicateProjectIds IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate ProjectId(s) found: %. ProjectId must be unique.',v_DuplicateProjectIds;
    END IF;

    -- Update existing projects where ProjectIdn is specified
    UPDATE stp.U_Project up
    SET ProjectId=tp.ProjectId,
        ProjectName=tp.ProjectName,
        TreeCntPledged=tp.TreeCntPledged,
        TreeCntPlanted=tp.TreeCntPlanted,
        ProjectLocation=ST_SetSRID(ST_MakePoint(tp.Lng,tp.Lat),4326)::geography,
        Ts=P_AnchorTs
    FROM T_Project tp
    WHERE up.ProjectIdn=tp.ProjectIdn
    AND tp.ProjectIdn IS NOT NULL;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'UPDATE stp.U_Project');

    -- Insert new projects where ProjectIdn is not specified
    INSERT INTO stp.U_Project (ProjectId,ProjectName,TreeCntPledged,TreeCntPlanted,ProjectLocation,StartDt,PropertyList,UserId,Ts)
    SELECT 
        tp.ProjectId,
        tp.ProjectName,
        tp.TreeCntPledged,
        tp.TreeCntPlanted,
        ST_SetSRID(ST_MakePoint(tp.Lng,tp.Lat),4326)::geography,
        P_AnchorTs,
		'','',
        P_AnchorTs
    FROM T_Project tp
    WHERE tp.ProjectIdn IS NULL;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'INSERT stp.U_Project');

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
    WHERE up.ProjectId IN (SELECT ProjectId FROM T_project);
END;
$BODY$;
