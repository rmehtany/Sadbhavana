-- Enhanced test data for tree map application
-- Multiple Indian cities with dense tree coverage

-- Insert test projects (Indian cities across multiple states)
INSERT INTO core.project (project_code, project_name, metadata) VALUES
-- Gujarat
('JM', 'Jamnagar', '{"state": "Gujarat", "population": 679000, "district": "Jamnagar", "known_for": "Oil refineries, Bandhani textiles"}'),
('RJ', 'Rajkot', '{"state": "Gujarat", "population": 1390640, "district": "Rajkot", "known_for": "Watson Museum, Mahatma Gandhi childhood home"}'),
('JV', 'Jamvanathali', '{"state": "Gujarat", "population": 2148, "district": "Jamnagar", "known_for": "Rural village in Saurashtra"}'),
('AM', 'Amreli', '{"state": "Gujarat", "population": 103466, "district": "Amreli", "known_for": "Groundnut, cotton production"}'),
('ND', 'Nadiad', '{"state": "Gujarat", "population": 225071, "district": "Kheda", "known_for": "Santram Mandir, educational hub"}'),
('AH', 'Ahmedabad', '{"state": "Gujarat", "population": 5577940, "district": "Ahmedabad", "known_for": "Sabarmati Ashram, UNESCO World Heritage City"}'),
('SU', 'Surat', '{"state": "Gujarat", "population": 4467797, "district": "Surat", "known_for": "Diamond cutting, textile industry"}'),
('VD', 'Vadodara', '{"state": "Gujarat", "population": 1670806, "district": "Vadodara", "known_for": "Laxmi Vilas Palace, MS University"}'),

-- Maharashtra
('MU', 'Mumbai', '{"state": "Maharashtra", "population": 12442373, "district": "Mumbai", "known_for": "Bollywood, Gateway of India"}'),
('PU', 'Pune', '{"state": "Maharashtra", "population": 3124458, "district": "Pune", "known_for": "IT hub, educational institutions"}'),
('NG', 'Nagpur', '{"state": "Maharashtra", "population": 2405421, "district": "Nagpur", "known_for": "Orange city, RSS headquarters"}'),
('NS', 'Nashik', '{"state": "Maharashtra", "population": 1486053, "district": "Nashik", "known_for": "Wine capital, Kumbh Mela"}'),

-- Karnataka
('BG', 'Bengaluru', '{"state": "Karnataka", "population": 8443675, "district": "Bengaluru Urban", "known_for": "IT capital, Garden city"}'),
('MY', 'Mysuru', '{"state": "Karnataka", "population": 920550, "district": "Mysuru", "known_for": "Mysore Palace, silk sarees"}'),
('MN', 'Mangaluru', '{"state": "Karnataka", "population": 484785, "district": "Dakshina Kannada", "known_for": "Port city, educational hub"}'),

-- Tamil Nadu
('CH', 'Chennai', '{"state": "Tamil Nadu", "population": 4646732, "district": "Chennai", "known_for": "Marina Beach, automobile industry"}'),
('CO', 'Coimbatore', '{"state": "Tamil Nadu", "population": 1050721, "district": "Coimbatore", "known_for": "Manchester of South India, textiles"}'),
('MD', 'Madurai', '{"state": "Tamil Nadu", "population": 1017865, "district": "Madurai", "known_for": "Meenakshi Temple, jasmine"}'),

-- Rajasthan
('JP', 'Jaipur', '{"state": "Rajasthan", "population": 3046163, "district": "Jaipur", "known_for": "Pink City, Amber Fort"}'),
('JO', 'Jodhpur', '{"state": "Rajasthan", "population": 1033918, "district": "Jodhpur", "known_for": "Blue City, Mehrangarh Fort"}'),
('UD', 'Udaipur', '{"state": "Rajasthan", "population": 451100, "district": "Udaipur", "known_for": "City of Lakes, palaces"}'),

-- Kerala
('KO', 'Kochi', '{"state": "Kerala", "population": 677381, "district": "Ernakulam", "known_for": "Queen of Arabian Sea, spice trade"}'),
('TV', 'Thiruvananthapuram', '{"state": "Kerala", "population": 957730, "district": "Thiruvananthapuram", "known_for": "Padmanabhaswamy Temple, IT parks"}'),
('KZ', 'Kozhikode', '{"state": "Kerala", "population": 609224, "district": "Kozhikode", "known_for": "Spice trade history, beaches"}')

ON CONFLICT (project_code) DO NOTHING;

-- Insert test donors (expanded list with Indian names)
INSERT INTO core.donor (donor_name, phone_number) VALUES
('Ramesh Patel', '9825123456'),
('Priya Shah', '9879234567'),
('Vikram Desai', '9898345678'),
('Anita Mehta', '9825456789'),
('Jayesh Joshi', '9879567890'),
('Lakshmi Iyer', '9876543210'),
('Arjun Reddy', '9845123456'),
('Kavita Sharma', '9987654321'),
('Rajesh Kumar', '9123456789'),
('Deepa Nair', '9944556677'),
('Suresh Rao', '9822334455'),
('Meera Gupta', '9711223344'),
('Anil Verma', '9988776655'),
('Pooja Singh', '9876512345'),
('Kiran Menon', '9745123456'),
('Sanjay Agarwal', '9821112233'),
('Neha Kapoor', '9810998877'),
('Ravi Krishnan', '9876667788'),
('Sneha Jain', '9823334455'),
('Manoj Pillai', '9947889900')
ON CONFLICT DO NOTHING;

-- Insert test trees with realistic distribution
-- Using various native Indian tree species

WITH donor_ids AS (
    SELECT id, donor_name FROM core.donor
),
tree_species AS (
    SELECT * FROM (VALUES
        ('Neem', 'Azadirachta indica'),
        ('Banyan', 'Ficus benghalensis'),
        ('Peepal', 'Ficus religiosa'),
        ('Mango', 'Mangifera indica'),
        ('Jamun', 'Syzygium cumini'),
        ('Tamarind', 'Tamarindus indica'),
        ('Babool', 'Acacia nilotica'),
        ('Pongamia', 'Pongamia pinnata'),
        ('Indian Coral Tree', 'Erythrina indica'),
        ('Teak', 'Tectona grandis'),
        ('Gulmohar', 'Delonix regia'),
        ('Ashoka', 'Saraca asoca'),
        ('Coconut', 'Cocos nucifera'),
        ('Jackfruit', 'Artocarpus heterophyllus'),
        ('Sandalwood', 'Santalum album'),
        ('Arjuna', 'Terminalia arjuna')
    ) AS species(common_name, scientific_name)
)
INSERT INTO core.tree (project_code, tree_number, donor_id, tree_location, planted_at, metadata)
SELECT 
    tree_data.project_code,
    tree_data.tree_number,
    tree_data.donor_id,
    ST_SetSRID(ST_MakePoint(tree_data.lng, tree_data.lat), 4326)::geography,
    tree_data.planted_at,
    tree_data.metadata::jsonb
FROM (
    -- Jamnagar (70.0577, 22.4707) - 25 trees in 1km radius
    SELECT 'JM'::CHAR(2), 1, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0577, 22.4707, '2024-01-15'::timestamptz, '{"species": "Neem", "scientific_name": "Azadirachta indica", "height": "4.5m"}'::text
    UNION ALL SELECT 'JM', 2, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0612, 22.4765, '2024-01-16', '{"species": "Banyan", "scientific_name": "Ficus benghalensis", "height": "3.6m"}'
    UNION ALL SELECT 'JM', 3, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0489, 22.4689, '2024-01-17', '{"species": "Peepal", "scientific_name": "Ficus religiosa", "height": "6m"}'
    UNION ALL SELECT 'JM', 4, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0651, 22.4589, '2024-01-18', '{"species": "Teak", "scientific_name": "Tectona grandis", "height": "4m"}'
    UNION ALL SELECT 'JM', 5, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0735, 22.4614, '2024-01-19', '{"species": "Mango", "scientific_name": "Mangifera indica", "height": "3.3m"}'
    UNION ALL SELECT 'JM', 6, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0399, 22.4505, '2024-01-20', '{"species": "Gulmohar", "scientific_name": "Delonix regia", "height": "7.6m"}'
    UNION ALL SELECT 'JM', 7, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0523, 22.4812, '2024-01-21', '{"species": "Jamun", "scientific_name": "Syzygium cumini", "height": "5.1m"}'
    UNION ALL SELECT 'JM', 8, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0688, 22.4701, '2024-01-22', '{"species": "Tamarind", "scientific_name": "Tamarindus indica", "height": "4.8m"}'
    UNION ALL SELECT 'JM', 9, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0445, 22.4623, '2024-01-23', '{"species": "Neem", "scientific_name": "Azadirachta indica", "height": "5.2m"}'
    UNION ALL SELECT 'JM', 10, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0589, 22.4778, '2024-01-24', '{"species": "Peepal", "scientific_name": "Ficus religiosa", "height": "3.9m"}'
    UNION ALL SELECT 'JM', 11, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0634, 22.4656, '2024-01-25', '{"species": "Banyan", "scientific_name": "Ficus benghalensis", "height": "4.7m"}'
    UNION ALL SELECT 'JM', 12, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0512, 22.4734, '2024-01-26', '{"species": "Ashoka", "scientific_name": "Saraca asoca", "height": "3.5m"}'
    UNION ALL SELECT 'JM', 13, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0667, 22.4589, '2024-01-27', '{"species": "Mango", "scientific_name": "Mangifera indica", "height": "6.2m"}'
    UNION ALL SELECT 'JM', 14, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0423, 22.4767, '2024-01-28', '{"species": "Gulmohar", "scientific_name": "Delonix regia", "height": "5.4m"}'
    UNION ALL SELECT 'JM', 15, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0701, 22.4723, '2024-01-29', '{"species": "Teak", "scientific_name": "Tectona grandis", "height": "4.3m"}'
    UNION ALL SELECT 'JM', 16, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0556, 22.4645, '2024-01-30', '{"species": "Jamun", "scientific_name": "Syzygium cumini", "height": "5.8m"}'
    UNION ALL SELECT 'JM', 17, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0478, 22.4712, '2024-01-31', '{"species": "Neem", "scientific_name": "Azadirachta indica", "height": "4.1m"}'
    UNION ALL SELECT 'JM', 18, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0623, 22.4801, '2024-02-01', '{"species": "Pongamia", "scientific_name": "Pongamia pinnata", "height": "6.7m"}'
    UNION ALL SELECT 'JM', 19, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0534, 22.4567, '2024-02-02', '{"species": "Babool", "scientific_name": "Acacia nilotica", "height": "3.8m"}'
    UNION ALL SELECT 'JM', 20, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0689, 22.4634, '2024-02-03', '{"species": "Tamarind", "scientific_name": "Tamarindus indica", "height": "5.5m"}'
    UNION ALL SELECT 'JM', 21, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0412, 22.4689, '2024-02-04', '{"species": "Peepal", "scientific_name": "Ficus religiosa", "height": "4.9m"}'
    UNION ALL SELECT 'JM', 22, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0598, 22.4723, '2024-02-05', '{"species": "Banyan", "scientific_name": "Ficus benghalensis", "height": "5.3m"}'
    UNION ALL SELECT 'JM', 23, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0645, 22.4678, '2024-02-06', '{"species": "Mango", "scientific_name": "Mangifera indica", "height": "4.6m"}'
    UNION ALL SELECT 'JM', 24, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0467, 22.4745, '2024-02-07', '{"species": "Gulmohar", "scientific_name": "Delonix regia", "height": "6.1m"}'
    UNION ALL SELECT 'JM', 25, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.0712, 22.4656, '2024-02-08', '{"species": "Ashoka", "scientific_name": "Saraca asoca", "height": "3.7m"}'
    
    -- Rajkot (70.7867, 22.3039) - 30 trees
    UNION ALL SELECT 'RJ', 1, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7867, 22.3039, '2024-01-15', '{"species": "Mango", "scientific_name": "Mangifera indica", "height": "5.5m"}'
    UNION ALL SELECT 'RJ', 2, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.8022, 22.2895, '2024-01-16', '{"species": "Jamun", "scientific_name": "Syzygium cumini", "height": "3m"}'
    UNION ALL SELECT 'RJ', 3, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7756, 22.3101, '2024-01-17', '{"species": "Tamarind", "scientific_name": "Tamarindus indica", "height": "4.8m"}'
    UNION ALL SELECT 'RJ', 4, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7923, 22.2967, '2024-01-18', '{"species": "Neem", "scientific_name": "Azadirachta indica", "height": "5.2m"}'
    UNION ALL SELECT 'RJ', 5, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7812, 22.3123, '2024-01-19', '{"species": "Peepal", "scientific_name": "Ficus religiosa", "height": "6.3m"}'
    UNION ALL SELECT 'RJ', 6, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7989, 22.2912, '2024-01-20', '{"species": "Banyan", "scientific_name": "Ficus benghalensis", "height": "4.1m"}'
    UNION ALL SELECT 'RJ', 7, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7701, 22.3056, '2024-01-21', '{"species": "Gulmohar", "scientific_name": "Delonix regia", "height": "5.7m"}'
    UNION ALL SELECT 'RJ', 8, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7845, 22.2978, '2024-01-22', '{"species": "Teak", "scientific_name": "Tectona grandis", "height": "4.4m"}'
    UNION ALL SELECT 'RJ', 9, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7934, 22.3089, '2024-01-23', '{"species": "Ashoka", "scientific_name": "Saraca asoca", "height": "3.6m"}'
    UNION ALL SELECT 'RJ', 10, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7778, 22.2945, '2024-01-24', '{"species": "Mango", "scientific_name": "Mangifera indica", "height": "5.9m"}'
    UNION ALL SELECT 'RJ', 11, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.8056, 22.3012, '2024-01-25', '{"species": "Jamun", "scientific_name": "Syzygium cumini", "height": "4.2m"}'
    UNION ALL SELECT 'RJ', 12, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7834, 22.3145, '2024-01-26', '{"species": "Neem", "scientific_name": "Azadirachta indica", "height": "5.4m"}'
    UNION ALL SELECT 'RJ', 13, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7723, 22.2989, '2024-01-27', '{"species": "Peepal", "scientific_name": "Ficus religiosa", "height": "4.7m"}'
    UNION ALL SELECT 'RJ', 14, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7967, 22.3067, '2024-01-28', '{"species": "Tamarind", "scientific_name": "Tamarindus indica", "height": "5.1m"}'
    UNION ALL SELECT 'RJ', 15, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7889, 22.2923, '2024-01-29', '{"species": "Banyan", "scientific_name": "Ficus benghalensis", "height": "6.5m"}'
    UNION ALL SELECT 'RJ', 16, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7745, 22.3134, '2024-01-30', '{"species": "Gulmohar", "scientific_name": "Delonix regia", "height": "4.9m"}'
    UNION ALL SELECT 'RJ', 17, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.8011, 22.2956, '2024-01-31', '{"species": "Teak", "scientific_name": "Tectona grandis", "height": "3.8m"}'
    UNION ALL SELECT 'RJ', 18, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7856, 22.3098, '2024-02-01', '{"species": "Pongamia", "scientific_name": "Pongamia pinnata", "height": "5.6m"}'
    UNION ALL SELECT 'RJ', 19, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7912, 22.2934, '2024-02-02', '{"species": "Mango", "scientific_name": "Mangifera indica", "height": "4.3m"}'
    UNION ALL SELECT 'RJ', 20, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7789, 22.3023, '2024-02-03', '{"species": "Jamun", "scientific_name": "Syzygium cumini", "height": "5.8m"}'
    UNION ALL SELECT 'RJ', 21, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.8034, 22.3078, '2024-02-04', '{"species": "Neem", "scientific_name": "Azadirachta indica", "height": "4.5m"}'
    UNION ALL SELECT 'RJ', 22, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7767, 22.2967, '2024-02-05', '{"species": "Peepal", "scientific_name": "Ficus religiosa", "height": "6.1m"}'
    UNION ALL SELECT 'RJ', 23, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7901, 22.3112, '2024-02-06', '{"species": "Ashoka", "scientific_name": "Saraca asoca", "height": "3.9m"}'
    UNION ALL SELECT 'RJ', 24, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7823, 22.2945, '2024-02-07', '{"species": "Banyan", "scientific_name": "Ficus benghalensis", "height": "5.3m"}'
    UNION ALL SELECT 'RJ', 25, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7978, 22.3045, '2024-02-08', '{"species": "Gulmohar", "scientific_name": "Delonix regia", "height": "4.6m"}'
    UNION ALL SELECT 'RJ', 26, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7734, 22.3089, '2024-02-09', '{"species": "Tamarind", "scientific_name": "Tamarindus indica", "height": "5.7m"}'
    UNION ALL SELECT 'RJ', 27, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7945, 22.2989, '2024-02-10', '{"species": "Mango", "scientific_name": "Mangifera indica", "height": "4.8m"}'
    UNION ALL SELECT 'RJ', 28, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7878, 22.3156, '2024-02-11', '{"species": "Teak", "scientific_name": "Tectona grandis", "height": "3.7m"}'
    UNION ALL SELECT 'RJ', 29, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.7812, 22.2912, '2024-02-12', '{"species": "Jamun", "scientific_name": "Syzygium cumini", "height": "5.2m"}'
    UNION ALL SELECT 'RJ', 30, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 70.8001, 22.3101, '2024-02-13', '{"species": "Neem", "scientific_name": "Azadirachta indica", "height": "4.1m"}'

    -- Mumbai (72.8777, 19.0760) - 40 trees
    UNION ALL SELECT 'MU', 1, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8777, 19.0760, '2024-01-10', '{"species": "Coconut", "scientific_name": "Cocos nucifera", "height": "8.2m"}'
    UNION ALL SELECT 'MU', 2, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8823, 19.0812, '2024-01-11', '{"species": "Gulmohar", "scientific_name": "Delonix regia", "height": "6.5m"}'
    UNION ALL SELECT 'MU', 3, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8734, 19.0698, '2024-01-12', '{"species": "Banyan", "scientific_name": "Ficus benghalensis", "height": "7.1m"}'
    UNION ALL SELECT 'MU', 4, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8856, 19.0789, '2024-01-13', '{"species": "Ashoka", "scientific_name": "Saraca asoca", "height": "4.3m"}'
    UNION ALL SELECT 'MU', 5, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8712, 19.0823, '2024-01-14', '{"species": "Peepal", "scientific_name": "Ficus religiosa", "height": "5.8m"}'
    UNION ALL SELECT 'MU', 6, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8801, 19.0745, '2024-01-15', '{"species": "Mango", "scientific_name": "Mangifera indica", "height": "5.4m"}'
    UNION ALL SELECT 'MU', 7, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8767, 19.0834, '2024-01-16', '{"species": "Neem", "scientific_name": "Azadirachta indica", "height": "4.9m"}'
    UNION ALL SELECT 'MU', 8, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8845, 19.0723, '2024-01-17', '{"species": "Coconut", "scientific_name": "Cocos nucifera", "height": "7.6m"}'
    UNION ALL SELECT 'MU', 9, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8723, 19.0789, '2024-01-18', '{"species": "Jamun", "scientific_name": "Syzygium cumini", "height": "5.1m"}'
    UNION ALL SELECT 'MU', 10, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8812, 19.0801, '2024-01-19', '{"species": "Gulmohar", "scientific_name": "Delonix regia", "height": "6.3m"}'
    UNION ALL SELECT 'MU', 11, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8745, 19.0712, '2024-01-20', '{"species": "Tamarind", "scientific_name": "Tamarindus indica", "height": "4.7m"}'
    UNION ALL SELECT 'MU', 12, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8878, 19.0767, '2024-01-21', '{"species": "Banyan", "scientific_name": "Ficus benghalensis", "height": "6.8m"}'
    UNION ALL SELECT 'MU', 13, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8756, 19.0845, '2024-01-22', '{"species": "Peepal", "scientific_name": "Ficus religiosa", "height": "5.5m"}'
    UNION ALL SELECT 'MU', 14, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8834, 19.0734, '2024-01-23', '{"species": "Ashoka", "scientific_name": "Saraca asoca", "height": "4.1m"}'
    UNION ALL SELECT 'MU', 15, (SELECT id FROM donor_ids ORDER BY RANDOM() LIMIT 1), 72.8701, 19.0778, '2024-01-24', '{"species": "Mango", "scientific_name": "Mangifera indica", "height": "5.9m"}'

) AS tree_data (project_code, tree_number, donor_id, lng, lat, planted_at, metadata);

