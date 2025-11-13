-- name: GetTreesByTownCluster :many
-- Zoom levels 1-8: Get tree counts grouped by town
SELECT 
    t.town_code,
    tw.town_name,
    COUNT(*) as tree_count,
    AVG(ST_Y(t.tree_location::geometry))::FLOAT as center_lat,
    AVG(ST_X(t.tree_location::geometry))::FLOAT as center_lng
FROM core.tree t
JOIN core.town tw ON t.town_code = tw.town_code
WHERE ST_Y(t.tree_location::geometry) BETWEEN sqlc.arg(south_lat) AND sqlc.arg(north_lat)
  AND ST_X(t.tree_location::geometry) BETWEEN sqlc.arg(west_lng) AND sqlc.arg(east_lng)
GROUP BY t.town_code, tw.town_name;

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

-- name: GetIndividualTrees :many
-- Zoom levels 13+: Return individual trees with details
SELECT 
    t.id,
    t.town_code,
    t.tree_number,
    t.donor_id,
    ST_Y(t.tree_location::geometry)::FLOAT as latitude,
    ST_X(t.tree_location::geometry)::FLOAT as longitude,
    t.planted_at,
    t.created_at,
    t.metadata,
    d.donor_name,
    tw.town_name
FROM core.tree t
JOIN core.donor d ON t.donor_id = d.id
JOIN core.town tw ON t.town_code = tw.town_code
WHERE ST_Y(t.tree_location::geometry) BETWEEN sqlc.arg(south_lat) AND sqlc.arg(north_lat)
  AND ST_X(t.tree_location::geometry) BETWEEN sqlc.arg(west_lng) AND sqlc.arg(east_lng)
LIMIT sqlc.arg(result_limit);

-- name: GetTreeByID :one
-- Get a single tree by ID with full details
SELECT 
    t.id,
    t.town_code,
    t.tree_number,
    t.donor_id,
    ST_Y(t.tree_location::geometry)::FLOAT as latitude,
    ST_X(t.tree_location::geometry)::FLOAT as longitude,
    t.planted_at,
    t.created_at,
    t.metadata,
    d.donor_name,
    d.email as donor_email,
    tw.town_name,
    tw.metadata as town_metadata
FROM core.tree t
JOIN core.donor d ON t.donor_id = d.id
JOIN core.town tw ON t.town_code = tw.town_code
WHERE t.id = $1;

-- name: CreateTree :one
-- Insert a new tree
INSERT INTO core.tree (
    town_code,
    tree_number,
    donor_id,
    tree_location,
    planted_at,
    metadata
) VALUES (
    $1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, $6, $7
)
RETURNING id, town_code, tree_number, donor_id, planted_at, created_at, metadata;

-- name: GetTreeCount :one
-- Get total tree count, optionally filtered by town
SELECT COUNT(*) as total
FROM core.tree t
WHERE ($1::CHAR(2) IS NULL OR t.town_code = $1);

-- name: GetTreesByTownCode :many
-- Get all trees in a specific town
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
WHERE t.town_code = $1
ORDER BY t.tree_number;

-- name: GetClusterDetail :one
-- Get detailed statistics for a town cluster
SELECT 
    tw.town_code,
    tw.town_name,
    tw.metadata as town_metadata,
    COUNT(t.id) as tree_count,
    AVG(ST_Y(t.tree_location::geometry))::FLOAT as center_lat,
    AVG(ST_X(t.tree_location::geometry))::FLOAT as center_lng,
    MIN(t.planted_at)::timestamptz as first_planted,
    MAX(t.planted_at)::timestamptz as last_planted,
    COUNT(DISTINCT t.donor_id) as unique_donors
FROM core.town tw
LEFT JOIN core.tree t ON tw.town_code = t.town_code
WHERE tw.town_code = sqlc.arg(town_code)
GROUP BY tw.town_code, tw.town_name, tw.metadata;