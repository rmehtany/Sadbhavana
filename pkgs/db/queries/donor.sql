-- name: CreateDonor :one
-- Insert a new donor
INSERT INTO core.donor (
    donor_name,
    email
) VALUES (
    $1, $2
)
RETURNING id, donor_name, email;

-- name: GetDonor :one
-- Get a single donor by ID
SELECT id, donor_name, email
FROM core.donor
WHERE id = $1;

-- name: GetDonorByEmail :one
-- Get a donor by email
SELECT id, donor_name, email
FROM core.donor
WHERE email = $1;

-- name: ListDonors :many
-- Get all donors
SELECT id, donor_name, email
FROM core.donor
ORDER BY donor_name;

-- name: UpdateDonor :one
-- Update donor information
UPDATE core.donor
SET 
    donor_name = $2,
    email = $3
WHERE id = $1
RETURNING id, donor_name, email;

-- name: GetDonorWithTreeCount :one
-- Get donor with their tree count
SELECT 
    d.id,
    d.donor_name,
    d.email,
    COUNT(t.id) as tree_count
FROM core.donor d
LEFT JOIN core.tree t ON d.id = t.donor_id
WHERE d.id = $1
GROUP BY d.id, d.donor_name, d.email;

-- name: ListDonorsWithTreeCounts :many
-- Get all donors with their tree counts
SELECT 
    d.id,
    d.donor_name,
    d.email,
    COUNT(t.id) as tree_count
FROM core.donor d
LEFT JOIN core.tree t ON d.id = t.donor_id
GROUP BY d.id, d.donor_name, d.email
ORDER BY tree_count DESC, d.donor_name;