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
    -- Validate required fields directly from JSON in memory
    IF EXISTS (
        SELECT 1 
        FROM jsonb_to_recordset(p_InputJson) AS t(donor_name text, mobile_number text, city text, country text)
        WHERE donor_name IS NULL OR mobile_number IS NULL OR city IS NULL OR country IS NULL
    ) THEN
        RAISE EXCEPTION 'Missing required fields';
    END IF;

    -- Check for duplicate MobileNumber within input batch
    SELECT string_agg(DISTINCT mobile_number, ', ')
    INTO v_DuplicateMobileNumbers
    FROM 
        (SELECT mobile_number
        FROM jsonb_to_recordset(p_InputJson) AS t(mobile_number text)
        GROUP BY mobile_number
        HAVING COUNT(*) > 1
    ) dups;

    IF v_DuplicateMobileNumbers IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate MobileNumber(s) in input batch: %. MobileNumber must be unique.', v_DuplicateMobileNumbers;
    END IF;

    -- Check for duplicate MobileNumber in existing records (excluding current record for updates)
    SELECT string_agg(DISTINCT td.mobile_number, ', ')
    INTO v_DuplicateMobileNumbers
    FROM jsonb_to_recordset(p_InputJson) AS td(donor_idn int, mobile_number text)
        JOIN stp.U_Donor ud 
            ON td.mobile_number = ud.MobileNumber
            AND (td.donor_idn IS NULL OR td.donor_idn != ud.DonorIdn);

    IF v_DuplicateMobileNumbers IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate MobileNumber(s) already exist: %. MobileNumber must be unique.', v_DuplicateMobileNumbers;
    END IF;

--    IF EXISTS
--        (SELECT 1 FROM T_Donor 
--        WHERE EmailAddr IS NOT NULL 
--        AND NOT core.F_ValidateEmail(EmailAddr))
--    THEN
--        RAISE EXCEPTION 'Invalid email address format detected';
--    END IF;

    -- Update existing donors
    UPDATE stp.U_Donor ud
    SET DonorName = td.donor_name,
        MobileNumber = td.mobile_number,
        City = td.city,
        EmailAddr = td.email_addr,
        Country = td.country,
        BirthDt = NULLIF(td.birth_dt, '')::DATE,
        PropertyList = COALESCE(td.property_list, '{}'::jsonb),
        UserIdn = P_UserIdn,
        Ts = P_AnchorTs
    FROM jsonb_to_recordset(p_InputJson) AS td(
        donor_idn     INT,
        donor_name    VARCHAR(128),
        mobile_number VARCHAR(64),
        city          VARCHAR(64),
        email_addr    VARCHAR(64),
        country       VARCHAR(64),
        birth_dt      TEXT,
        property_list JSONB
    )
    WHERE ud.DonorIdn = td.donor_idn
      AND td.donor_idn IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'UPDATE stp.U_Donor');

    -- Insert new donors
    INSERT INTO stp.U_Donor (DonorName, MobileNumber, City, EmailAddr, Country, BirthDt, PropertyList, UserIdn, Ts)
    SELECT 
        td.donor_name,
        td.mobile_number,
        td.city,
        td.email_addr,
        td.country,
        NULLIF(td.birth_dt, '')::DATE,
        COALESCE(td.property_list, '{}'::jsonb),
        P_UserIdn,
        P_AnchorTs
    FROM jsonb_to_recordset(p_InputJson) AS td(
        donor_idn     INT,
        donor_name    VARCHAR(128),
        mobile_number VARCHAR(64),
        city          VARCHAR(64),
        email_addr    VARCHAR(64),
        country       VARCHAR(64),
        birth_dt      TEXT,
        property_list JSONB
    )
    WHERE td.donor_idn IS NULL;
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
    WHERE ud.MobileNumber IN (
        SELECT mobile_number 
        FROM jsonb_to_recordset(p_InputJson) AS t(mobile_number text)
    );
END;
$BODY$;

-- DeleteDonor - Delete donors with validation and optional cascade
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
    v_Cascade BOOLEAN;
    v_PhotosDeleted INT := 0;
    v_FilesDeleted INT := 0;
    v_TreesDeleted INT := 0;
    v_PledgesDeleted INT := 0;
    v_SendLogsDeleted INT := 0;
BEGIN
    -- Get cascade flag (default false)
    v_Cascade := COALESCE((p_InputJson->>'cascade')::BOOLEAN, false);
    CALL core.P_Step(p_RunLogIdn, NULL, 'Cascade: ' || v_Cascade);

    -- Create temp table for delete requests
    CREATE TEMP TABLE T_DonorDelete (
        DonorIdn INT
    ) ON COMMIT DROP;

    -- Parse input JSON - expect {"donors": [{"donor_idn": 1}]}
    INSERT INTO T_DonorDelete (DonorIdn)
    SELECT (T->>'donor_idn')::INT
    FROM jsonb_array_elements(p_InputJson->'donors') AS T
    WHERE T->>'donor_idn' IS NOT NULL;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT T_DonorDelete');

    IF v_Rc = 0 THEN
        RAISE EXCEPTION 'No valid donor_idn values provided for deletion';
    END IF;

    -- Check for donors with existing pledges (unless cascade)
    IF NOT v_Cascade THEN
        SELECT string_agg(DISTINCT ud.DonorName, ', ')
        INTO v_DonorNames
        FROM T_DonorDelete tdd
            JOIN stp.U_Donor ud ON tdd.DonorIdn = ud.DonorIdn
            JOIN stp.U_Pledge up ON tdd.DonorIdn = up.DonorIdn;

        IF v_DonorNames IS NOT NULL THEN
            RAISE EXCEPTION 'Cannot delete donor(s) with existing pledges: %. Use cascade=true to delete donors and all related data.', v_DonorNames;
        END IF;
    ELSE
        -- Cascade delete: remove all related data in correct order
        
        -- 1. Delete donor send logs for trees associated with this donor's pledges
        DELETE FROM stp.U_DonorSendLog dsl
        USING T_DonorDelete tdd
            JOIN stp.U_Pledge p ON tdd.DonorIdn = p.DonorIdn
            JOIN stp.U_Tree t ON p.PledgeIdn = t.PledgeIdn
        WHERE dsl.TreeIdn = t.TreeIdn;
        GET DIAGNOSTICS v_SendLogsDeleted = ROW_COUNT;
        CALL core.P_Step(p_RunLogIdn, v_SendLogsDeleted, 'DELETE stp.U_DonorSendLog (cascade)');

        -- 2. Delete tree photos for trees associated with this donor's pledges
        DELETE FROM stp.U_TreePhoto tp
        USING T_DonorDelete tdd
            JOIN stp.U_Pledge p ON tdd.DonorIdn = p.DonorIdn
            JOIN stp.U_Tree t ON p.PledgeIdn = t.PledgeIdn
        WHERE tp.TreeIdn = t.TreeIdn;
        GET DIAGNOSTICS v_PhotosDeleted = ROW_COUNT;
        CALL core.P_Step(p_RunLogIdn, v_PhotosDeleted, 'DELETE stp.U_TreePhoto (cascade)');

        -- 3. Delete files associated with tree photos (if not referenced elsewhere)
        DELETE FROM stp.U_File f
        WHERE f.FileIdn IN (
            SELECT DISTINCT tp.FileIdn
            FROM T_DonorDelete tdd
                JOIN stp.U_Pledge p ON tdd.DonorIdn = p.DonorIdn
                JOIN stp.U_Tree t ON p.PledgeIdn = t.PledgeIdn
                JOIN stp.U_TreePhoto tp ON t.TreeIdn = tp.TreeIdn
        )
        AND NOT EXISTS (
            SELECT 1 FROM stp.U_TreePhoto tp2
            WHERE tp2.FileIdn = f.FileIdn
        );
        GET DIAGNOSTICS v_FilesDeleted = ROW_COUNT;
        CALL core.P_Step(p_RunLogIdn, v_FilesDeleted, 'DELETE stp.U_File (cascade)');

        -- 4. Delete trees for pledges associated with this donor
        DELETE FROM stp.U_Tree t
        USING T_DonorDelete tdd
            JOIN stp.U_Pledge p ON tdd.DonorIdn = p.DonorIdn
        WHERE t.PledgeIdn = p.PledgeIdn;
        GET DIAGNOSTICS v_TreesDeleted = ROW_COUNT;
        CALL core.P_Step(p_RunLogIdn, v_TreesDeleted, 'DELETE stp.U_Tree (cascade)');

        -- 5. Delete pledges for this donor
        DELETE FROM stp.U_Pledge p
        USING T_DonorDelete tdd
        WHERE p.DonorIdn = tdd.DonorIdn;
        GET DIAGNOSTICS v_PledgesDeleted = ROW_COUNT;
        CALL core.P_Step(p_RunLogIdn, v_PledgesDeleted, 'DELETE stp.U_Pledge (cascade)');
    END IF;

    -- Capture DonorIdns being deleted
    SELECT string_agg(DonorIdn::TEXT, ',')
    INTO v_DeletedDonorIdns
    FROM T_DonorDelete;

    -- Return deleted donors info
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
            ) ORDER BY DonorName
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_Donor ud
    WHERE ud.DonorIdn IN (SELECT DonorIdn FROM T_DonorDelete);

    -- Delete donors
    DELETE FROM stp.U_Donor ud
    USING T_DonorDelete tdd
    WHERE ud.DonorIdn = tdd.DonorIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'DELETE stp.U_Donor');

    -- Add cascade deletion summary to output
    IF v_Cascade THEN
        p_OutputJson := p_OutputJson || jsonb_build_object(
            'cascade', true,
            'deleted_counts', jsonb_build_object(
                'donors', v_Rc,
                'pledges', v_PledgesDeleted,
                'trees', v_TreesDeleted,
                'photos', v_PhotosDeleted,
                'files', v_FilesDeleted,
                'send_logs', v_SendLogsDeleted
            )
        );
    END IF;
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
/*
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
                "donor_idn": 1,
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

-- Example 7: Delete single donor without cascade
CALL core.P_DbApi(
    '{
		"db_api_name": "DeleteDonor",
        "request": {
            "cascade": false,
            "donors": [
                {
                    "donor_idn": 1
                }
            ]
        }
    }'::jsonb,
    NULL
);

-- Example 8: Delete multiple donors
CALL core.P_DbApi(
    '{
		"db_api_name": "DeleteDonor",
        "request": {
            "cascade": false,
            "donors": [
                {
                    "donor_idn": 9
                },
                {
                    "donor_idn": 10
                }
            ]
        }
    }'::jsonb,
    NULL
);

-- Example 9: Cascade delete donor with all related data
-- This deletes the donor AND all related pledges, trees, photos, and send logs
CALL core.P_DbApi(
    '{
		"db_api_name": "DeleteDonor",
        "request": {
            "cascade": true,
            "donors": [
                {
                    "donor_idn": 1
                }
            ]
        }
    }'::jsonb,
    NULL
);

select * from stp.U_Donor;
select * from stp.u_pledge where DonorIdn=1;
select * from core.V_RL ORDER BY RunLogIdn DESC;
select * from core.V_RLS WHERE RunLogIdn=(select MAX(RunLogIdn) from core.U_RunLog) order by Idn;
*/