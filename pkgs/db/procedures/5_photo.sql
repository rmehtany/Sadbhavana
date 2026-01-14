-- 5_photo.sql
-- UploadPhotoInfo
-- GetTreePhotos
/*
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
*/