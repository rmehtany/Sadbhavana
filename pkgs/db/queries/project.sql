-- name: CreateProject :one
INSERT INTO core.project (
    project_code,
    project_name,
    metadata
) VALUES (
    $1, $2, $3
)
RETURNING *;

-- name: SearchProjects :many
SELECT *
FROM core.project
WHERE project_name ILIKE '%' || $1 || '%' OR project_code ILIKE '%' || $1 || '%'
ORDER BY project_name;