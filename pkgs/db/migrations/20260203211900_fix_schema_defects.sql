-- +goose Up
-- +goose StatementBegin
SELECT 'Applying schema fixes for defects identified in code review';

---------------------------------------------------------
-- Fix Defect #1: Rename U_File.createdts to ts
---------------------------------------------------------
-- Check if old column exists before renaming
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'stp' 
        AND table_name = 'u_file' 
        AND column_name = 'createdts'
    ) THEN
        ALTER TABLE stp.u_file RENAME COLUMN createdts TO ts;
        RAISE NOTICE 'Renamed U_File.createdts to ts';
    ELSE
        RAISE NOTICE 'Column createdts does not exist, skipping rename';
    END IF;
END $$;

---------------------------------------------------------
-- Fix Defect #2 & #3: Make PhotoLocation and PhotoTs nullable
---------------------------------------------------------
-- These fields should be optional as photos may not have GPS coordinates
-- or explicit timestamps
ALTER TABLE stp.u_treephoto 
    ALTER COLUMN photolocation DROP NOT NULL;

ALTER TABLE stp.u_treephoto 
    ALTER COLUMN photots DROP NOT NULL;

---------------------------------------------------------
-- Fix Defect #5: Add unique constraint on U_Provider.providername
---------------------------------------------------------
-- Check if index already exists before creating
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'stp' 
        AND tablename = 'u_provider' 
        AND indexname = 'xak1u_provider'
    ) THEN
        CREATE UNIQUE INDEX xak1u_provider ON stp.u_provider (providername);
        RAISE NOTICE 'Created unique index on U_Provider.providername';
    ELSE
        RAISE NOTICE 'Index xak1u_provider already exists, skipping';
    END IF;
END $$;

---------------------------------------------------------
-- Fix Defect #6: Add unique constraint on U_TreeType.treetypename
---------------------------------------------------------
-- Check if index already exists before creating
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'stp' 
        AND tablename = 'u_treetype' 
        AND indexname = 'xak1u_treetype'
    ) THEN
        CREATE UNIQUE INDEX xak1u_treetype ON stp.u_treetype (treetypename);
        RAISE NOTICE 'Created unique index on U_TreeType.treetypename';
    ELSE
        RAISE NOTICE 'Index xak1u_treetype already exists, skipping';
    END IF;
END $$;

---------------------------------------------------------
-- Fix: Add unique constraint on U_File business key
---------------------------------------------------------
-- The business key is: (ProviderIdn, FileStoreId, FilePath, FileName)
-- Check if index already exists before creating
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'stp' 
        AND tablename = 'u_file' 
        AND indexname = 'xak1u_file'
    ) THEN
        CREATE UNIQUE INDEX xak1u_file 
            ON stp.u_file (provideridn, filestoreid, filepath, filename);
        RAISE NOTICE 'Created unique index on U_File business key';
    ELSE
        RAISE NOTICE 'Index xak1u_file already exists, skipping';
    END IF;
END $$;

SELECT 'Schema fixes applied successfully' AS status;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
SELECT 'Reverting schema fixes';

-- Revert U_File column rename
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'stp' 
        AND table_name = 'u_file' 
        AND column_name = 'ts'
    ) THEN
        ALTER TABLE stp.u_file RENAME COLUMN ts TO createdts;
    END IF;
END $$;

-- Revert PhotoLocation and PhotoTs to NOT NULL
-- WARNING: This will fail if there are NULL values in the table
ALTER TABLE stp.u_treephoto 
    ALTER COLUMN photolocation SET NOT NULL;

ALTER TABLE stp.u_treephoto 
    ALTER COLUMN photots SET NOT NULL;

-- Drop unique indexes
DROP INDEX IF EXISTS stp.xak1u_provider;
DROP INDEX IF EXISTS stp.xak1u_treetype;
DROP INDEX IF EXISTS stp.xak1u_file;

SELECT 'Schema fixes reverted' AS status;
-- +goose StatementEnd
