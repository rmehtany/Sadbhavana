-- name: GetTreesByProjectCluster :many
-- Zoom levels 1-8: Get tree counts grouped by project
SELECT 
    t.project_code,
    tw.project_name,
    COUNT(*) as tree_count,
    AVG(ST_Y(t.tree_location::geometry))::FLOAT as center_lat,
    AVG(ST_X(t.tree_location::geometry))::FLOAT as center_lng
FROM core.tree t
JOIN core.project tw ON t.project_code = tw.project_code
WHERE ST_Y(t.tree_location::geometry) BETWEEN sqlc.arg(south_lat) AND sqlc.arg(north_lat)
  AND ST_X(t.tree_location::geometry) BETWEEN sqlc.arg(west_lng) AND sqlc.arg(east_lng)
GROUP BY t.project_code, tw.project_name;

-- name: GetDonorTreesByProjectCluster :many
-- Zoom levels 1-8: Get tree counts grouped by project
SELECT 
    t.project_code,
    tw.project_name,
    COUNT(*) as tree_count,
    AVG(ST_Y(t.tree_location::geometry))::FLOAT as center_lat,
    AVG(ST_X(t.tree_location::geometry))::FLOAT as center_lng
FROM core.tree t
JOIN core.project tw ON t.project_code = tw.project_code
WHERE ST_Y(t.tree_location::geometry) BETWEEN sqlc.arg(south_lat) AND sqlc.arg(north_lat)
  AND ST_X(t.tree_location::geometry) BETWEEN sqlc.arg(west_lng) AND sqlc.arg(east_lng)
  AND t.donor_id = sqlc.arg(donor_id)
GROUP BY t.project_code, tw.project_name;

-- name: GetTreesByGridCluster :many
-- Zoom levels 9-12: Grid-based clustering for medium zoom
WITH params AS (
    SELECT 
        @grid_size::float8 as grid_size,
        @west_lng::float8 as west_lng,
        @south_lat::float8 as south_lat,
        @east_lng::float8 as east_lng,
        @north_lat::float8 as north_lat
)
SELECT 
    ST_Y(ST_SnapToGrid(t.tree_location::geometry, p.grid_size, p.grid_size))::FLOAT as grid_lat,
    ST_X(ST_SnapToGrid(t.tree_location::geometry, p.grid_size, p.grid_size))::FLOAT as grid_lng,
    COUNT(*) as tree_count,
    ARRAY_AGG(t.id)::VARCHAR[] as tree_ids
FROM core.tree t
CROSS JOIN params p
WHERE t.tree_location && ST_MakeEnvelope(p.west_lng, p.south_lat, p.east_lng, p.north_lat, 4326)::geography
GROUP BY ST_SnapToGrid(t.tree_location::geometry, p.grid_size, p.grid_size)
HAVING COUNT(*) > 0;

-- name: GetDonorTreesByGridCluster :many
-- Zoom levels 9-12: Grid-based clustering for medium zoom
WITH params AS (
    SELECT 
        @grid_size::float8 as grid_size,
        @west_lng::float8 as west_lng,
        @south_lat::float8 as south_lat,
        @east_lng::float8 as east_lng,
        @north_lat::float8 as north_lat
)
SELECT 
    ST_Y(ST_SnapToGrid(t.tree_location::geometry, p.grid_size, p.grid_size))::FLOAT as grid_lat,
    ST_X(ST_SnapToGrid(t.tree_location::geometry, p.grid_size, p.grid_size))::FLOAT as grid_lng,
    COUNT(*) as tree_count,
    ARRAY_AGG(t.id)::VARCHAR[] as tree_ids
FROM core.tree t
CROSS JOIN params p
WHERE t.tree_location && ST_MakeEnvelope(p.west_lng, p.south_lat, p.east_lng, p.north_lat, 4326)::geography
    AND t.donor_id = @donor_id::CHAR(21)
GROUP BY ST_SnapToGrid(t.tree_location::geometry, p.grid_size, p.grid_size)
HAVING COUNT(*) > 0;

-- name: GetIndividualTrees :many
-- Zoom levels 13+: Return individual trees with details
SELECT 
    t.id,
    t.project_code,
    t.tree_number,
    t.donor_id,
    ST_Y(t.tree_location::geometry)::FLOAT as latitude,
    ST_X(t.tree_location::geometry)::FLOAT as longitude,
    t.planted_at,
    t.created_at,
    t.metadata,
    d.donor_name,
    tw.project_name
FROM core.tree t
JOIN core.donor d ON t.donor_id = d.id
JOIN core.project tw ON t.project_code = tw.project_code
WHERE ST_Y(t.tree_location::geometry) BETWEEN sqlc.arg(south_lat) AND sqlc.arg(north_lat)
  AND ST_X(t.tree_location::geometry) BETWEEN sqlc.arg(west_lng) AND sqlc.arg(east_lng)
LIMIT sqlc.arg(result_limit);

-- name: GetDonorIndividualTrees :many
-- Zoom levels 13+: Return individual trees with details
SELECT 
    t.id,
    t.project_code,
    t.tree_number,
    t.donor_id,
    ST_Y(t.tree_location::geometry)::FLOAT as latitude,
    ST_X(t.tree_location::geometry)::FLOAT as longitude,
    t.planted_at,
    t.created_at,
    t.metadata,
    d.donor_name,
    tw.project_name
FROM core.tree t
JOIN core.donor d ON t.donor_id = d.id
JOIN core.project tw ON t.project_code = tw.project_code
WHERE ST_Y(t.tree_location::geometry) BETWEEN sqlc.arg(south_lat) AND sqlc.arg(north_lat)
  AND ST_X(t.tree_location::geometry) BETWEEN sqlc.arg(west_lng) AND sqlc.arg(east_lng)
  AND t.donor_id = sqlc.arg(donor_id)
LIMIT sqlc.arg(result_limit);

-- name: GetTreeByID :one
-- Get a single tree by ID with full details
SELECT 
    t.id,
    t.project_code,
    t.tree_number,
    t.donor_id,
    ST_Y(t.tree_location::geometry)::FLOAT as latitude,
    ST_X(t.tree_location::geometry)::FLOAT as longitude,
    t.planted_at,
    t.created_at,
    t.metadata,
    d.donor_name,
    d.phone_number as donor_phone_number,
    tw.project_name,
    tw.metadata as project_metadata
FROM core.tree t
JOIN core.donor d ON t.donor_id = d.id
JOIN core.project tw ON t.project_code = tw.project_code
WHERE t.id = $1;

-- name: CreateTree :one
-- Insert a new tree
INSERT INTO core.tree (
    project_code,
    tree_number,
    donor_id,
    tree_location,
    planted_at,
    metadata
) VALUES (
    $1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, $6, $7
)
RETURNING id, project_code, tree_number, donor_id, planted_at, created_at, metadata;

-- name: GetTreeCount :one
-- Get total tree count, optionally filtered by project
SELECT COUNT(*) as total
FROM core.tree t
WHERE ($1::CHAR(2) IS NULL OR t.project_code = $1);

-- name: GetTreesByProjectCode :many
-- Get all trees in a specific project
SELECT 
    t.id,
    t.tree_number,
    ST_Y(t.tree_location::geometry)::FLOAT as latitude,
    ST_X(t.tree_location::geometry)::FLOAT as longitude,
    t.planted_at,
    t.metadata,
    d.donor_name
FROM core.tree t
JOIN core.donor d ON t.donor_id = d.id
WHERE t.project_code = $1
ORDER BY t.tree_number;

-- name: GetClusterDetail :one
-- Get detailed statistics for a project cluster
SELECT 
    tw.project_code,
    tw.project_name,
    tw.metadata as project_metadata,
    COUNT(t.id) as tree_count,
    AVG(ST_Y(t.tree_location::geometry))::FLOAT as center_lat,
    AVG(ST_X(t.tree_location::geometry))::FLOAT as center_lng,
    MIN(t.planted_at)::timestamptz as first_planted,
    MAX(t.planted_at)::timestamptz as last_planted,
    COUNT(DISTINCT t.donor_id) as unique_donors
FROM core.project tw
LEFT JOIN core.tree t ON tw.project_code = t.project_code
WHERE tw.project_code = sqlc.arg(project_code)
GROUP BY tw.project_code, tw.project_name, tw.metadata;

-- name: GetDonorClusterDetail :one
-- Get detailed statistics for a project cluster
SELECT 
    tw.project_code,
    tw.project_name,
    tw.metadata as project_metadata,
    COUNT(t.id) as tree_count,
    AVG(ST_Y(t.tree_location::geometry))::FLOAT as center_lat,
    AVG(ST_X(t.tree_location::geometry))::FLOAT as center_lng,
    MIN(t.planted_at)::timestamptz as first_planted,
    MAX(t.planted_at)::timestamptz as last_planted,
    COUNT(DISTINCT t.donor_id) as unique_donors
FROM core.project tw
LEFT JOIN core.tree t ON tw.project_code = t.project_code
WHERE tw.project_code = sqlc.arg(project_code)
  AND t.donor_id = sqlc.arg(donor_id)
GROUP BY tw.project_code, tw.project_name, tw.metadata;