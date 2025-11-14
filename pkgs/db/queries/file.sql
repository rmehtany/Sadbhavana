-- name: UpsertFile :one
INSERT INTO core.file (file_store, file_store_id, file_path, file_name, file_url, file_type, file_expiration)
VALUES(
    sqlc.arg(file_store),
    sqlc.arg(file_store_id),
    sqlc.arg(file_path),
    sqlc.arg(file_name),
    sqlc.arg(file_url),
    sqlc.arg(file_type),
    sqlc.arg(file_expiration)
)
ON CONFLICT (file_store_id) DO UPDATE SET
    file_store = EXCLUDED.file_store,
    file_path = EXCLUDED.file_path,
    file_name = EXCLUDED.file_name,
    file_url = EXCLUDED.file_url,
    file_type = EXCLUDED.file_type,
    file_expiration = EXCLUDED.file_expiration
RETURNING *;

-- name: GetFileByID :one
SELECT *
FROM core.file
WHERE id = sqlc.arg(file_id);

-- name: GetLatestTreeUpdateFile :one
SELECT f.*
FROM core.file AS f
    JOIN core.tree_update AS tu ON f.id = tu.file_id
WHERE tu.tree_id = sqlc.arg(tree_id)
ORDER BY tu.update_date DESC
LIMIT 1;

-- name: GetTreeUpdateFiles :many
SELECT f.*
FROM core.file AS f
    JOIN core.tree_update AS tu ON f.id = tu.file_id
WHERE tu.tree_id = sqlc.arg(tree_id)
ORDER BY tu.update_date DESC;