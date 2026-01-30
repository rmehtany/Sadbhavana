-- 2_donor.sql
-- get_donor
-- search_donor
-- save_donor
-- delete_donor
-- merge_donor

-- GetDonor - Search donors by pattern
CREATE OR REPLACE PROCEDURE stp.p_get_donor(
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
    CALL core.p_step(p_RunLogIdn, v_Rc, 'SELECT Donors');
END;
$BODY$;

-- SaveDonor - Insert/Update donors with validation
CREATE OR REPLACE PROCEDURE stp.p_save_donor(
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
        BirthDt         DATE,
        PropertyList    JSONB
    ) ON COMMIT DROP;

    -- Parse input JSON
    INSERT INTO T_Donor (DonorIdn, DonorName, MobileNumber, City, EmailAddr, Country, BirthDt, PropertyList)
    SELECT 
        NULLIF(T->>'donor_idn', '')::INT,
        T->>'donor_name',
        T->>'mobile_number',
        T->>'city',
        T->>'email_addr',
        T->>'country',
        NULLIF(T->>'birth_dt', '')::DATE,
        COALESCE(T->'property_list', '{}'::jsonb)
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'INSERT T_Donor');

    -- Validate required fields
    IF EXISTS (SELECT 1 FROM T_Donor WHERE DonorName IS NULL OR MobileNumber IS NULL OR City IS NULL OR Country IS NULL) THEN
        RAISE EXCEPTION 'Missing required fields: donor_name, mobile_number, city, country are mandatory';
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

    IF EXISTS
        (SELECT 1 FROM T_Donor 
        WHERE EmailAddr IS NOT NULL 
        AND NOT core.F_ValidateEmail(EmailAddr))
    THEN
        RAISE EXCEPTION 'Invalid email address format detected';
    END IF;

    -- Update existing donors
    UPDATE stp.U_Donor ud
    SET DonorName = td.DonorName,
        MobileNumber = td.MobileNumber,
        City = td.City,
        EmailAddr = td.EmailAddr,
        Country = td.Country,
        BirthDt = td.BirthDt,
        PropertyList = td.PropertyList,
        UserIdn = P_UserIdn,
        Ts = P_AnchorTs
    FROM T_Donor td
    WHERE ud.DonorIdn = td.DonorIdn
      AND td.DonorIdn IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'UPDATE stp.U_Donor');

    -- Insert new donors
    INSERT INTO stp.U_Donor (DonorName, MobileNumber, City, EmailAddr, Country, BirthDt, PropertyList, UserIdn, Ts)
    SELECT 
        td.DonorName,
        td.MobileNumber,
        td.City,
        td.EmailAddr,
        td.Country,
        td.BirthDt,
        td.PropertyList,
        P_UserIdn,
        P_AnchorTs
    FROM T_Donor td
    WHERE td.DonorIdn IS NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'INSERT stp.U_Donor');

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
CREATE OR REPLACE PROCEDURE stp.p_delete_donor(
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
    CALL core.p_step(p_RunLogIdn, v_Rc, 'INSERT T_DonorDelete');

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
    CALL core.p_step(p_RunLogIdn, v_Rc, 'DELETE stp.U_Donor');

    -- Return result
    p_OutputJson := jsonb_build_object(
        'deleted_count', v_Rc,
        'deleted_donor_idns', COALESCE(v_DeletedDonorIdns, '')
    );
END;
$BODY$;
-- MergeDonor - Merge donor records