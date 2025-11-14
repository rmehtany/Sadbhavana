-- +goose Up
-- Enable PostGIS extension for geospatial data
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create core schema
CREATE SCHEMA IF NOT EXISTS core;

-- Create nanoid generation function
CREATE OR REPLACE FUNCTION core.generate_nanoid(prefix CHAR(3) DEFAULT NULL, size INT DEFAULT 21) RETURNS TEXT AS $BODY$ DECLARE alphabet TEXT := '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'; id TEXT := ''; i INT := 0; nanoid_size INT; BEGIN IF prefix IS NOT NULL THEN IF length(prefix) != 3 THEN RAISE EXCEPTION 'Prefix must be exactly 3 characters long'; END IF; nanoid_size := size - 4; id := prefix || '_'; ELSE nanoid_size := size; END IF; WHILE i < nanoid_size LOOP id := id || substr(alphabet, floor(random() * length(alphabet) + 1)::int, 1); i := i + 1; END LOOP; RETURN id; END $BODY$ LANGUAGE plpgsql VOLATILE;

CREATE TABLE core.project (
    project_name VARCHAR(255) NOT NULL,
    metadata JSONB NOT NULL,
    project_code CHAR(2) PRIMARY KEY
);

-- Create donor table
CREATE TABLE core.donor (
    id CHAR(21) PRIMARY KEY DEFAULT core.generate_nanoid('DON'),
    donor_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(255) NOT NULL
);

-- Create tree table
CREATE TABLE core.tree (
    id CHAR(21) PRIMARY KEY DEFAULT core.generate_nanoid('TRE'),
    project_code CHAR(2) NOT NULL REFERENCES core.project(project_code),
    tree_number INT NOT NULL,
    donor_id CHAR(21) NOT NULL REFERENCES core.donor(id),
    tree_location GEOGRAPHY(Point, 4326) NOT NULL,
    planted_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB NOT NULL,
    UNIQUE(project_code, tree_number)
);

-- Create file table
CREATE TABLE core.file (
    id CHAR(21) PRIMARY KEY DEFAULT core.generate_nanoid('FIL'),
    file_store VARCHAR(255) NOT NULL,
    file_store_id VARCHAR(1023),
    file_path VARCHAR(1023),
    file_name VARCHAR(255),
    file_type VARCHAR(255),
    file_url VARCHAR(1023),
    file_expiration TIMESTAMPTZ,
    UNIQUE(file_store_id)
);

-- Create tree_update table
CREATE TABLE core.tree_update (
    tree_id CHAR(21) NOT NULL REFERENCES core.tree(id),
    update_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    file_id CHAR(21) NOT NULL REFERENCES core.file(id),
    PRIMARY KEY (tree_id, update_date),
    UNIQUE(tree_id, file_id)
);

-- Create indexes for performance
CREATE INDEX idx_tree_location ON core.tree USING GIST(tree_location);

-- +goose Down
DROP INDEX IF EXISTS core.idx_tree_location;

DROP TABLE IF EXISTS core.tree_update;
DROP TABLE IF EXISTS core.file;
DROP TABLE IF EXISTS core.tree;
DROP TABLE IF EXISTS core.donor;

DROP FUNCTION IF EXISTS core.generate_nanoid;
DROP SCHEMA IF EXISTS core CASCADE;
DROP EXTENSION IF EXISTS postgis CASCADE;