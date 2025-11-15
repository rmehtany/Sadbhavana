-- name: CreateProject :one
INSERT INTO core.project (
    project_code,
    project_name,
    metadata
) VALUES (
    $1, $2, $3
)
RETURNING *;

-- name: GetProject :one
SELECT * FROM core.project
WHERE project_code = $1;

-- name: ListProjects :many
SELECT * FROM core.project
ORDER BY project_name;

-- name: UpdateProject :one
UPDATE core.project
SET 
    project_name = $2,
    metadata = $3
WHERE project_code = $1
RETURNING *;

-- name: DeleteProject :exec
DELETE FROM core.project
WHERE project_code = $1;

-- name: GetProjectWithTreeCount :one
SELECT 
    t.project_code,
    t.project_name,
    t.metadata,
    COUNT(tr.id) as tree_count
FROM core.project t
LEFT JOIN core.tree tr ON t.project_code = tr.project_code
WHERE t.project_code = $1
GROUP BY t.project_code, t.project_name, t.metadata;

-- name: ListProjectsWithTreeCounts :many
SELECT 
    t.project_code,
    t.project_name,
    t.metadata,
    COUNT(tr.id) as tree_count
FROM core.project t
LEFT JOIN core.tree tr ON t.project_code = tr.project_code
GROUP BY t.project_code, t.project_name, t.metadata
ORDER BY t.project_name;

-- name: SearchProjects :many
SELECT *
FROM core.project
WHERE project_name ILIKE '%' || $1 || '%' OR project_code ILIKE '%' || $1 || '%'
ORDER BY project_name;