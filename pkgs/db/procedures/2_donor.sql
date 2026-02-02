-- 2_donor.sql
-- get_donor
-- search_donor
-- save_donor
-- delete_donor
-- merge_donor

-- GetDonor - Search donors by pattern
CREATE OR REPLACE PROCEDURE stp.P_GetDonor(
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
            ) ORDER BY DonorName, MobileNumber
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Donor
    WHERE (v_DonorPattern IS NULL 
           OR DonorName LIKE v_DonorPattern 
           OR MobileNumber LIKE v_DonorPattern
           OR EmailAddr LIKE v_DonorPattern);
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'SELECT Donors');
END;
$BODY$;

-- SaveDonor - Insert/Update donors with validation
CREATE OR REPLACE PROCEDURE stp.P_SaveDonor(
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
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT T_Donor');

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
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'UPDATE stp.U_Donor');

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
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT stp.U_Donor');

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
CREATE OR REPLACE PROCEDURE stp.P_DeleteDonor(
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
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT T_DonorDelete');

    IF v_Rc = 0 THEN
        RAISE EXCEPTION 'No valid donor_idn values provided for deletion';
    END IF;

    -- Check for donors with existing pledges
    SELECT string_agg(DISTINCT tdd.DonorIdn::VARCHAR,',')
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
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'DELETE stp.U_Donor');

    -- Return result
    p_OutputJson := jsonb_build_object(
        'deleted_count', v_Rc,
        'deleted_donor_idns', COALESCE(v_DeletedDonorIdns, '')
    );
END;
$BODY$;

CALL core.P_DbApi (
    '{
        "db_api_name": "RegisterDbApi",	
        "request": {
            "records": [
                {
                    "db_api_name": "GetDonor",
                    "schema_name": "stp",
                    "handler_name": "P_GetDonor",
                    "property_list": {
                        "description": "Searches donors by name, mobile number, or email pattern",
                        "version": "1.0",
                        "permissions": ["read"]
                    }
                },
                {
                    "db_api_name": "SaveDonor",
                    "schema_name": "stp",
                    "handler_name": "P_SaveDonor",
                    "property_list": {
                        "description": "Saves a new donor or updates an existing one",
                        "version": "1.0",
                        "permissions": ["write"]
                    }
                },
                {
                    "db_api_name": "DeleteDonor",
                    "schema_name": "stp",
                    "handler_name": "P_DeleteDonor",
                    "property_list": {
                        "description": "Deletes a donor by Idn",
                        "version": "1.0",
                        "permissions": ["write"]
                    }
                }
            ]
        }
    }'::jsonb,
    null
);

-- End of 2_donor.sql
select * from stp.U_Donor;

-- Example 1: Search all donors
CALL core.P_DbApi (
    '{
        "db_api_name": "GetDonor",	
        "request": {
            "donor_pattern": null
        }
    }'::jsonb,
    NULL
);

-- Example 2: Search donors by name pattern
CALL core.P_DbApi (
    '{
        "db_api_name": "GetDonor",	
        "request": {
            "donor_pattern": "Sharma"
        }
    }'::jsonb,
    NULL
);

-- Example 3: Search donors by mobile number pattern
CALL core.P_DbApi (
    '{
        "db_api_name": "GetDonor",	
        "request": {
            "donor_pattern": "9876"
        }
    }'::jsonb,
    NULL
);

-- Example 4: Insert new donors with required fields only
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveDonor",
        "request": [
            {
                "donor_name": "Rajesh Kumar Sharma",
                "mobile_number": "+91-9876543210",
                "city": "Mumbai",
                "country": "India"
            },
            {
                "donor_name": "Priya Patel",
                "mobile_number": "+91-9123456789",
                "city": "Ahmedabad",
                "country": "India"
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 5: Insert new donors with all optional fields
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveDonor",
        "request": [
            {
                "donor_name": "Amit Desai",
                "mobile_number": "+91-9988776655",
                "city": "Pune",
                "country": "India",
                "email_addr": "amit.desai@example.com",
                "birth_dt": "1985-03-15",
                "property_list": {
                    "occupation": "Engineer",
                    "preferred_contact": "email"
                }
            },
            {
                "donor_name": "Sneha Reddy",
                "mobile_number": "+91-8765432109",
                "city": "Hyderabad",
                "country": "India",
                "email_addr": "sneha.r@example.com",
                "birth_dt": "1990-07-22",
                "property_list": {
                    "company": "Tech Corp",
                    "referral_source": "website"
                }
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 6: Update existing donors (use actual donor_idn from previous inserts)
CALL core.P_DbApi(
    '{
        "db_api_name": "SaveDonor",
        "request": [
            {
                "donor_idn": "1",
                "donor_name": "Rajesh Kumar Sharma",
                "mobile_number": "+91-9876543210",
                "city": "Mumbai",
                "country": "India",
                "email_addr": "rajesh.sharma@example.com",
                "property_list": {
                    "vip_status": true
                }
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 7: Delete single donor
CALL core.P_DbApi(
    '{
        "db_api_name": "DeleteDonor",
        "request": [
            {
                "donor_idn": "2"
            }
        ]
    }'::jsonb,
    NULL
);

-- Example 8: Delete multiple donors
CALL core.P_DbApi(
    '{
        "db_api_name": "DeleteDonor",
        "request": [
            {
                "donor_idn": "3"
            },
            {
                "donor_idn": "4"
            }
        ]
    }'::jsonb,
    NULL
);

select * from stp.U_Donor;
select * from core.V_RL ORDER BY RunLogIdn DESC;
select * from core.V_RLS WHERE RunLogIdn=(select MAX(RunLogIdn) from core.U_RunLog) order by Idn;