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

-- name: GetTreeByProjectCodeAndNumber :one
-- Get a single tree by project code and tree number
SELECT 
    t.id,
    t.project_code,
    t.tree_number,
    t.donor_id,
    ST_Y(t.tree_location::geometry)::FLOAT as latitude,
    ST_X(t.tree_location::geometry)::FLOAT as longitude,
    t.planted_at,
    t.created_at,
    t.metadata
FROM core.tree t
WHERE t.project_code = $1 AND t.tree_number = $2;

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