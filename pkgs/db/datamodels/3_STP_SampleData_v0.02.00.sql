-- Sample Data for Save The Planet (STP) Schema
-- Updated for PostGIS GEOGRAPHY types

---------------------------------------------------------
-- TRUNCATE ALL TABLES (Clear existing data)
-- Note: Order matters due to foreign key dependencies
---------------------------------------------------------
TRUNCATE TABLE stp.u_donorsendlog RESTART IDENTITY;
TRUNCATE TABLE stp.u_treephoto RESTART IDENTITY;
TRUNCATE TABLE stp.u_tree RESTART IDENTITY;
TRUNCATE TABLE stp.u_file RESTART IDENTITY;
TRUNCATE TABLE stp.u_pledge RESTART IDENTITY;
TRUNCATE TABLE stp.u_donor RESTART IDENTITY;
TRUNCATE TABLE stp.u_project RESTART IDENTITY;
TRUNCATE TABLE stp.u_treetype RESTART IDENTITY;
TRUNCATE TABLE stp.u_provider RESTART IDENTITY;
TRUNCATE TABLE stp.u_user RESTART IDENTITY;

-- Sample Data for Tree Planting Database Schema
-- Run this after creating the schema structure

---------------------------------------------------------
-- U_User - Insert users first (referenced by other tables)
---------------------------------------------------------
INSERT INTO stp.u_user (username, mobilenumber, useridncreator, ts) VALUES
('admin', '+1-555-0100', NULL, '2024-01-01 10:00:00'),
('john_doe', '+1-555-0101', 1, '2024-01-15 09:30:00'),
('jane_smith', '+1-555-0102', 1, '2024-01-20 14:00:00'),
('mike_wilson', '+1-555-0103', 1, '2024-02-01 11:00:00'),
('sarah_jones', '+1-555-0104', 1, '2024-02-10 16:30:00');

---------------------------------------------------------
-- U_Provider - Cloud storage providers
---------------------------------------------------------
INSERT INTO stp.u_provider (providername, authtype, authconfig, accesstoken, refreshtoken, expirets) VALUES
('AWS S3', 'OAuth2', '{"region":"us-east-1","bucket":"tree-photos"}', 'aws_access_token_123', 'aws_refresh_token_123', '2025-12-31 23:59:59'),
('Google Cloud Storage', 'OAuth2', '{"project":"tree-project","bucket":"tree-images"}', 'gcp_access_token_456', 'gcp_refresh_token_456', '2025-12-31 23:59:59'),
('Azure Blob Storage', 'OAuth2', '{"account":"treeproject","container":"photos"}', 'azure_access_token_789', 'azure_refresh_token_789', '2025-12-31 23:59:59');

---------------------------------------------------------
-- U_TreeType - Different tree species
---------------------------------------------------------
INSERT INTO stp.u_treetype (treetypename, avglifeyears, propertylist) VALUES
('Oak', 300, '{"scientific_name":"Quercus","growth_rate":"slow","height":"20-30m"}'),
('Pine', 150, '{"scientific_name":"Pinus","growth_rate":"medium","height":"15-45m"}'),
('Maple', 100, '{"scientific_name":"Acer","growth_rate":"medium","height":"10-25m"}'),
('Birch', 80, '{"scientific_name":"Betula","growth_rate":"fast","height":"12-20m"}'),
('Cedar', 200, '{"scientific_name":"Cedrus","growth_rate":"slow","height":"30-40m"}'),
('Willow', 75, '{"scientific_name":"Salix","growth_rate":"fast","height":"10-20m"}'),
('Eucalyptus', 250, '{"scientific_name":"Eucalyptus","growth_rate":"fast","height":"30-55m"}'),
('Mango', 100, '{"scientific_name":"Mangifera indica","growth_rate":"medium","height":"10-40m"}');

---------------------------------------------------------
-- U_Donor - People who donate/sponsor trees
---------------------------------------------------------
INSERT INTO stp.u_donor (donorname, mobilenumber, city, emailaddr, country, state, birthdt, propertylist, useridn, ts) VALUES
('Robert Anderson', '+1-555-1001', 'Seattle', 'robert.anderson@email.com', 'USA', 'Washington', '1985-03-15', '{"donor_level":"gold","preferences":"oak,pine"}', 2, '2024-03-01 10:00:00'),
('Emily Chen', '+1-555-1002', 'San Francisco', 'emily.chen@email.com', 'USA', 'California', '1990-07-22', '{"donor_level":"platinum","preferences":"all"}', 2, '2024-03-05 14:30:00'),
('David Kumar', '+91-98765-43210', 'Mumbai', 'david.kumar@email.com', 'India', 'Maharashtra', '1988-11-10', '{"donor_level":"silver","preferences":"mango,eucalyptus"}', 3, '2024-03-10 09:15:00'),
('Maria Garcia', '+34-612-345-678', 'Madrid', 'maria.garcia@email.com', 'Spain', 'Madrid', '1992-05-30', '{"donor_level":"gold","preferences":"cedar,oak"}', 3, '2024-03-15 16:45:00'),
('James Wilson', '+44-7700-900123', 'London', 'james.wilson@email.com', 'UK', 'England', '1983-09-18', '{"donor_level":"bronze","preferences":"birch,maple"}', 4, '2024-03-20 11:20:00'),
('Lisa Thompson', '+1-555-1003', 'Portland', 'lisa.thompson@email.com', 'USA', 'Oregon', '1995-12-05', '{"donor_level":"silver","preferences":"pine,willow"}', 4, '2024-03-25 13:00:00'),
('Ahmed Hassan', '+20-100-123-4567', 'Cairo', 'ahmed.hassan@email.com', 'Egypt', 'Cairo', '1987-04-25', '{"donor_level":"gold","preferences":"eucalyptus"}', 5, '2024-04-01 10:30:00'),
('Sophie Dubois', '+33-6-12-34-56-78', 'Paris', 'sophie.dubois@email.com', 'France', 'Île-de-France', '1991-08-14', '{"donor_level":"platinum","preferences":"oak,cedar"}', 5, '2024-04-05 15:15:00');

---------------------------------------------------------
-- U_Project - Tree planting projects in different locations
---------------------------------------------------------
INSERT INTO stp.u_project (projectid, projectname, projectlocation, startdt, treecntpledged, treecntplanted, propertylist, useridn, ts) VALUES
('PROJ001', 'Pacific Northwest Forest Restoration', ST_GeogFromText('POINT(-122.3321 47.6062)'), '2024-04-01', 1000, 250, '{"area_hectares":50,"target_species":"oak,pine,cedar"}', 2, '2024-03-01 09:00:00'),
('PROJ002', 'California Coastal Reforestation', ST_GeogFromText('POINT(-122.4194 37.7749)'), '2024-05-01', 750, 180, '{"area_hectares":35,"target_species":"eucalyptus,pine"}', 2, '2024-03-10 10:30:00'),
('PROJ003', 'Mumbai Urban Green Initiative', ST_GeogFromText('POINT(72.8777 19.0760)'), '2024-03-15', 500, 320, '{"area_hectares":20,"target_species":"mango,eucalyptus"}', 3, '2024-03-05 11:00:00'),
('PROJ004', 'Spanish Mountain Regreening', ST_GeogFromText('POINT(-3.7038 40.4168)'), '2024-06-01', 600, 150, '{"area_hectares":40,"target_species":"oak,cedar"}', 3, '2024-03-12 14:00:00'),
('PROJ005', 'Thames Valley Woodland Project', ST_GeogFromText('POINT(-0.1276 51.5074)'), '2024-07-01', 400, 95, '{"area_hectares":25,"target_species":"birch,maple,oak"}', 4, '2024-03-18 09:30:00');

---------------------------------------------------------
-- U_Pledge - Donor commitments to projects
---------------------------------------------------------
INSERT INTO stp.u_pledge (projectidn, donoridn, pledgets, treecntpledged, treecntplanted, pledgecredit, propertylist, useridn) VALUES
(1, 1, '2024-03-15 10:00:00', 100, 25, '{"Robert Anderson": 50, "Anderson Family": 30, "Memorial Fund": 20}', '{"payment_method":"credit_card","recurring":false}', 2),
(1, 2, '2024-03-18 14:30:00', 200, 50, '{"Emily Chen": 120, "Chen Corporation": 80}', '{"payment_method":"paypal","recurring":true}', 2),
(2, 2, '2024-03-20 11:00:00', 150, 40, '{"Emily Chen": 100, "Tech For Trees Initiative": 50}', '{"payment_method":"paypal","recurring":true}', 2),
(3, 3, '2024-03-22 09:15:00', 120, 80, '{"David Kumar": 70, "Kumar Enterprises": 50}', '{"payment_method":"upi","recurring":false}', 3),
(4, 4, '2024-03-25 16:45:00', 80, 30, '{"Maria Garcia": 50, "Garcia & Associates": 30}', '{"payment_method":"bank_transfer","recurring":false}', 3),
(5, 5, '2024-03-28 11:20:00', 60, 15, '{"James Wilson": 35, "Wilson Family Trust": 25}', '{"payment_method":"credit_card","recurring":false}', 4),
(1, 6, '2024-04-01 13:00:00', 90, 20, '{"Lisa Thompson": 60, "Green Portland Fund": 30}', '{"payment_method":"credit_card","recurring":false}', 4),
(3, 7, '2024-04-03 10:30:00', 100, 65, '{"Ahmed Hassan": 100}', '{"payment_method":"bank_transfer","recurring":false}', 5),
(4, 8, '2024-04-05 15:15:00', 110, 50, '{"Sophie Dubois": 60, "Dubois Foundation": 50}', '{"payment_method":"credit_card","recurring":true}', 5),
(2, 1, '2024-04-08 10:00:00', 75, 20, '{"Robert Anderson": 40, "In Memory of John Anderson": 35}', '{"payment_method":"credit_card","recurring":false}', 2);

---------------------------------------------------------
-- U_Tree - Individual planted trees
---------------------------------------------------------
INSERT INTO stp.u_tree (treelocation, treetypeidn, pledgeidn, creditname, treeid, propertylist) VALUES
-- Trees for Project 1, Pledge 1 (Robert Anderson, 25 trees)
(ST_GeogFromText('POINT(-122.3325 47.6065)'), 1, 1, 'Robert Anderson', 'TREE-P1-001', '{"planted_date":"2024-04-15","health":"excellent"}'),
(ST_GeogFromText('POINT(-122.3328 47.6068)'), 2, 1, 'Robert Anderson', 'TREE-P1-002', '{"planted_date":"2024-04-15","health":"good"}'),
(ST_GeogFromText('POINT(-122.3330 47.6070)'), 5, 1, 'Robert Anderson', 'TREE-P1-003', '{"planted_date":"2024-04-16","health":"excellent"}'),
-- Trees for Project 1, Pledge 2 (Emily Chen, 50 trees)
(ST_GeogFromText('POINT(-122.3335 47.6075)'), 1, 2, 'Emily Chen', 'TREE-P1-004', '{"planted_date":"2024-04-20","health":"excellent"}'),
(ST_GeogFromText('POINT(-122.3338 47.6078)'), 2, 2, 'Emily Chen', 'TREE-P1-005', '{"planted_date":"2024-04-20","health":"good"}'),
(ST_GeogFromText('POINT(-122.3340 47.6080)'), 1, 2, 'Emily Chen', 'TREE-P1-006', '{"planted_date":"2024-04-21","health":"excellent"}'),
-- Trees for Project 2, Pledge 3 (Emily Chen, 40 trees)
(ST_GeogFromText('POINT(-122.4198 37.7752)'), 7, 3, 'Emily Chen', 'TREE-P2-001', '{"planted_date":"2024-05-10","health":"excellent"}'),
(ST_GeogFromText('POINT(-122.4200 37.7755)'), 2, 3, 'Emily Chen', 'TREE-P2-002', '{"planted_date":"2024-05-10","health":"good"}'),
-- Trees for Project 3, Pledge 4 (David Kumar, 80 trees)
(ST_GeogFromText('POINT(72.8780 19.0763)'), 8, 4, 'David Kumar', 'TREE-P3-001', '{"planted_date":"2024-03-25","health":"excellent"}'),
(ST_GeogFromText('POINT(72.8783 19.0766)'), 7, 4, 'David Kumar', 'TREE-P3-002', '{"planted_date":"2024-03-25","health":"excellent"}'),
(ST_GeogFromText('POINT(72.8786 19.0769)'), 8, 4, 'David Kumar', 'TREE-P3-003', '{"planted_date":"2024-03-26","health":"good"}'),
-- Trees for Project 4, Pledge 5 (Maria Garcia, 30 trees)
(ST_GeogFromText('POINT(-3.7040 40.4170)'), 1, 5, 'Maria Garcia', 'TREE-P4-001', '{"planted_date":"2024-06-15","health":"excellent"}'),
(ST_GeogFromText('POINT(-3.7043 40.4173)'), 5, 5, 'Maria Garcia', 'TREE-P4-002', '{"planted_date":"2024-06-15","health":"good"}'),
-- Trees for Project 5, Pledge 6 (James Wilson, 15 trees)
(ST_GeogFromText('POINT(-0.1278 51.5076)'), 4, 6, 'James Wilson', 'TREE-P5-001', '{"planted_date":"2024-07-20","health":"excellent"}'),
(ST_GeogFromText('POINT(-0.1280 51.5078)'), 3, 6, 'James Wilson', 'TREE-P5-002', '{"planted_date":"2024-07-20","health":"good"}'),
-- Trees for Project 1, Pledge 7 (Lisa Thompson, 20 trees)
(ST_GeogFromText('POINT(-122.3345 47.6085)'), 2, 7, 'Lisa Thompson', 'TREE-P1-007', '{"planted_date":"2024-04-25","health":"excellent"}'),
(ST_GeogFromText('POINT(-122.3348 47.6088)'), 6, 7, 'Lisa Thompson', 'TREE-P1-008', '{"planted_date":"2024-04-25","health":"good"}'),
-- Trees for Project 3, Pledge 8 (Ahmed Hassan, 65 trees)
(ST_GeogFromText('POINT(72.8789 19.0772)'), 7, 8, 'Ahmed Hassan', 'TREE-P3-004', '{"planted_date":"2024-04-10","health":"excellent"}'),
(ST_GeogFromText('POINT(72.8792 19.0775)'), 8, 8, 'Ahmed Hassan', 'TREE-P3-005', '{"planted_date":"2024-04-10","health":"excellent"}'),
-- Trees for Project 4, Pledge 9 (Sophie Dubois, 50 trees)
(ST_GeogFromText('POINT(-3.7046 40.4176)'), 1, 9, 'Sophie Dubois', 'TREE-P4-003', '{"planted_date":"2024-06-20","health":"excellent"}'),
(ST_GeogFromText('POINT(-3.7049 40.4179)'), 5, 9, 'Sophie Dubois', 'TREE-P4-004', '{"planted_date":"2024-06-20","health":"good"}');

---------------------------------------------------------
-- U_File - Photo files
---------------------------------------------------------
INSERT INTO stp.u_file (filepath, filename, filetype, filestoreid, createdts, provideridn) VALUES
('/photos/2024/04/', 'tree_photo_001.jpg', 'image/jpeg', 's3://tree-photos/001.jpg', '2024-04-16 10:00:00', 1),
('/photos/2024/04/', 'tree_photo_002.jpg', 'image/jpeg', 's3://tree-photos/002.jpg', '2024-04-16 10:05:00', 1),
('/photos/2024/04/', 'tree_photo_003.jpg', 'image/jpeg', 's3://tree-photos/003.jpg', '2024-04-17 14:30:00', 1),
('/photos/2024/04/', 'tree_photo_004.jpg', 'image/jpeg', 's3://tree-photos/004.jpg', '2024-04-22 11:00:00', 1),
('/photos/2024/05/', 'tree_photo_005.jpg', 'image/jpeg', 'gcs://tree-images/005.jpg', '2024-05-11 09:15:00', 2),
('/photos/2024/05/', 'tree_photo_006.jpg', 'image/jpeg', 'gcs://tree-images/006.jpg', '2024-05-11 09:20:00', 2),
('/photos/2024/03/', 'tree_photo_007.jpg', 'image/jpeg', 'gcs://tree-images/007.jpg', '2024-03-26 16:00:00', 2),
('/photos/2024/03/', 'tree_photo_008.jpg', 'image/jpeg', 'gcs://tree-images/008.jpg', '2024-03-27 10:30:00', 2),
('/photos/2024/06/', 'tree_photo_009.jpg', 'image/jpeg', 'azure://photos/009.jpg', '2024-06-16 13:45:00', 3),
('/photos/2024/06/', 'tree_photo_010.jpg', 'image/jpeg', 'azure://photos/010.jpg', '2024-06-21 15:20:00', 3);

---------------------------------------------------------
-- U_TreePhoto - Photos of planted trees
---------------------------------------------------------
INSERT INTO stp.u_treephoto (treeidn, uploadts, donorsentts, photolocation, propertylist, fileidn, photots, donoridn, useridn) VALUES
(1, '2024-04-16 10:00:00', '2024-04-17 08:00:00', ST_GeogFromText('POINT(-122.3325 47.6065)'), '{"quality":"high","camera":"iPhone 13"}', 1, '2024-04-15 14:30:00', 1, 2),
(2, '2024-04-16 10:05:00', '2024-04-17 08:05:00', ST_GeogFromText('POINT(-122.3328 47.6068)'), '{"quality":"high","camera":"iPhone 13"}', 2, '2024-04-15 14:35:00', 1, 2),
(3, '2024-04-17 14:30:00', '2024-04-18 09:00:00', ST_GeogFromText('POINT(-122.3330 47.6070)'), '{"quality":"medium","camera":"iPhone 13"}', 3, '2024-04-16 16:00:00', 1, 2),
(4, '2024-04-22 11:00:00', '2024-04-23 10:00:00', ST_GeogFromText('POINT(-122.3335 47.6075)'), '{"quality":"high","camera":"Samsung S21"}', 4, '2024-04-20 15:20:00', 2, 2),
(7, '2024-05-11 09:15:00', '2024-05-12 08:30:00', ST_GeogFromText('POINT(-122.4198 37.7752)'), '{"quality":"high","camera":"Samsung S21"}', 5, '2024-05-10 13:45:00', 2, 2),
(8, '2024-05-11 09:20:00', NULL, ST_GeogFromText('POINT(-122.4200 37.7755)'), '{"quality":"medium","camera":"Samsung S21"}', 6, '2024-05-10 13:50:00', 2, 2),
(9, '2024-03-26 16:00:00', '2024-03-27 09:00:00', ST_GeogFromText('POINT(72.8780 19.0763)'), '{"quality":"high","camera":"OnePlus 9"}', 7, '2024-03-25 11:20:00', 3, 3),
(10, '2024-03-27 10:30:00', '2024-03-28 08:15:00', ST_GeogFromText('POINT(72.8783 19.0766)'), '{"quality":"high","camera":"OnePlus 9"}', 8, '2024-03-25 11:25:00', 3, 3),
(12, '2024-06-16 13:45:00', '2024-06-17 10:00:00', ST_GeogFromText('POINT(-3.7040 40.4170)'), '{"quality":"high","camera":"Google Pixel 6"}', 9, '2024-06-15 14:30:00', 4, 3),
(20, '2024-06-21 15:20:00', NULL, ST_GeogFromText('POINT(-3.7046 40.4176)'), '{"quality":"excellent","camera":"Canon EOS R5"}', 10, '2024-06-20 16:00:00', 8, 5);

---------------------------------------------------------
-- U_DonorSendLog - Log of photo notifications sent to donors
---------------------------------------------------------
INSERT INTO stp.u_donorsendlog (treeidn, uploadts, sendts, sendstatus) VALUES
(1, '2024-04-16 10:00:00', '2024-04-17 08:00:00', 'sent'),
(2, '2024-04-16 10:05:00', '2024-04-17 08:05:00', 'sent'),
(3, '2024-04-17 14:30:00', '2024-04-18 09:00:00', 'sent'),
(4, '2024-04-22 11:00:00', '2024-04-23 10:00:00', 'sent'),
(7, '2024-05-11 09:15:00', '2024-05-12 08:30:00', 'sent'),
(8, '2024-05-11 09:20:00', NULL, 'pending'),
(9, '2024-03-26 16:00:00', '2024-03-27 09:00:00', 'sent'),
(10, '2024-03-27 10:30:00', '2024-03-28 08:15:00', 'sent'),
(12, '2024-06-16 13:45:00', '2024-06-17 10:00:00', 'sent'),
(20, '2024-06-21 15:20:00', NULL, 'pending');

-- Sample queries to verify the data:
-- SELECT * FROM stp.u_user;
-- SELECT * FROM stp.u_donor;
-- SELECT * FROM stp.u_project;
-- SELECT * FROM stp.u_pledge;
-- SELECT * FROM stp.u_tree;
-- SELECT * FROM stp.u_treephoto;

-- Summary query to see totals:
-- SELECT 
--     (SELECT COUNT(*) FROM stp.u_user) as total_users,
--     (SELECT COUNT(*) FROM stp.u_donor) as total_donors,
--     (SELECT COUNT(*) FROM stp.u_project) as total_projects,
--     (SELECT COUNT(*) FROM stp.u_pledge) as total_pledges,
--     (SELECT COUNT(*) FROM stp.u_tree) as total_trees,
--     (SELECT COUNT(*) FROM stp.u_treephoto) as total_photos;
---------------------------------------------------------
-- Sample Queries to Verify PostGIS Geography Data
---------------------------------------------------------

-- Query 1: Get projects with their locations in human-readable format
-- SELECT projectidn, projectname, 
--        ST_X(projectlocation::geometry) as longitude,
--        ST_Y(projectlocation::geometry) as latitude
-- FROM stp.u_project;

-- Query 2: Find trees within 10km of a specific point (e.g., Mumbai center)
-- SELECT treeidn, treeid, 
--        ST_Distance(treelocation, ST_SetSRID(ST_MakePoint(72.8777, 19.0760), 4326)) as distance_meters
-- FROM stp.u_tree
-- WHERE ST_DWithin(treelocation, ST_SetSRID(ST_MakePoint(72.8777, 19.0760), 4326), 10000)
-- ORDER BY distance_meters;

-- Query 3: Calculate distance between donor location and their trees
-- SELECT d.donorname, t.treeid,
--        ST_Distance(
--          ST_SetSRID(ST_MakePoint(72.8777, 19.0760), 4326), 
--          t.treelocation
--        ) / 1000 as distance_km
-- FROM stp.u_donor d
-- JOIN stp.u_pledge p ON d.donoridn = p.donoridn
-- JOIN stp.u_tree t ON p.pledgeidn = t.pledgeidn
-- WHERE d.donoridn = 1
-- LIMIT 5;