-- 1_project.sql
-- GetProject
-- SearchProject
-- SaveProject
-- DeleteProject

-- 2_donor.sql
-- GetDonor
-- SearchDonor
-- SaveDonor
-- DeleteDonor
-- MergeDonor

-- 3_pledge.sql
-- SearchPledge
-- SavePledge
-- DeletePledge

-- 4_tree.sql
-- CreateTreeBulk
-- GetTree
-- SearchTree
-- SaveTree
-- DeleteTree

-- 5_photo.sql
-- UploadPhotoInfo
-- GetTreePhotos

-- 6_donorupdate.sql
-- GetDonorUpdate
-- PostDonorUpdate

-- 7_provider.sql
-- GetProvider
-- SaveProvider
-- DeleteProvider

-- Rename to SearchProject: GetProject - Searches by pattern matching on project name or project id
CREATE OR REPLACE PROCEDURE STP.P_GetProject(
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
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Project
    WHERE (p_InputJson->>'project_pattern' IS NULL 
           OR ProjectId LIKE v_ProjectPattern 
           OR ProjectName LIKE v_ProjectPattern)
    ORDER BY ProjectIdn;

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'SELECT Projects');
END;
$BODY$;

-- SaveProject - Insert/Update projects with validation
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
        PropertyList    VARCHAR(256)
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
        COALESCE(T->>'property_list', '{}')
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
    SELECT 
        tp.ProjectId,
        tp.ProjectName,
        tp.StartDt,
        tp.TreeCntPledged,
        tp.TreeCntPlanted,
        ST_SetSRID(ST_MakePoint(tp.Lng, tp.Lat), 4326)::geography,
        tp.PropertyList,
        P_UserIdn,
        P_AnchorTs
    FROM T_Project tp
    WHERE tp.ProjectIdn IS NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT stp.U_Project');

    -- Return saved projects
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'project_idn', up.ProjectIdn,
                'project_id', up.ProjectId,
                'project_name', up.ProjectName,
                'start_dt', up.StartDt,
                'tree_cnt_pledged', up.TreeCntPledged,
                'tree_cnt_planted', up.TreeCntPlanted,
                'latitude', ST_Y(up.ProjectLocation::geometry)::FLOAT,
                'longitude', ST_X(up.ProjectLocation::geometry)::FLOAT,
                'property_list', up.PropertyList
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Project up
    WHERE up.ProjectId IN (SELECT ProjectId FROM T_Project);
END;
$BODY$;

-- DeleteProject - Delete projects with validation
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

-- =====================================================================
-- DONOR PROCEDURES
-- =====================================================================
-- GetDonor - Search donors by pattern
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
    v_DonorPattern VARCHAR(128);
BEGIN
    -- Extract and prepare search pattern
    v_DonorPattern := '%' || COALESCE(p_InputJson->>'donor_pattern', '') || '%';
    RAISE NOTICE 'DonorPattern: %', v_DonorPattern;

    -- Build result JSON
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'donor_idn', DonorIdn,
                'donor_name', DonorName,
                'mobile_number', MobileNumber,
                'city', City,
                'email_addr', EmailAddr,
                'country', Country,
                'state', State,
                'birth_dt', BirthDt,
                'property_list', PropertyList
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Donor
    WHERE (v_DonorPattern IS NULL 
           OR DonorName LIKE v_DonorPattern 
           OR MobileNumber LIKE v_DonorPattern
           OR EmailAddr LIKE v_DonorPattern)
    ORDER BY DonorName, MobileNumber;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'SELECT Donors');
END;
$BODY$;

-- SaveDonor - Insert/Update donors with validation
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
    -- Create temp table for input donors
    CREATE TEMP TABLE T_Donor (
        DonorIdn        INT,
        DonorName       VARCHAR(128),
        MobileNumber    VARCHAR(64),
        City            VARCHAR(64),
        EmailAddr       VARCHAR(64),
        Country         VARCHAR(64),
        State           VARCHAR(64),
        BirthDt         DATE,
        PropertyList    VARCHAR(256)
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_Donor (DonorIdn, DonorName, MobileNumber, City, EmailAddr, Country, State, BirthDt, PropertyList)
    SELECT 
        NULLIF(T->>'donor_idn', '')::INT,
        T->>'donor_name',
        T->>'mobile_number',
        T->>'city',
        T->>'email_addr',
        T->>'country',
        T->>'state',
        NULLIF(T->>'birth_dt', '')::DATE,
        COALESCE(T->>'property_list', '{}')
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT T_Donor');

    -- Validate required fields
    IF EXISTS (SELECT 1 FROM T_Donor WHERE DonorName IS NULL OR MobileNumber IS NULL OR City IS NULL OR Country IS NULL OR State IS NULL) THEN
        RAISE EXCEPTION 'Missing required fields: donor_name, mobile_number, city, country, state are mandatory';
    END IF;

    -- Check for duplicate MobileNumber within input batch
    SELECT string_agg(DISTINCT MobileNumber, ', ')
    INTO v_DuplicateMobileNumbers
    FROM 
        (SELECT MobileNumber
        FROM T_Donor
        GROUP BY MobileNumber
        HAVING COUNT(*) > 1
    ) dups;

    IF v_DuplicateMobileNumbers IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate MobileNumber(s) in input batch: %. MobileNumber must be unique.', v_DuplicateMobileNumbers;
    END IF;

    -- Check for duplicate MobileNumber in existing records (excluding current record for updates)
    SELECT string_agg(DISTINCT td.MobileNumber, ', ')
    INTO v_DuplicateMobileNumbers
    FROM T_Donor td
        JOIN stp.U_Donor ud 
            ON td.MobileNumber = ud.MobileNumber
            AND (td.DonorIdn IS NULL OR td.DonorIdn != ud.DonorIdn);

    IF v_DuplicateMobileNumbers IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate MobileNumber(s) already exist: %. MobileNumber must be unique.', v_DuplicateMobileNumbers;
    END IF;

    -- Update existing donors
    UPDATE stp.U_Donor ud
    SET DonorName = td.DonorName,
        MobileNumber = td.MobileNumber,
        City = td.City,
        EmailAddr = td.EmailAddr,
        Country = td.Country,
        State = td.State,
        BirthDt = td.BirthDt,
        PropertyList = td.PropertyList,
        UserIdn = P_UserIdn,
        Ts = P_AnchorTs
    FROM T_Donor td
    WHERE ud.DonorIdn = td.DonorIdn
      AND td.DonorIdn IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'UPDATE stp.U_Donor');

    -- Insert new donors
    INSERT INTO stp.U_Donor (DonorName, MobileNumber, City, EmailAddr, Country, State, BirthDt, PropertyList, UserIdn, Ts)
    SELECT 
        td.DonorName,
        td.MobileNumber,
        td.City,
        td.EmailAddr,
        td.Country,
        td.State,
        td.BirthDt,
        td.PropertyList,
        P_UserIdn,
        P_AnchorTs
    FROM T_Donor td
    WHERE td.DonorIdn IS NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT stp.U_Donor');

    -- Return saved donors
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'donor_idn', ud.DonorIdn,
                'donor_name', ud.DonorName,
                'mobile_number', ud.MobileNumber,
                'city', ud.City,
                'email_addr', ud.EmailAddr,
                'country', ud.Country,
                'state', ud.State,
                'birth_dt', ud.BirthDt,
                'property_list', ud.PropertyList
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Donor ud
    WHERE ud.MobileNumber IN (SELECT MobileNumber FROM T_Donor);
END;
$BODY$;

-- DeleteDonor - Delete donors with validation
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
    v_DonorNames TEXT;
    v_DeletedDonorIdns TEXT;
BEGIN
    -- Create temp table for delete requests
    CREATE TEMP TABLE T_DonorDelete (
        DonorIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_DonorDelete (DonorIdn)
    SELECT (T->>'donor_idn')::INT
    FROM jsonb_array_elements(p_InputJson) AS T
    WHERE T->>'donor_idn' IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT T_DonorDelete');

    IF v_Rc = 0 THEN
        RAISE EXCEPTION 'No valid donor_idn values provided for deletion';
    END IF;

    -- Check for donors with existing pledges
    SELECT string_agg(DISTINCT tdd.DonorIdn,',')
    INTO v_DonorNames
    FROM T_DonorDelete tdd
    	JOIN stp.U_Pledge up
     	   ON tdd.DonorIdn=up.DonorIdn;

    IF v_DonorNames IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot delete donor(s) with existing pledges: %', v_DonorNames;
    END IF;

    -- Capture DonorIdns being deleted
    SELECT string_agg(DonorIdn::TEXT, ',')
    INTO v_DeletedDonorIdns
    FROM T_DonorDelete;

    -- Delete donors
    DELETE FROM stp.U_Donor ud
    USING T_DonorDelete tdd
    WHERE ud.DonorIdn = tdd.DonorIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'DELETE stp.U_Donor');

    -- Return result
    p_OutputJson := jsonb_build_object(
        'deleted_count', v_Rc,
        'deleted_donor_idns', COALESCE(v_DeletedDonorIdns, '')
    );
END;
$BODY$;

-- =====================================================================
-- PLEDGE PROCEDURES
-- =====================================================================

-- GetPledge - Search pledges by DonorIdn or ProjectIdn
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
    -- Extract search criteria
    v_DonorIdn := NULLIF(p_InputJson->>'donor_idn', '')::INT;
    v_ProjectIdn := NULLIF(p_InputJson->>'project_idn', '')::INT;
    
    -- Build result JSON
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'pledge_idn', p.PledgeIdn,
                'project_idn', p.ProjectIdn,
                'project_id', pr.ProjectId,
                'project_name', pr.ProjectName,
                'donor_idn', p.DonorIdn,
                'donor_name', d.DonorName,
                'pledge_ts', p.PledgeTs,
                'tree_cnt_pledged', p.TreeCntPledged,
                'tree_cnt_planted', p.TreeCntPlanted,
                'pledge_credit', p.PledgeCredit,
                'property_list', p.PropertyList
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Pledge p
        JOIN stp.U_Project pr 
            ON p.ProjectIdn = pr.ProjectIdn
        JOIN stp.U_Donor d 
            ON p.DonorIdn = d.DonorIdn
    WHERE (v_DonorIdn IS NULL OR p.DonorIdn = v_DonorIdn)
      AND (v_ProjectIdn IS NULL OR p.ProjectIdn = v_ProjectIdn)
    ORDER BY p.PledgeIdn;

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'SELECT Pledges');
END;
$BODY$;

-- SavePledge - Insert/Update pledges with validation
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
    v_InvalidProjects TEXT;
    v_InvalidDonors TEXT;
BEGIN
    -- Create temp table for input pledges
    CREATE TEMP TABLE T_Pledge (
        PledgeIdn       INT,
        ProjectIdn      INT,
        DonorIdn        INT,
        PledgeTs        TIMESTAMP,
        TreeCntPledged  INT,
        TreeCntPlanted  INT,
        PledgeCredit    JSONB,
        PropertyList    VARCHAR(256)
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_Pledge (PledgeIdn, ProjectIdn, DonorIdn, PledgeTs, TreeCntPledged, TreeCntPlanted, PledgeCredit, PropertyList)
    SELECT
        NULLIF(T->>'pledge_idn', '')::INT,
        (T->>'project_idn')::INT,
        (T->>'donor_idn')::INT,
        COALESCE(NULLIF(T->>'pledge_ts', '')::TIMESTAMP, P_AnchorTs),
        COALESCE((T->>'tree_cnt_pledged')::INT, 0),
        COALESCE((T->>'tree_cnt_planted')::INT, 0),
        COALESCE(T->'pledge_credit', '{}'::jsonb),
        COALESCE(T->>'property_list', '{}')
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT T_Pledge');

    -- Validate required fields
    IF EXISTS (SELECT 1 FROM T_Pledge WHERE ProjectIdn IS NULL OR DonorIdn IS NULL) THEN
        RAISE EXCEPTION 'Missing required fields: project_idn and donor_idn are mandatory';
    END IF;

    -- Validate TreeCntPlanted <= TreeCntPledged
    IF EXISTS (SELECT 1 FROM T_Pledge WHERE TreeCntPlanted > TreeCntPledged) THEN
        RAISE EXCEPTION 'tree_cnt_planted cannot exceed tree_cnt_pledged';
    END IF;

    -- Validate ProjectIdn exists
    SELECT string_agg(DISTINCT tp.ProjectIdn::TEXT, ', ')
    INTO v_InvalidProjects
    FROM T_Pledge tp
        LEFT JOIN stp.U_Project p 
            ON tp.ProjectIdn = p.ProjectIdn
    WHERE p.ProjectIdn IS NULL;

    IF v_InvalidProjects IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid project_idn(s): %. Projects do not exist.', v_InvalidProjects;
    END IF;

    -- Validate DonorIdn exists
    SELECT string_agg(DISTINCT tp.DonorIdn::TEXT, ', ')
    INTO v_InvalidDonors
    FROM T_Pledge tp
        LEFT JOIN stp.U_Donor d 
            ON tp.DonorIdn = d.DonorIdn
    WHERE d.DonorIdn IS NULL;

    IF v_InvalidDonors IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid donor_idn(s): %. Donors do not exist.', v_InvalidDonors;
    END IF;

    -- Update existing pledges
    UPDATE stp.U_Pledge up
    SET ProjectIdn = tp.ProjectIdn,
        DonorIdn = tp.DonorIdn,
        PledgeTs = tp.PledgeTs,
        TreeCntPledged = tp.TreeCntPledged,
        TreeCntPlanted = tp.TreeCntPlanted,
        PledgeCredit = tp.PledgeCredit,
        PropertyList = tp.PropertyList,
        UserIdn = P_UserIdn
    FROM T_Pledge tp
    WHERE up.PledgeIdn = tp.PledgeIdn
      AND tp.PledgeIdn IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'UPDATE stp.U_Pledge');

    -- Insert new pledges
    INSERT INTO stp.U_Pledge (ProjectIdn, DonorIdn, PledgeTs, TreeCntPledged, TreeCntPlanted, PledgeCredit, PropertyList, UserIdn)
    SELECT
        tp.ProjectIdn,
        tp.DonorIdn,
        tp.PledgeTs,
        tp.TreeCntPledged,
        tp.TreeCntPlanted,
        tp.PledgeCredit,
        tp.PropertyList,
        P_UserIdn
    FROM T_Pledge tp
    WHERE tp.PledgeIdn IS NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT stp.U_Pledge');

    -- Return saved pledges
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'pledge_idn', up.PledgeIdn,
                'project_idn', up.ProjectIdn,
                'donor_idn', up.DonorIdn,
                'pledge_ts', up.PledgeTs,
                'tree_cnt_pledged', up.TreeCntPledged,
                'tree_cnt_planted', up.TreeCntPlanted,
                'pledge_credit', up.PledgeCredit,
                'property_list', up.PropertyList
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Pledge up
    WHERE (up.ProjectIdn, up.DonorIdn) IN (SELECT ProjectIdn, DonorIdn FROM T_Pledge);
END;
$BODY$;

-- DeletePledge - Delete pledges with validation
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
    v_CreateType VARCHAR(32);
    v_DeletedPledgeIdns TEXT;
    v_PledgesWithPhotos TEXT;
BEGIN
    -- Create temp table for delete requests
    CREATE TEMP TABLE T_PledgeDelete (
        PledgeIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_PledgeDelete (PledgeIdn)
    SELECT (T->>'pledge_idn')::INT
    FROM jsonb_array_elements(p_InputJson) AS T
    WHERE T->>'pledge_idn' IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT T_PledgeDelete');

    IF v_Rc = 0 THEN
        RAISE EXCEPTION 'No valid pledge_idn values provided for deletion';
    END IF;

    -- Capture PledgeIdns being deleted
    SELECT string_agg(PledgeIdn::TEXT, ',')
    INTO v_DeletedPledgeIdns
    FROM T_PledgeDelete;

    -- Delete pledges
    DELETE FROM stp.U_Pledge up
    USING T_PledgeDelete tpd
    WHERE up.PledgeIdn = tpd.PledgeIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'DELETE stp.U_Pledge');

    -- Return result
    p_OutputJson := jsonb_build_object(
        'deleted_count', v_Rc,
        'deleted_pledge_idns', COALESCE(v_DeletedPledgeIdns, '')
    );
END;
$BODY$;

-- =====================================================================
-- TREE PROCEDURES
-- =====================================================================

-- CreateTreeBulk - Create trees for pledges in a project
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
    CALL core.P_RunLogStep(p_RunLogIdn, NULL, 'ProjectIdn: ' || v_ProjectIdn);

    -- Get CreateType
    v_CreateType := COALESCE(p_InputJson->>'create_type', 'Missing');
    CALL core.P_RunLogStep(p_RunLogIdn, NULL, 'CreateType: ' || v_CreateType);

    -- Validate project exists and get ProjectId
    SELECT ProjectId
    INTO v_ProjectId
    FROM stp.U_Project
    WHERE ProjectIdn = v_ProjectIdn;
    
    IF v_ProjectId IS NULL THEN
        RAISE EXCEPTION 'Project not found for ProjectIdn: %', v_ProjectIdn;
    END IF;
    CALL core.P_RunLogStep(p_RunLogIdn, NULL, 'Found Project: ' || v_ProjectId);

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
        CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'DELETE stp.U_Tree (Clean mode)');
    END IF;

    -- Get the current max tree number for this project
    SELECT COALESCE(MAX(SUBSTRING(t.TreeId FROM LENGTH(v_ProjectId) + 1)::INT), 0)
    INTO v_MaxTreeNum
    FROM stp.U_Pledge p
        JOIN stp.U_Tree t 
            ON p.PledgeIdn = t.PledgeIdn
    WHERE p.ProjectIdn = v_ProjectIdn;
    CALL core.P_RunLogStep(p_RunLogIdn, NULL, 'Max TreeNum: ' || v_MaxTreeNum);

    -- Create tree records for project pledges
    INSERT INTO stp.U_Tree (TreeLocation, TreeTypeIdn, PledgeIdn, CreditName, TreeId, PropertyList)
	SELECT NULL,NULL,p.PledgeIdn,pc.key,
	    v_ProjectId || LPAD((v_MaxTreeNum + row_number() OVER (ORDER BY p.PledgeIdn, pc.key, gs.n))::TEXT, 6, '0') AS TreeId,
		'{}'
	FROM 
		(SELECT p.PledgeIdn,p.DonorIdn,p.TreeCntPledged,p.PledgeCredit
	    FROM stp.U_Pledge p
	        LEFT JOIN stp.U_Tree t
		        ON p.PledgeIdn=t.PledgeIdn
	    WHERE p.ProjectIdn=v_ProjectIdn
	      AND t.TreeIdn IS NULL
		) AS t
	    CROSS JOIN LATERAL jsonb_each_text(t.PledgeCredit) AS pc
	    CROSS JOIN LATERAL generate_series(1, (pc.value)::INT) AS gs(n)
	WHERE p.ProjectIdn = v_ProjectIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT stp.U_Tree');

    -- Return summary
    p_OutputJson := jsonb_build_object(
        'project_idn', v_ProjectIdn,
        'project_id', v_ProjectId,
        'trees_created', v_Rc,
        'create_type', v_CreateType
    );
END;
$BODY$;

-- GetTree - Search trees by various criteria
CREATE OR REPLACE PROCEDURE STP.P_GetTree(
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
    v_TreeIdPattern := '%' || p_InputJson->>'tree_id_pattern' || '%';
    v_CreditNamePattern := '%' || p_InputJson->>'credit_name' || '%';
    
    RAISE NOTICE 'GetTree - PledgeIdn: %, ProjectIdn: %, DonorIdn: %, TreeIdPattern: %, CreditNamePattern: %', 
        v_PledgeIdn, v_ProjectIdn, v_DonorIdn, v_TreeIdPattern, v_CreditNamePattern;

    -- Build result JSON with related information
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'tree_idn', t.TreeIdn,
                'latitude', ST_Y(t.TreeLocation::geometry)::FLOAT,
                'longitude', ST_X(t.TreeLocation::geometry)::FLOAT
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Tree t
	    JOIN stp.U_Pledge p 
			ON t.PledgeIdn = p.PledgeIdn
	    JOIN stp.U_Project pr 
			ON p.ProjectIdn = pr.ProjectIdn
	    JOIN stp.U_Donor d 
			ON p.DonorIdn = d.DonorIdn
    WHERE (v_PledgeIdn IS NULL OR t.PledgeIdn = v_PledgeIdn)
      AND (v_ProjectIdn IS NULL OR p.ProjectIdn = v_ProjectIdn)
      AND (v_DonorIdn IS NULL OR p.DonorIdn = v_DonorIdn)
      AND (v_TreeIdPattern IS NULL OR t.TreeId LIKE v_TreeIdPattern)
      AND (v_CreditNamePattern NULL OR t.CreditName LIKE v_CreditNamePattern)
    ORDER BY t.TreeIdn;

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'SELECT Trees');
END;
$BODY$;

CREATE OR REPLACE PROCEDURE STP.P_SaveTree(
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
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT T_Tree');

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
    LEFT JOIN stp.U_Tree ut ON tt.TreeIdn = ut.TreeIdn
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
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'UPDATE stp.U_Tree');

    -- Return updated trees
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'tree_idn', t.TreeIdn,
                'tree_id', t.TreeId,
                'tree_location', jsonb_build_object(
                    'latitude', ST_Y(t.TreeLocation::geometry)::FLOAT,
                    'longitude', ST_X(t.TreeLocation::geometry)::FLOAT
                ),
                'tree_type_idn', t.TreeTypeIdn,
                'pledge_idn', t.PledgeIdn,
                'credit_name', t.CreditName,
                'property_list', t.PropertyList
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Tree t
    WHERE t.TreeIdn IN (SELECT TreeIdn FROM T_Tree);
END;
$BODY$;

-- DeleteTree - Delete trees by PledgeIdns with validation
CREATE OR REPLACE PROCEDURE STP.P_DeleteTree(
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
    v_DeletedTreeIdns TEXT;
    v_TreesWithPhotos TEXT;
    v_ForceDelete BOOLEAN;
BEGIN
    -- Validate input is an array
    IF jsonb_typeof(p_InputJson) != 'array' THEN
        RAISE EXCEPTION 'Input must be a JSON array';
    END IF;

    -- Get force_delete flag (default false)
    v_ForceDelete := COALESCE((p_InputJson->0->>'force_delete')::BOOLEAN, false);
    CALL core.P_RunLogStep(p_RunLogIdn, NULL, 'ForceDelete: ' || v_ForceDelete);

    -- Create temp table for delete requests
    CREATE TEMP TABLE T_TreeDelete (
        PledgeIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON - expecting array of pledge_idn values
    INSERT INTO T_TreeDelete (PledgeIdn)
    SELECT DISTINCT (T->>'pledge_idn')::INT
    FROM jsonb_array_elements(p_InputJson) AS T
    WHERE T->>'pledge_idn' IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT T_TreeDelete');

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
        CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'DELETE stp.U_TreePhoto (force)');

        -- Also delete from donor send log
        DELETE FROM stp.U_DonorSendLog dsl
        USING T_TreeDelete ttd
	        JOIN stp.U_Tree t 
				ON ttd.PledgeIdn = t.PledgeIdn
        WHERE dsl.TreeIdn = t.TreeIdn;
        GET DIAGNOSTICS v_Rc = ROW_COUNT;
        CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'DELETE stp.U_DonorSendLog (force)');
    END IF;

    -- Capture TreeIdns being deleted
    SELECT string_agg(DISTINCT t.TreeIdn::TEXT, ',')
    INTO v_DeletedTreeIdns
    FROM T_TreeDelete ttd
    JOIN stp.U_Tree t ON ttd.PledgeIdn = t.PledgeIdn;

    -- Delete trees for the specified pledges
    DELETE FROM stp.U_Tree t
    USING T_TreeDelete ttd
    WHERE t.PledgeIdn = ttd.PledgeIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'DELETE stp.U_Tree');

    -- Return result
    p_OutputJson := jsonb_build_object(
        'deleted_count', v_Rc,
        'deleted_tree_idns', COALESCE(v_DeletedTreeIdns, ''),
        'force_delete', v_ForceDelete
    );
END;
$BODY$;
CREATE OR REPLACE PROCEDURE STP.P_UploadTreePhoto(
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
    v_InvalidTreeIds TEXT;
    v_InvalidProviders TEXT;
    v_PhotosInserted INT := 0;
    v_FilesInserted INT := 0;
BEGIN
    -- Validate input is an array
    IF jsonb_typeof(p_InputJson) != 'array' THEN
        RAISE EXCEPTION 'Input must be a JSON array';
    END IF;

    -- Create temp table for input data
    CREATE TEMP TABLE T_PhotoUpload (
        RowNum          SERIAL,
        -- Tree identification
        TreeId          VARCHAR(64),
        -- Provider info (U_Provider columns)
        ProviderName    VARCHAR(128),
        -- File info (U_File columns)
        FileStoreId     VARCHAR(64),
        FilePath        VARCHAR(64),
        FileName        VARCHAR(64),
        FileType        VARCHAR(64),
        CreatedTs       TIMESTAMP,
        -- Photo info (U_TreePhoto columns)
        PhotoLat        FLOAT,
        PhotoLng        FLOAT,
        PhotoTs         TIMESTAMP,
        PhotoPropertyList VARCHAR(256),
    ) ON COMMIT DROP;

    -- Parse input JSON - map to respective table columns
    INSERT INTO T_PhotoUpload (TreeId,ProviderName,FilePath,FileName,FileType,FileStoreId,CreatedTs,
        PhotoLat,PhotoLng,PhotoTs,PhotoPropertyList,UploadTs)
    SELECT 
        T->>'tree_id',
        -- U_Provider columns
        T->>'provider_name',
        -- U_File columns
        T->>'file_store_id',
        T->>'file_path',
        T->>'file_name',
        T->>'file_type',
        COALESCE(NULLIF(T->>'created_ts', '')::TIMESTAMP, P_AnchorTs),
        -- U_TreePhoto columns
        (T->>'photo_latitude')::FLOAT,
        (T->>'photo_longitude')::FLOAT,
        NULLIF(T->>'photo_ts', '')::TIMESTAMP,
        COALESCE(T->>'photo_property_list', '{}'),
        -- Upload timestamp (primary key for U_TreePhoto)
        COALESCE(NULLIF(T->>'upload_ts', '')::TIMESTAMP, P_AnchorTs)
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT T_PhotoUpload');

    -- Validate required fields
    IF EXISTS (
        SELECT 1 FROM T_PhotoUpload 
        WHERE TreeId IS NULL 
           OR ProviderName IS NULL 
           OR FileName IS NULL 
           OR FileType IS NULL 
           OR PhotoLat IS NULL 
           OR PhotoLng IS NULL
    ) THEN
        RAISE EXCEPTION 'Missing required fields: tree_id, provider_name, file_name, file_type, photo_latitude, photo_longitude are mandatory';
    END IF;

    -- Validate geographic coordinates
    IF EXISTS (SELECT 1 FROM T_PhotoUpload WHERE PhotoLat < -90 OR PhotoLat > 90 OR PhotoLng < -180 OR PhotoLng > 180) THEN
        RAISE EXCEPTION 'Invalid coordinates: Latitude must be between -90 and 90, Longitude between -180 and 180';
    END IF;

    -- Resolve TreeId to TreeIdn
    UPDATE T_PhotoUpload tpu
    SET TreeIdn = t.TreeIdn
    FROM stp.U_Tree t
    WHERE tpu.TreeId = t.TreeId;

    -- Validate all TreeIds exist
    SELECT string_agg(DISTINCT TreeId, ', ')
    INTO v_InvalidTreeIds
    FROM T_PhotoUpload
    WHERE TreeIdn IS NULL;

    IF v_InvalidTreeIds IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid tree_id(s): %. Trees do not exist.', v_InvalidTreeIds;
    END IF;

    -- Resolve ProviderName to ProviderIdn
    UPDATE T_PhotoUpload tpu
    SET ProviderIdn = p.ProviderIdn
    FROM stp.U_Provider p
    WHERE tpu.ProviderName = p.ProviderName;

    -- Validate all Providers exist
    SELECT string_agg(DISTINCT ProviderName, ', ')
    INTO v_InvalidProviders
    FROM T_PhotoUpload
    WHERE ProviderIdn IS NULL;

    IF v_InvalidProviders IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid provider_name(s): %. Providers do not exist.', v_InvalidProviders;
    END IF;

    -- Derive DonorIdn from tree's pledge
    UPDATE T_PhotoUpload tpu
    SET DonorIdn = p.DonorIdn
    FROM stp.U_Tree t
    JOIN stp.U_Pledge p ON t.PledgeIdn = p.PledgeIdn
    WHERE tpu.TreeIdn = t.TreeIdn;

    -- Validate DonorIdn was successfully derived for all records
    IF EXISTS (SELECT 1 FROM T_PhotoUpload WHERE DonorIdn IS NULL) THEN
        RAISE EXCEPTION 'Failed to derive DonorIdn for some trees. Tree-Pledge-Donor relationship may be broken.';
    END IF;

    CALL core.P_RunLogStep(p_RunLogIdn, NULL, 'Validation complete - resolved TreeIdn, ProviderIdn, DonorIdn');

    -- Insert files into U_File
    INSERT INTO stp.U_File (FilePath, FileName, FileType, FileStoreId, CreatedTs, ProviderIdn)
    SELECT 
        tpu.FilePath,
        tpu.FileName,
        tpu.FileType,
        tpu.FileStoreId,
        tpu.CreatedTs,
        tpu.ProviderIdn
    FROM T_PhotoUpload tpu
    RETURNING FileIdn, FileName
    INTO TEMP TABLE T_NewFiles;
    GET DIAGNOSTICS v_FilesInserted = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_FilesInserted, 'INSERT stp.U_File');

    -- Update temp table with new FileIdns (match by filename and row order)
    WITH FileMapping AS (
        SELECT 
            tpu.RowNum,
            nf.FileIdn,
            ROW_NUMBER() OVER (PARTITION BY tpu.FileName ORDER BY tpu.RowNum) as rn1,
            ROW_NUMBER() OVER (PARTITION BY nf.FileName ORDER BY nf.FileIdn) as rn2
        FROM T_PhotoUpload tpu
        JOIN T_NewFiles nf ON tpu.FileName = nf.FileName
    )
    UPDATE T_PhotoUpload tpu
    SET FileIdn = fm.FileIdn
    FROM FileMapping fm
    WHERE tpu.RowNum = fm.RowNum
      AND fm.rn1 = fm.rn2;

    -- Insert tree photos into U_TreePhoto
    INSERT INTO stp.U_TreePhoto (TreeIdn, UploadTs, PhotoLocation, PropertyList, FileIdn, PhotoTs, DonorIdn, UserIdn)
    SELECT 
        tpu.TreeIdn,
        tpu.UploadTs,
        ST_SetSRID(ST_MakePoint(tpu.PhotoLng, tpu.PhotoLat), 4326)::geography,
        tpu.PhotoPropertyList,
        tpu.FileIdn,
        tpu.PhotoTs,
        tpu.DonorIdn,
        P_UserIdn
    FROM T_PhotoUpload tpu
    ON CONFLICT (TreeIdn, UploadTs) DO UPDATE
    SET PhotoLocation = EXCLUDED.PhotoLocation,
        PropertyList = EXCLUDED.PropertyList,
        FileIdn = EXCLUDED.FileIdn,
        PhotoTs = EXCLUDED.PhotoTs,
        DonorIdn = EXCLUDED.DonorIdn,
        UserIdn = EXCLUDED.UserIdn;
    GET DIAGNOSTICS v_PhotosInserted = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_PhotosInserted, 'INSERT/UPDATE stp.U_TreePhoto');

    -- Create donor send log entries for new photos
    INSERT INTO stp.U_DonorSendLog (TreeIdn, UploadTs, SendStatus)
    SELECT DISTINCT
        tpu.TreeIdn,
        tpu.UploadTs,
        'pending'
    FROM T_PhotoUpload tpu
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_RunLogStep(p_RunLogIdn, v_Rc, 'INSERT stp.U_DonorSendLog');

    -- Return uploaded photo information with complete details
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'tree_idn', tp.TreeIdn,
                'tree_id', t.TreeId,
                'credit_name', t.CreditName,
                'upload_ts', tp.UploadTs,
                'photo_ts', tp.PhotoTs,
                'photo_location', jsonb_build_object(
                    'latitude', ST_Y(tp.PhotoLocation::geometry)::FLOAT,
                    'longitude', ST_X(tp.PhotoLocation::geometry)::FLOAT
                ),
                'file_idn', tp.FileIdn,
                'file_name', f.FileName,
                'file_path', f.FilePath,
                'file_type', f.FileType,
                'file_store_id', f.FileStoreId,
                'created_ts', f.CreatedTs,
                'provider_name', prov.ProviderName,
                'donor_idn', tp.DonorIdn,
                'donor_name', d.DonorName,
                'donor_email', d.EmailAddr,
                'donor_mobile', d.MobileNumber,
                'project_idn', pr.ProjectIdn,
                'project_id', pr.ProjectId,
                'project_name', pr.ProjectName,
                'pledge_idn', p.PledgeIdn,
                'send_status', dsl.SendStatus,
                'photo_property_list', tp.PropertyList
            )
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM T_PhotoUpload tpu
    JOIN stp.U_TreePhoto tp ON tpu.TreeIdn = tp.TreeIdn AND tpu.UploadTs = tp.UploadTs
    JOIN stp.U_Tree t ON tp.TreeIdn = t.TreeIdn
    JOIN stp.U_File f ON tp.FileIdn = f.FileIdn
    JOIN stp.U_Provider prov ON f.ProviderIdn = prov.ProviderIdn
    JOIN stp.U_Donor d ON tp.DonorIdn = d.DonorIdn
    JOIN stp.U_Pledge p ON t.PledgeIdn = p.PledgeIdn
    JOIN stp.U_Project pr ON p.ProjectIdn = pr.ProjectIdn
    LEFT JOIN stp.U_DonorSendLog dsl ON tp.TreeIdn = dsl.TreeIdn AND tp.UploadTs = dsl.UploadTs;

    -- Add summary to output
    p_OutputJson := jsonb_build_object(
        'files_created', v_FilesInserted,
        'photos_processed', v_PhotosInserted,
        'photos', p_OutputJson
    );
END;
$BODY$;
