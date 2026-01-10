-- GetProject
-- SaveProject
-- DeleteProject
-- GetDonor 
-- SaveDonor
-- DeleteDonor
-- MergeDonor
-- GetPledge
-- SavePledge
-- DeletePledge
-- CreateTreeBulk
-- GetTree
-- SaveTree
-- DeleteTree
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
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'INSERT T_Project');

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
    	JOIN stp.U_Project up 
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
-- DeleteProject
CREATE OR REPLACE PROCEDURE STP.P_DeleteProject(
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
	v_ProjectIds TEXT;
    v_DeletedProjectIdns TEXT;
BEGIN
    -- Create temp table to hold input project identifiers
    CREATE TEMP TABLE T_ProjectDelete (
        ProjectIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON array into temp table
    INSERT INTO T_ProjectDelete (ProjectIdn)
    SELECT (T->>'project_idn')::INT
    FROM jsonb_array_elements(p_InputJson) AS T
    WHERE T->>'project_idn' IS NOT NULL;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'INSERT T_ProjectDelete');

    -- Validate: Check for Projects with existing pledges 
    SELECT string_agg(DISTINCT up.ProjectId,',')
    INTO v_ProjectIds
    FROM T_ProjectDelete tpd
    	JOIN stp.U_Project up
     	   ON tpd.ProjectIdn=up.ProjectIdn
    	JOIN stp.U_Pledge up2
     	   ON tpd.ProjectIdn=up2.ProjectIdn;

    -- If duplicates found,raise exception
    IF v_DuplicateProjectIds IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid ProjectId(s): %. ProjectId must not have pledges.',v_ProjectIds;
    END IF;

    -- Capture the ProjectIdns that will be deleted for output
    SELECT string_agg(ProjectIdn::TEXT,',')
    INTO v_DeletedProjectIdns
    FROM T_ProjectDelete;

    -- Delete projects
    DELETE FROM stp.U_Project up
    USING T_ProjectDelete tpd
    WHERE up.ProjectIdn=tpd.ProjectIdn;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'DELETE stp.U_Project');

    -- Return deleted project identifiers
    p_OutputJson:=jsonb_build_object(
        'deleted_count',v_Rc,
        'deleted_project_idns',COALESCE(v_DeletedProjectIdns,'')
    );
END;
$BODY$;
-- GetDonor - Searches by pattern matching on donor name, mobile number, or email
CREATE OR REPLACE PROCEDURE STP.P_GetDonor(
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
    v_DonorPattern varchar(128);
BEGIN
    v_DonorPattern='%' || (p_InputJson->>'donor_pattern') || '%';
    raise notice 'DonorPattern: %',v_DonorPattern;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'donor_idn',DonorIdn,
                'donor_name',DonorName,
                'mobile_number',MobileNumber,
                'city',City,
                'email_addr',EmailAddr,
                'country',Country,
                'state',State,
                'birth_dt',BirthDt
            )
        ),'[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Donor
    WHERE (v_DonorPattern IS NULL 
            OR DonorName LIKE v_DonorPattern 
            OR MobileNumber LIKE v_DonorPattern
            OR EmailAddr LIKE v_DonorPattern);
END;
$BODY$;

-- SaveDonor with Insert/Update and Duplicate Key Validation
CREATE OR REPLACE PROCEDURE STP.P_SaveDonor(
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
    v_DuplicateMobileNumbers TEXT;
BEGIN
    -- Create temp table to hold input donors
    CREATE TEMP TABLE T_Donor (
        DonorIdn        INT,
        DonorName       VARCHAR(128),
        MobileNumber    VARCHAR(64),
        City            VARCHAR(64),
        EmailAddr       VARCHAR(64),
        Country         VARCHAR(64),
        State           VARCHAR(64),
        BirthDt         DATE
    ) ON COMMIT DROP;

    -- Parse input JSON array into temp table
    INSERT INTO T_Donor (DonorIdn,DonorName,MobileNumber,City,EmailAddr,Country,State,BirthDt)
    SELECT 
        NULLIF(T->>'donor_idn','')::INT,
        T->>'donor_name',
        T->>'mobile_number',
        T->>'city',
        T->>'email_addr',
        T->>'country',
        T->>'state',
        NULLIF(T->>'birth_dt','')::DATE
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'INSERT T_Donor');

    -- Validate: Check for duplicate MobileNumber within input batch
    SELECT string_agg(DISTINCT MobileNumber,',')
    INTO v_DuplicateMobileNumbers
    FROM 
        (SELECT MobileNumber
        FROM T_Donor
        GROUP BY MobileNumber
        HAVING COUNT(*)>1
        ) dups;

    IF v_DuplicateMobileNumbers IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate MobileNumber(s) in input batch: %. MobileNumber must be unique.',v_DuplicateMobileNumbers;
    END IF;

    -- Validate: Check for duplicate MobileNumber in existing records (excluding current record for updates)
    SELECT string_agg(DISTINCT td.MobileNumber,',')
    INTO v_DuplicateMobileNumbers
    FROM T_Donor td
        JOIN stp.U_Donor ud 
           ON td.MobileNumber=ud.MobileNumber
           AND (td.DonorIdn IS NULL OR td.DonorIdn!=ud.DonorIdn);

    -- If duplicates found,raise exception
    IF v_DuplicateMobileNumbers IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate MobileNumber(s) found: %. MobileNumber must be unique.',v_DuplicateMobileNumbers;
    END IF;

    -- Update existing donors where DonorIdn is specified
    UPDATE stp.U_Donor ud
    SET DonorName=td.DonorName,
        MobileNumber=td.MobileNumber,
        City=td.City,
        EmailAddr=td.EmailAddr,
        Country=td.Country,
        State=td.State,
        BirthDt=td.BirthDt,
        Ts=P_AnchorTs
    FROM T_Donor td
    WHERE ud.DonorIdn=td.DonorIdn
    AND td.DonorIdn IS NOT NULL;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'UPDATE stp.U_Donor');

    -- Insert new donors where DonorIdn is not specified
    INSERT INTO stp.U_Donor (DonorName,MobileNumber,City,EmailAddr,Country,State,BirthDt,PropertyList,UserIdn,Ts)
    SELECT 
        td.DonorName,
        td.MobileNumber,
        td.City,
        td.EmailAddr,
        td.Country,
        td.State,
        td.BirthDt,
        '',
        P_UserIdn,
        P_AnchorTs
    FROM T_Donor td
    WHERE td.DonorIdn IS NULL;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'INSERT stp.U_Donor');

    -- Return the saved donors (both updated and inserted)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'donor_idn',ud.DonorIdn,
                'donor_name',ud.DonorName,
                'mobile_number',ud.MobileNumber,
                'city',ud.City,
                'email_addr',ud.EmailAddr,
                'country',ud.Country,
                'state',ud.State,
                'birth_dt',ud.BirthDt
            )
        ),'[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Donor ud
    WHERE ud.MobileNumber IN (SELECT MobileNumber FROM T_Donor);
END;
$BODY$;

-- DeleteDonor - Deletes by DonorIdn and returns count and list of deleted identifiers
CREATE OR REPLACE PROCEDURE STP.P_DeleteDonor(
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
	v_DonorIdns TEXT;
    v_DeletedDonorIdns TEXT;
BEGIN
    -- Create temp table to hold input donor identifiers
    CREATE TEMP TABLE T_DonorDelete (
        DonorIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON array into temp table
    INSERT INTO T_DonorDelete (DonorIdn)
    SELECT (T->>'donor_idn')::INT
    FROM jsonb_array_elements(p_InputJson) AS T
    WHERE T->>'donor_idn' IS NOT NULL;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'INSERT T_DonorDelete');

    -- Validate: Check for Projects with existing pledges 
    SELECT string_agg(DISTINCT tdd.DonorIdn,',')
    INTO v_DonorIdns
    FROM T_DonorDelete tdd
    	JOIN stp.U_Pledge up
     	   ON tdd.DonorIdn=up.DonorIdn;

    -- If duplicates found,raise exception
    IF v_DonorIdns IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid DonorIdn(s): %. Donor must not have pledges.',v_DonorIdns;
    END IF;

    -- Capture the DonorIdns that will be deleted for output
    SELECT string_agg(DonorIdn::TEXT,',')
    INTO v_DeletedDonorIdns
    FROM T_DonorDelete;

    -- Delete donors
    DELETE FROM stp.U_Donor ud
    USING T_DonorDelete tdd
    WHERE ud.DonorIdn=tdd.DonorIdn;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'DELETE stp.U_Donor');

    -- Return deleted donor identifiers
    p_OutputJson:=jsonb_build_object(
        'deleted_count',v_Rc,
        'deleted_donor_idns',COALESCE(v_DeletedDonorIdns,'')
    );
END;
$BODY$;

-- GetPledge (search by DonorIdn or ProjectIdn)
-- GetPledge (search by DonorIdn or ProjectIdn)
CREATE OR REPLACE PROCEDURE STP.P_GetPledge(
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
    v_DonorIdn INT;
    v_ProjectIdn INT;
BEGIN
    v_DonorIdn:=NULLIF(p_InputJson->>'donor_idn','')::INT;
    v_ProjectIdn:=NULLIF(p_InputJson->>'project_idn','')::INT;
    
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'pledge_idn',PledgeIdn,
                'project_idn',ProjectIdn,
                'donor_idn',DonorIdn,
                'pledge_ts',PledgeTs,
                'tree_cnt_pledged',TreeCntPledged,
                'tree_cnt_planted',TreeCntPlanted,
                'pledge_credit',PledgeCredit
            )
        ),'[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Pledge
    WHERE (v_DonorIdn IS NULL OR DonorIdn=v_DonorIdn)
      AND (v_ProjectIdn IS NULL OR ProjectIdn=v_ProjectIdn);
END;
$BODY$;

-- SavePledge with Insert/Update and Tree Creation
CREATE OR REPLACE PROCEDURE STP.P_SavePledge(
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
BEGIN
    -- Create temp table to hold input pledges
    CREATE TEMP TABLE T_Pledge (
        PledgeIdn       INT,
        ProjectIdn      INT,
        DonorIdn        INT,
        PledgeTs        TIMESTAMP,
        TreeCntPledged  INT,
        TreeCntPlanted  INT,
        PledgeCredit    JSONB
    ) ON COMMIT DROP;

    -- Parse input JSON array into temp table
    INSERT INTO T_Pledge (PledgeIdn,ProjectIdn,DonorIdn,PledgeTs,TreeCntPledged,TreeCntPlanted,PledgeCredit)
    SELECT
        NULLIF(T->>'pledge_idn','')::INT,
        (T->>'project_idn')::INT,
        (T->>'donor_idn')::INT,
        COALESCE(NULLIF(T->>'pledge_ts','')::TIMESTAMP,P_AnchorTs),
        COALESCE((T->>'tree_cnt_pledged')::INT,0),
        COALESCE((T->>'tree_cnt_planted')::INT,0),
        (T->'pledge_credit') AS PledgeCredit
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'INSERT T_Pledge');

    -- Update existing pledges where PledgeIdn is specified
    UPDATE stp.U_Pledge up
    SET ProjectIdn=tp.ProjectIdn,
        DonorIdn=tp.DonorIdn,
        PledgeTs=tp.PledgeTs,
        TreeCntPledged=tp.TreeCntPledged,
        TreeCntPlanted=tp.TreeCntPlanted,
        PledgeCredit=tp.PledgeCredit
    FROM T_Pledge tp
    WHERE up.PledgeIdn=tp.PledgeIdn
    AND tp.PledgeIdn IS NOT NULL;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'UPDATE stp.U_Pledge');

    -- Insert new pledges where PledgeIdn is not specified
    INSERT INTO stp.U_Pledge (ProjectIdn,DonorIdn,PledgeTs,TreeCntPledged,TreeCntPlanted,PledgeCredit,PropertyList,UserIdn)
    SELECT
        tp.ProjectIdn,
        tp.DonorIdn,
        tp.PledgeTs,
        tp.TreeCntPledged,
        tp.TreeCntPlanted,
        tp.PledgeCredit,
        '',
        P_UserIdn
    FROM T_Pledge tp
    WHERE tp.PledgeIdn IS NULL;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'INSERT stp.U_Pledge');

    -- Return the saved pledges (both updated and inserted)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'pledge_idn',up.PledgeIdn,
                'project_idn',up.ProjectIdn,
                'donor_idn',up.DonorIdn,
                'pledge_ts',up.PledgeTs,
                'tree_cnt_pledged',up.TreeCntPledged,
                'tree_cnt_planted',up.TreeCntPlanted,
                'pledge_credit',up.PledgeCredit
            )
        ),'[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Pledge up
    WHERE (up.ProjectIdn,up.DonorIdn) IN (SELECT ProjectIdn,DonorIdn FROM T_Pledge);
END;
$BODY$;
-- DeletePledge - Deletes by PledgeIdn and returns count and list of deleted identifiers
CREATE OR REPLACE PROCEDURE STP.P_DeletePledge(
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
    v_DeletedPledgeIdns TEXT;
BEGIN
    -- Get CreateType from input
    CALL core.P_RunLogStep(p_RunLogIdn,NULL,'CreateType: ' || v_CreateType);

    -- Create temp table to hold input pledge identifiers
    CREATE TEMP TABLE T_PledgeDelete (
        PledgeIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON array into temp table
    INSERT INTO T_PledgeDelete (PledgeIdn)
    SELECT (T->>'pledge_idn')::INT
    FROM jsonb_array_elements(p_InputJson) AS T
    WHERE T->>'pledge_idn' IS NOT NULL;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'INSERT T_PledgeDelete');

    -- Capture the PledgeIdns that will be deleted for output
    SELECT string_agg(PledgeIdn::TEXT,',')
    INTO v_DeletedPledgeIdns
    FROM T_PledgeDelete;

    -- Handle Clean option
    IF v_CreateType='Clean' THEN
        -- Check if any trees have photos
        IF EXISTS
            (SELECT 1
            FROM stp.U_Pledge p
                JOIN stp.U_Tree t
                    ON p.PledgeIdn=t.PledgeIdn
                JOIN stp.U_TreePhoto AS tp
                    ON t.TreeIdn=tp.TreeIdn
            WHERE p.ProjectIdn=v_ProjectIdn)
        THEN
            RAISE EXCEPTION 'Tree cannot be deleted as we have records in U_TreePhoto';
        END IF;

	    -- Delete pledged trees
	    DELETE FROM stp.U_Tree ut
	    USING T_PledgeDelete tpd
	    WHERE ut.PledgeIdn=tpd.PledgeIdn;
	    GET DIAGNOSTICS v_Rc=ROW_COUNT;
	    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'DELETE stp.U_Tree');
	END IF;

    -- Delete pledges
    DELETE FROM stp.U_Pledge up
    USING T_PledgeDelete tpd
    WHERE up.PledgeIdn=tpd.PledgeIdn;
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'DELETE stp.U_Pledge');

    -- Return deleted pledge identifiers
    p_OutputJson:=jsonb_build_object(
        'deleted_count',v_Rc,
        'deleted_pledge_idns',COALESCE(v_DeletedPledgeIdns,'')
    );
END;
$BODY$;

-- PopulateTree - Create trees for pledges in a given project
CREATE OR REPLACE PROCEDURE STP.P_CreateTreeBulk(
    IN      P_AnchorTs      TIMESTAMP,
    IN      P_UserIdn       INT,
    IN      P_RunLogIdn     INT,
    IN      p_InputJson     JSONB,
    INOUT   p_OutputJson    JSONB
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_CreateType		VARCHAR(32);	-- Missing (Default), Clean
    v_MaxTreeNum		INT;
    v_ProjectId			VARCHAR(64);
    v_ProjectIdn		INT;
    v_Rc 				INTEGER;
BEGIN
    -- Get ProjectIdn from input (moved to beginning)
    v_ProjectIdn := (p_InputJson->>'project_idn')::INT;
    IF v_ProjectIdn IS NULL THEN
        RAISE EXCEPTION 'project_idn is required';
    END IF;
    CALL core.P_RunLogStep(p_RunLogIdn,NULL,'ProjectIdn: ' || v_ProjectIdn);

    -- Get CreateType from input
    v_CreateType := COALESCE(p_InputJson->>'create_type','Missing');
    CALL core.P_RunLogStep(p_RunLogIdn,NULL,'CreateType: ' || v_CreateType);

    -- Get ProjectId
    SELECT ProjectId
    INTO v_ProjectId
    FROM stp.U_Project
    WHERE ProjectIdn=v_ProjectIdn;
    IF v_ProjectId IS NULL THEN
        RAISE EXCEPTION 'Project not found for ProjectIdn: %',v_ProjectIdn;
    END IF;
    CALL core.P_RunLogStep(p_RunLogIdn,NULL,'Found Project: ' || v_ProjectId);

    -- Handle Clean option
    IF v_CreateType='Clean' THEN
        -- Check if any trees have photos
        IF EXISTS
            (SELECT 1
            FROM stp.U_Pledge p
                JOIN stp.U_Tree t
                    ON p.PledgeIdn=t.PledgeIdn
                JOIN stp.U_TreePhoto AS tp
                    ON t.TreeIdn=tp.TreeIdn
            WHERE p.ProjectIdn=v_ProjectIdn)
        THEN
            RAISE EXCEPTION 'Tree cannot be deleted as we have records in U_TreePhoto';
        END IF;

        -- Delete existing trees for this project
        DELETE FROM stp.U_Tree t
        USING stp.U_Pledge p
        WHERE t.PledgeIdn=p.PledgeIdn
          AND p.ProjectIdn=v_ProjectIdn;
        GET DIAGNOSTICS v_Rc=ROW_COUNT;
        CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'DELETE stp.U_Tree');
    END IF;

    -- Get the current max tree number for this project
    SELECT COALESCE(MAX(SUBSTRING(t.TreeId FROM LENGTH(v_ProjectId)+1)::INT),0)
    INTO v_MaxTreeNum
    FROM stp.U_Pledge p
        JOIN stp.U_Tree t
            ON p.PledgeIdn=t.PledgeIdn
    WHERE p.ProjectIdn=v_ProjectIdn;

    -- Create tree records for project pledges not already processed
    INSERT INTO stp.U_Tree (TreeLocation,TreeTypeIdn,PledgeIdn,CreditName,TreeId,PropertyList)
    SELECT 
        ST_SetSRID(ST_MakePoint(v_Lng,v_Lat),4326)::geography,
        0,
        t.PledgeIdn,
        pc->>'credit_name',
        v_ProjectId || (v_MaxTreeNum + row_number() OVER (ORDER BY t.DonorIdn,t.PledgeIdn,gs.n))::TEXT,
        ''
    FROM
        (SELECT p.PledgeIdn,p.DonorIdn,p.TreeCntPledged,p.PledgeCredit
        FROM stp.U_Pledge p
            LEFT JOIN stp.U_Tree t
                ON p.PledgeIdn=t.PledgeIdn
        WHERE p.ProjectIdn=v_ProjectIdn
          AND t.TreeIdn IS NULL
        ) AS t
        CROSS JOIN LATERAL jsonb_array_elements(t.PledgeCredit) AS pc
        CROSS JOIN LATERAL generate_series(1,(pc->>'tree_cnt')::INT) AS gs(n);
    GET DIAGNOSTICS v_Rc=ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'INSERT stp.U_Tree');

    -- Return summary
    p_OutputJson := jsonb_build_object(
        'project_idn',v_ProjectIdn,
        'project_id',v_ProjectId,
        'trees_created',v_Rc
    );
    CALL core.P_RunLogStep(p_RunLogIdn,v_Rc,'Trees created for ProjectIdn: ' || v_ProjectIdn);
END;
$BODY$;