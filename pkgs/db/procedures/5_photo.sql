-- 5_photo.sql
-- upload_tree_photo - Upload tree photos with file management
-- get_tree_photos - Retrieve photos for a tree

CREATE OR REPLACE PROCEDURE stp.p_upload_tree_photo(
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
    v_InvalidTreeIds TEXT;
    v_InvalidProviders TEXT;
    v_PhotosInserted INT := 0;
    v_FilesInserted INT := 0;
    v_DuplicateFiles TEXT;
BEGIN
    -- Create temp table for input data
    CREATE TEMP TABLE T_PhotoUpload (
        RowNum          SERIAL,
        -- Tree identification
        TreeId          VARCHAR(64),
        TreeIdn         INT,
        -- Donor information
        DonorIdn        INT,
        -- Provider info (U_Provider columns)
        ProviderName    VARCHAR(128),
        ProviderIdn     INT,
        -- File info (U_File columns)
        FileIdn         INT,
        FileStoreId     VARCHAR(256),
        FilePath        VARCHAR(2048),
        FileName        VARCHAR(256),
        FileType        VARCHAR(64),
        -- Photo info (U_TreePhoto columns)
        PhotoLat        FLOAT,
        PhotoLng        FLOAT,
        PhotoTs         TIMESTAMP,
        PhotoPropertyList JSONB,
        UploadTs        TIMESTAMP
    ) ON COMMIT DROP;

    -- Parse input JSON - map to respective table columns
    INSERT INTO T_PhotoUpload (TreeId, ProviderName, FileStoreId, FilePath, FileName, FileType, CreatedTs,
        PhotoLat, PhotoLng, PhotoTs, PhotoPropertyList, UploadTs)
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
        NULLIF(T->>'photo_latitude', '')::FLOAT,
        NULLIF(T->>'photo_longitude', '')::FLOAT,
        NULLIF(T->>'photo_ts', '')::TIMESTAMP,
        COALESCE(T->'photo_property_list', '{}'::jsonb),
        -- Upload timestamp (primary key for U_TreePhoto)
        COALESCE(NULLIF(T->>'upload_ts', '')::TIMESTAMP, P_AnchorTs)
    FROM jsonb_array_elements(p_InputJson) AS T;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'INSERT T_PhotoUpload');

    -- Validate required fields
    IF EXISTS
        (SELECT 1 FROM T_PhotoUpload 
        WHERE TreeId IS NULL 
           OR ProviderName IS NULL 
           OR FileStoreId IS NULL 
           OR FileName IS NULL 
           OR FileType IS NULL)
    THEN
        RAISE EXCEPTION 'Missing required fields: tree_id, provider_name, file_store_id, file_name, file_type are mandatory';
    END IF;

    -- Validate both latitude and longitude provided together (if provided)
    IF EXISTS (SELECT 1 FROM T_PhotoUpload WHERE (PhotoLat IS NULL AND PhotoLng IS NOT NULL) OR (PhotoLat IS NOT NULL AND PhotoLng IS NULL)) THEN
        RAISE EXCEPTION 'Both latitude and longitude must be provided together or both omitted';
    END IF;

    -- Validate geographic coordinates (only if provided)
    IF EXISTS (SELECT 1 FROM T_PhotoUpload WHERE PhotoLat IS NOT NULL AND (PhotoLat < -90 OR PhotoLat > 90)) THEN
        RAISE EXCEPTION 'Invalid latitude: must be between -90 and 90';
    END IF;
    
    IF EXISTS (SELECT 1 FROM T_PhotoUpload WHERE PhotoLng IS NOT NULL AND (PhotoLng < -180 OR PhotoLng > 180)) THEN
        RAISE EXCEPTION 'Invalid longitude: must be between -180 and 180';
    END IF;

    -- Resolve TreeId to TreeIdn
    UPDATE T_PhotoUpload tpu
    SET TreeIdn = t.TreeIdn
    FROM stp.U_Tree t
    WHERE tpu.TreeId = t.TreeId;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'UPDATE T_PhotoUpload (TreeIdn)');

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
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'UPDATE T_PhotoUpload (ProviderIdn)');

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
        JOIN stp.U_Pledge p 
            ON t.PledgeIdn = p.PledgeIdn
    WHERE tpu.TreeIdn = t.TreeIdn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'UPDATE T_PhotoUpload (DonorIdn)');

    -- Validate DonorIdn was successfully derived for all records
    IF EXISTS (SELECT 1 FROM T_PhotoUpload WHERE DonorIdn IS NULL) THEN
        RAISE EXCEPTION 'Failed to derive DonorIdn for some trees. Tree-Pledge-Donor relationship may be broken.';
    END IF;

    -- Check for duplicate files within the input batch (same ProviderName + FileStoreId)
    SELECT string_agg(DISTINCT ProviderName || ':' || FileStoreId, ', ')
    INTO v_DuplicateFiles
    FROM 
        (SELECT ProviderName, FileStoreId
        FROM T_PhotoUpload
        GROUP BY ProviderName, FileStoreId
        HAVING COUNT(*) > 1
    	) dups;

    IF v_DuplicateFiles IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate files in input batch (Provider:FileStoreId): %. Each file can only be uploaded once per batch.', v_DuplicateFiles;
    END IF;

    -- Insert only new files that don't exist (based on business key: ProviderIdn + FileStoreId)
    INSERT INTO stp.U_File (ProviderIdn, FileStoreId, FilePath, FileName, FileType)
    SELECT 
        tpu.ProviderIdn,
        tpu.FileStoreId,
        tpu.FilePath,
        tpu.FileName,
        tpu.FileType
    FROM T_PhotoUpload tpu
        LEFT JOIN stp.U_File f 
            ON tpu.ProviderIdn = f.ProviderIdn
            AND tpu.FileStoreId = f.FileStoreId
    WHERE f.FileIdn IS NULL;
    GET DIAGNOSTICS v_FilesInserted = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_FilesInserted, 'INSERT stp.U_File');

    -- Single update: Match all files (both existing and newly created) in one pass
    UPDATE T_PhotoUpload tpu
    SET FileIdn = f.FileIdn
    FROM stp.U_File f
    WHERE tpu.ProviderIdn = f.ProviderIdn
      AND tpu.FileStoreId = f.FileStoreId;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'UPDATE T_PhotoUpload (Assign FileIdn)');

    -- Verify all records have FileIdn
    IF EXISTS (SELECT 1 FROM T_PhotoUpload WHERE FileIdn IS NULL) THEN
        RAISE EXCEPTION 'Failed to assign FileIdn to all photos';
    END IF;

    -- Insert tree photos into U_TreePhoto
    INSERT INTO stp.U_TreePhoto (TreeIdn, UploadTs, PhotoLocation, PropertyList, FileIdn, PhotoTs, DonorIdn, UserIdn)
    SELECT 
        tpu.TreeIdn,
        tpu.UploadTs,
        CASE 
            WHEN tpu.PhotoLat IS NOT NULL AND tpu.PhotoLng IS NOT NULL 
            THEN ST_SetSRID(ST_MakePoint(tpu.PhotoLng, tpu.PhotoLat), 4326)::geography
            ELSE NULL
        END,
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
    CALL core.p_step(p_RunLogIdn, v_PhotosInserted, 'INSERT/UPDATE stp.U_TreePhoto');

    -- Create donor send log entries for new photos
    INSERT INTO stp.U_DonorSendLog (TreeIdn, UploadTs, SendStatus)
    SELECT TreeIdn, UploadTs, 'pending'
    FROM T_PhotoUpload
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'INSERT stp.U_DonorSendLog');

    -- Add summary to output
    p_OutputJson := jsonb_build_object(
        'files_created', v_FilesInserted,
        'photos_processed', v_PhotosInserted,
        'total_records', (SELECT COUNT(*) FROM T_PhotoUpload)
    );
END;
$BODY$;

-- GetTreePhotos - Retrieve photos for a tree ordered by upload timestamp
CREATE OR REPLACE PROCEDURE stp.p_get_tree_photos(
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
    v_TreeIdn INT;
BEGIN
    -- Extract TreeIdn from input
    v_TreeIdn := NULLIF(p_InputJson->>'tree_idn', '')::INT;
    
    IF v_TreeIdn IS NULL THEN
        RAISE EXCEPTION 'tree_idn is required';
    END IF;
    
    RAISE NOTICE 'TreeIdn: %', v_TreeIdn;

    -- Build result JSON with photo details
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'tree_idn', tp.TreeIdn,
                'upload_ts', tp.UploadTs,
                'photo_ts', tp.PhotoTs,
                'photo_latitude', ST_Y(tp.PhotoLocation::geometry)::FLOAT,
                'photo_longitude', ST_X(tp.PhotoLocation::geometry)::FLOAT,
                'donor_idn', tp.DonorIdn,
                'donor_name', d.DonorName,
                'file_name', f.FileName,
                'file_path', f.FilePath,
                'file_type', f.FileType,
                'file_store_id', f.FileStoreId,
                'created_ts', f.CreatedTs,
                'provider_name', p.ProviderName,
                'property_list', tp.PropertyList
            ) ORDER BY tp.UploadTs
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM stp.U_TreePhoto tp
        JOIN stp.U_Donor d 
            ON tp.DonorIdn = d.DonorIdn
        JOIN stp.U_File f 
            ON tp.FileIdn = f.FileIdn
        JOIN stp.U_Provider p 
            ON f.ProviderIdn = p.ProviderIdn
    WHERE tp.TreeIdn = v_TreeIdn;

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.p_step(p_RunLogIdn, v_Rc, 'SELECT Tree Photos');
END;
$BODY$;

-- End of 5_photo.sql