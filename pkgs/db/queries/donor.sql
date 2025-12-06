-- name: CreateDonor :one
-- Insert a new donor
INSERT INTO core.donor (
    donor_name,
    phone_number
) VALUES (
    $1, $2
)
RETURNING id, donor_name, phone_number;

-- name: SearchDonors :many
-- Search donors by name or phone number
SELECT id, donor_name, phone_number
FROM core.donor
WHERE donor_name ILIKE '%' || $1 || '%' OR phone_number ILIKE '%' || $1 || '%'
ORDER BY donor_name;