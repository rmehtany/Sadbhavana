-- name: CreateTown :one
INSERT INTO core.town (
    town_code,
    town_name,
    metadata
) VALUES (
    $1, $2, $3
)
RETURNING *;

-- name: GetTown :one
SELECT * FROM core.town
WHERE town_code = $1;

-- name: ListTowns :many
SELECT * FROM core.town
ORDER BY town_name;

-- name: UpdateTown :one
UPDATE core.town
SET 
    town_name = $2,
    metadata = $3
WHERE town_code = $1
RETURNING *;

-- name: DeleteTown :exec
DELETE FROM core.town
WHERE town_code = $1;

-- name: GetTownWithTreeCount :one
SELECT 
    t.town_code,
    t.town_name,
    t.metadata,
    COUNT(tr.id) as tree_count
FROM core.town t
LEFT JOIN core.tree tr ON t.town_code = tr.town_code
WHERE t.town_code = $1
GROUP BY t.town_code, t.town_name, t.metadata;

-- name: ListTownsWithTreeCounts :many
SELECT 
    t.town_code,
    t.town_name,
    t.metadata,
    COUNT(tr.id) as tree_count
FROM core.town t
LEFT JOIN core.tree tr ON t.town_code = tr.town_code
GROUP BY t.town_code, t.town_name, t.metadata
ORDER BY t.town_name;