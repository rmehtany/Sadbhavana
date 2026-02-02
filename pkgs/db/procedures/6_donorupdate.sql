-- 6_donorupdate.sql
-- Donor Update Management
--
-- This module manages the notification workflow for sending tree photo updates to donors.
-- It uses a high water mark pattern to track which updates have been processed, allowing
-- for efficient batch processing and recovery from failures.
--
-- Key Features:
-- - Batch retrieval of pending donor notifications
-- - High water mark tracking to prevent duplicate processing
-- - Status tracking (pending/sent/failed) for each notification
-- - Complete donor and tree information for notification generation

-- =====================================================================================
-- P_GetDonorUpdate
-- =====================================================================================
-- Purpose: Retrieve the next batch of pending donor photo notifications
--
-- This procedure implements a cursor-free batch processing pattern using a high water
-- mark stored in core.U_Control. It returns complete information needed to generate
-- notifications to donors about their tree photos.
--
-- Input Parameters:
--   p_InputJson: {
--     "batch_size": <number>  // Optional, default 100, max 1000
--   }
--
-- Output:
--   Array of donor update records with complete tree and photo information
--
-- High Water Mark:
--   Tracks the last processed Idn from U_DonorSendLog to enable resumable processing
--   Stored in: core.U_Control with ControlName = 'DonorUpdHwm'
-- =====================================================================================

CREATE OR REPLACE PROCEDURE stp.P_GetDonorUpdate(
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
    v_BatchSize INT;
    v_HighWaterMark INT;
    v_MaxIdn INT;
BEGIN
    -- Extract and validate batch size (default: 100, max: 1000)
    v_BatchSize := COALESCE((p_InputJson->>'batch_size')::INT, 100);

    IF v_BatchSize <= 0 OR v_BatchSize > 1000 THEN
        RAISE EXCEPTION 'batch_size must be between 1 and 1000';
    END IF;
    CALL core.P_Step(p_RunLogIdn, NULL, 'Batch Size: ' || v_BatchSize);

    -- Retrieve high water mark from control table
    -- This represents the last successfully processed Idn from U_DonorSendLog
    -- If no high water mark exists (first run), defaults to 0

    SELECT COALESCE((core.F_GetControl('DonorUpdHwm')->>'idn')::INT, 0)
    INTO v_HighWaterMark;
    CALL core.P_Step(p_RunLogIdn, NULL, 'High Water Mark: ' || v_HighWaterMark);

    -- Create temporary staging table for this batch
    -- Stores Idn values for efficient subsequent JOIN operations
    CREATE TEMP TABLE T_DonorUpdateBatch (
        Idn INT PRIMARY KEY,
        TreeIdn INT,
        UploadTs TIMESTAMPTZ
    ) ON COMMIT DROP;

    -- Select next N pending entries from donor send log
    -- Only processes records that:
    --   1. Have status 'pending' (not yet sent)
    --   2. Have Idn > current high water mark (haven't been processed)
    -- Orders by Idn to ensure sequential processing
    INSERT INTO T_DonorUpdateBatch (Idn, TreeIdn, UploadTs)
    SELECT Idn, TreeIdn, UploadTs
    FROM stp.U_DonorSendLog
    WHERE SendStatus = 'pending'
      AND Idn > v_HighWaterMark
    ORDER BY Idn
    LIMIT v_BatchSize;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'SELECT next batch from U_DonorSendLog');

    -- If no pending records found, return empty result
    IF v_Rc = 0 THEN
        p_OutputJson := '[]'::jsonb;
        CALL core.P_Step(p_RunLogIdn, NULL, 'No pending updates found');
        RETURN;
    END IF;

    -- Retrieve complete donor notification data
    -- Joins across multiple tables to gather all information needed for notification:
    --   - Tree details (TreeId, CreditName)
    --   - Donor contact information (name, email, mobile)
    --   - Project context (project name)
    --   - Photo metadata (timestamp, location)
    --   - File storage details (path, name, type)
    --
    -- Note: Currently filters to pledges with tree_cnt_pledged <= 3
    -- TODO: Consider making this filter configurable or removing it
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'idn', dub.Idn,
                'tree_idn', dub.TreeIdn,
                'tree_id', t.TreeId,
                'credit_name', t.CreditName,
                'upload_ts', dub.UploadTs,
                'donor_name', d.DonorName,
                'donor_email', d.EmailAddr,
                'donor_mobile', d.MobileNumber,
                'project_name', pr.ProjectName,
                'photo_ts', tp.PhotoTs,
                'photo_location_latitude', ST_Y(tp.PhotoLocation::geometry)::FLOAT,
                'photo_location_longitude', ST_X(tp.PhotoLocation::geometry)::FLOAT,
                'file_name', f.FileName,
                'file_path', f.FilePath,
                'file_type', f.FileType
            ) ORDER BY dub.Idn
        ), '[]'::jsonb
    )
    INTO p_OutputJson
    FROM T_DonorUpdateBatch dub
        JOIN stp.U_Tree t 
            ON dub.TreeIdn = t.TreeIdn
        JOIN stp.U_Pledge p 
            ON t.PledgeIdn = p.PledgeIdn
            AND p.TreeCntPledged <= 3  -- Filter for small pledges only
        JOIN stp.U_Donor d 
            ON p.DonorIdn = d.DonorIdn
        JOIN stp.U_Project pr 
            ON p.ProjectIdn = pr.ProjectIdn
        JOIN stp.U_TreePhoto tp 
            ON dub.TreeIdn = tp.TreeIdn 
            AND dub.UploadTs = tp.UploadTs
        JOIN stp.U_File f 
            ON tp.FileIdn = f.FileIdn;

    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'Build donor update JSON');
END;
$BODY$;

-- =====================================================================================
-- P_PostDonorUpdate
-- =====================================================================================
-- Purpose: Mark donor notifications as sent/failed and update processing high water mark
--
-- After notifications are sent to donors, this procedure updates their status in
-- U_DonorSendLog and advances the high water mark to track progress.
--
-- Input Parameters:
--   p_InputJson: [
--     {
--       "idn": <number>,           // U_DonorSendLog.Idn
--       "send_status": <string>    // 'sent' or 'failed'
--     },
--     ...
--   ]
--
-- Output:
--   Summary of updates performed and new high water mark value
--
-- Send Status Values:
--   - 'sent': Notification successfully delivered to donor
--   - 'failed': Notification delivery failed (can be retried)
--   - 'pending': Initial state (not accepted as input here)
--
-- High Water Mark Update:
--   Updated to the maximum Idn from the input batch, enabling resumable processing
-- =====================================================================================

CREATE OR REPLACE PROCEDURE stp.P_PostDonorUpdate(
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
    v_NewHighWaterMark INT;
BEGIN
    -- Create temporary table for batch status updates
    CREATE TEMP TABLE T_DonorSendUpdate (
        Idn INT,
        SendStatus VARCHAR(64)
    ) ON COMMIT DROP;

    -- Parse input JSON array into temporary table
    -- Each element should contain an Idn and new send_status
    INSERT INTO T_DonorSendUpdate (Idn, SendStatus)
    SELECT 
        (T->>'idn')::INT,
        T->>'send_status'
    FROM jsonb_array_elements(p_InputJson) AS T
    WHERE T->>'idn' IS NOT NULL;  -- Skip any malformed entries
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'INSERT T_DonorSendUpdate');

    -- Validate that we have records to process
    IF v_Rc = 0 THEN
        RAISE EXCEPTION 'No valid idn values provided for update';
    END IF;

    -- Validate send_status values
    -- Only 'sent' and 'failed' are accepted
    -- 'pending' is the initial state and shouldn't be posted back
    IF EXISTS 
        (SELECT 1 FROM T_DonorSendUpdate 
         WHERE SendStatus NOT IN ('sent', 'failed'))
    THEN
        RAISE EXCEPTION 'Invalid send_status. Must be one of: sent, failed';
    END IF;

    -- Update status in donor send log
    -- For 'sent' status, also record the timestamp of successful delivery
    -- For 'failed' status, preserve any existing SendTs (for retry tracking)
    UPDATE stp.U_DonorSendLog dsl
    SET SendStatus = tsu.SendStatus,
        SendTs = 
            CASE 
                WHEN tsu.SendStatus = 'sent' THEN P_AnchorTs
                ELSE dsl.SendTs  -- Preserve existing timestamp for failed attempts
            END
    FROM T_DonorSendUpdate tsu
    WHERE dsl.Idn = tsu.Idn;
    GET DIAGNOSTICS v_Rc = ROW_COUNT;
    CALL core.P_Step(p_RunLogIdn, v_Rc, 'UPDATE stp.U_DonorSendLog');

    -- Update high water mark to track processing progress
    -- Uses the maximum Idn from this batch
    -- This allows processing to resume from this point if interrupted
    IF v_Rc > 0 THEN
        SELECT MAX(Idn)
        INTO v_NewHighWaterMark
        FROM T_DonorSendUpdate;

        -- Store new high water mark in control table
        CALL core.P_SetControl(
            'DonorUpdHwm',
            jsonb_build_object(
                'idn', v_NewHighWaterMark,
                'updated_ts', P_AnchorTs,
                'updated_by', P_UserIdn
            ),
            P_UserIdn
        );
        CALL core.P_Step(p_RunLogIdn, NULL, 'Updated High Water Mark: ' || v_NewHighWaterMark);
    ELSE
        v_NewHighWaterMark := NULL;
        CALL core.P_Step(p_RunLogIdn, NULL, 'No records updated - high water mark unchanged');
    END IF;

    -- Return summary of operation
    p_OutputJson := jsonb_build_object(
        'updated_count', v_Rc,
        'new_high_water_mark', v_NewHighWaterMark
    );
END;
$BODY$;

-- =====================================================================================
-- Usage Examples
-- =====================================================================================
/*

-- Example 1: Get next batch of pending donor updates (default batch size of 100)
CALL core.P_DbApi(
    '{
        "db_api_name": "GetDonorUpdate",
        "request": {}
    }'::jsonb,
    NULL
);

-- Example 2: Get specific batch size
CALL core.P_DbApi(
    '{
        "db_api_name": "GetDonorUpdate",
        "request": {
            "batch_size": 50
        }
    }'::jsonb,
    NULL
);

-- Example 3: Mark notifications as sent
CALL core.P_DbApi(
    '{
        "db_api_name": "PostDonorUpdate",
        "request": [
            {"idn": 123, "send_status": "sent"},
            {"idn": 124, "send_status": "sent"},
            {"idn": 125, "send_status": "failed"}
        ]
    }'::jsonb,
    NULL
);

-- Check current high water mark
SELECT core.P_GetControl('DonorUpdHwm');

-- Reset high water mark (for testing/recovery)
CALL core.P_SetControl(
    'DonorUpdHwm',
    '{"idn": 0}'::jsonb,
    1
);

*/