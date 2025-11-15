-- name: CreateDonor :one
-- Insert a new donor
INSERT INTO core.donor (
    donor_name,
    phone_number
) VALUES (
    $1, $2
)
RETURNING id, donor_name, phone_number;

-- name: GetDonor :one
-- Get a single donor by ID
SELECT id, donor_name, phone_number
FROM core.donor
WHERE id = $1;

-- name: GetDonorByPhoneNumber :one
-- Get a donor by phone_number
SELECT id, donor_name, phone_number
FROM core.donor
WHERE phone_number = $1;

-- name: ListDonors :many
-- Get all donors
SELECT id, donor_name, phone_number
FROM core.donor
ORDER BY donor_name;

-- name: UpdateDonor :one
-- Update donor information
UPDATE core.donor
SET 
    donor_name = $2,
    phone_number = $3
WHERE id = $1
RETURNING id, donor_name, phone_number;

-- name: GetDonorWithTreeCount :one
-- Get donor with their tree count
SELECT 
    d.id,
    d.donor_name,
    d.phone_number,
    COUNT(t.id) as tree_count
FROM core.donor d
LEFT JOIN core.tree t ON d.id = t.donor_id
WHERE d.id = $1
GROUP BY d.id, d.donor_name, d.phone_number;

-- name: ListDonorsWithTreeCounts :many
-- Get all donors with their tree counts
SELECT 
    d.id,
    d.donor_name,
    d.phone_number,
    COUNT(t.id) as tree_count
FROM core.donor d
LEFT JOIN core.tree t ON d.id = t.donor_id
GROUP BY d.id, d.donor_name, d.phone_number
ORDER BY tree_count DESC, d.donor_name;

-- name: SearchDonors :many
-- Search donors by name or phone number
SELECT id, donor_name, phone_number
FROM core.donor
WHERE donor_name ILIKE '%' || $1 || '%' OR phone_number ILIKE '%' || $1 || '%'
ORDER BY donor_name;