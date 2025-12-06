-- name: CreateTreeUpdate :one
-- Insert a new tree update
INSERT INTO
    core.tree_update (tree_id, file_id)
VALUES ($1, $2) ON CONFLICT (file_id) DO
UPDATE
SET
    file_id = EXCLUDED.file_id RETURNING tree_id,
    update_date,
    file_id;

-- name: GetLatestTreeUpdate :one
-- Get the most recent update for a tree
SELECT tu.tree_id, tu.update_date, tu.file_id, f.file_store, f.file_store_id, f.file_path, f.file_name, f.file_type, f.file_expiration
FROM core.tree_update tu
    JOIN core.file f ON tu.file_id = f.id
WHERE
    tu.tree_id = $1
ORDER BY tu.update_date DESC
LIMIT 1;