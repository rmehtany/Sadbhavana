-- name: CreateFile :one
-- Insert a new file record
INSERT INTO core.file (
    file_store,
    file_store_id,
    file_path,
    file_name,
    file_type,
    file_expiration
) VALUES (
    $1, $2, $3, $4, $5, $6
)
RETURNING id, file_store, file_store_id, file_path, file_name, file_type, file_expiration;

-- name: GetFile :one
-- Get a file by ID
SELECT id, file_store, file_store_id, file_path, file_name, file_type, file_expiration
FROM core.file
WHERE id = $1;

-- name: CreateTreeUpdate :one
-- Insert a new tree update
INSERT INTO core.tree_update (
    tree_id,
    update_date,
    file_id
) VALUES (
    $1, $2, $3
)
RETURNING tree_id, update_date, file_id;

-- name: GetTreeUpdates :many
-- Get all updates for a specific tree
SELECT 
    tu.tree_id,
    tu.update_date,
    tu.file_id,
    f.file_store,
    f.file_store_id,
    f.file_path,
    f.file_name,
    f.file_type,
    f.file_expiration
FROM core.tree_update tu
JOIN core.file f ON tu.file_id = f.id
WHERE tu.tree_id = $1
ORDER BY tu.update_date DESC;

-- name: GetLatestTreeUpdate :one
-- Get the most recent update for a tree
SELECT 
    tu.tree_id,
    tu.update_date,
    tu.file_id,
    f.file_store,
    f.file_store_id,
    f.file_path,
    f.file_name,
    f.file_type,
    f.file_expiration
FROM core.tree_update tu
JOIN core.file f ON tu.file_id = f.id
WHERE tu.tree_id = $1
ORDER BY tu.update_date DESC
LIMIT 1;

-- name: DeleteTreeUpdate :exec
-- Delete a specific tree update
DELETE FROM core.tree_update
WHERE tree_id = $1 AND update_date = $2;

-- name: GetRecentUpdates :many
-- Get recent updates across all trees
SELECT 
    tu.tree_id,
    tu.update_date,
    tu.file_id,
    t.tree_number,
    t.project_code,
    tw.project_name,
    f.file_name,
    f.file_path
FROM core.tree_update tu
JOIN core.tree t ON tu.tree_id = t.id
JOIN core.project tw ON t.project_code = tw.project_code
JOIN core.file f ON tu.file_id = f.id
ORDER BY tu.update_date DESC
LIMIT $1;

-- name: GetTreesWithUpdateCount :many
-- Get trees with their update counts
SELECT 
    t.id,
    t.tree_number,
    t.project_code,
    tw.project_name,
    COUNT(tu.file_id) as update_count,
    MAX(tu.update_date) as last_updated
FROM core.tree t
JOIN core.project tw ON t.project_code = tw.project_code
LEFT JOIN core.tree_update tu ON t.id = tu.tree_id
WHERE ($1::CHAR(2) IS NULL OR t.project_code = $1)
GROUP BY t.id, t.tree_number, t.project_code, tw.project_name
ORDER BY last_updated DESC NULLS LAST;