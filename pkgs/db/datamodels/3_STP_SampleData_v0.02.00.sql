-- Sample Data for Save The Planet (STP) Schema
-- Updated for PostGIS GEOGRAPHY types

---------------------------------------------------------
-- TRUNCATE ALL TABLES (Clear existing data)
-- Note: Order matters due to foreign key dependencies
---------------------------------------------------------
TRUNCATE TABLE stp.u_donorsendlog CASCADE;
TRUNCATE TABLE stp.u_treephoto CASCADE;
TRUNCATE TABLE stp.u_tree CASCADE;
TRUNCATE TABLE stp.u_file CASCADE;
TRUNCATE TABLE stp.u_pledge CASCADE;
TRUNCATE TABLE stp.u_donor CASCADE;
TRUNCATE TABLE stp.u_project CASCADE;
TRUNCATE TABLE stp.u_treetype CASCADE;
TRUNCATE TABLE stp.u_provider CASCADE;
TRUNCATE TABLE stp.u_user CASCADE;

-- Reset identity sequences (optional - ensures IDs start from 1)
ALTER SEQUENCE stp.u_user_userid_seq RESTART WITH 1;
ALTER SEQUENCE stp.u_provider_provideridn_seq RESTART WITH 1;
ALTER SEQUENCE stp.u_treetype_treetypeidn_seq RESTART WITH 1;
ALTER SEQUENCE stp.u_donor_donoridn_seq RESTART WITH 1;
ALTER SEQUENCE stp.u_project_projectidn_seq RESTART WITH 1;
ALTER SEQUENCE stp.u_pledge_pledgeidn_seq RESTART WITH 1;
ALTER SEQUENCE stp.u_tree_treeidn_seq RESTART WITH 1;
ALTER SEQUENCE stp.u_file_fileidn_seq RESTART WITH 1;
ALTER SEQUENCE stp.u_donorsendlog_idn_seq RESTART WITH 1;

---------------------------------------------------------
-- U_User
---------------------------------------------------------
INSERT INTO stp.u_user (username, useridcreator, ts, mobilenumber) VALUES
('admin001', 'system', '2024-01-01', '+91-9900000001'),
('admin002', 'admin001', '2024-01-15', '+91-9900000002'),
('admin003', 'admin001', '2024-02-01', '+91-9900000003'),
('fielduser001', 'admin002', '2024-03-01', '+91-9900000004'),
('fielduser002', 'admin002', '2024-03-15', '+91-9900000005');

---------------------------------------------------------
-- U_Provider
---------------------------------------------------------
INSERT INTO stp.u_provider (providername, authtype, authconfig, accesstoken, refreshtoken, expirets) VALUES
('Google Drive', 'OAuth2', 'client_id=abc123', 'ya29.a0AfH6SMB...', 'rt_1xY2z3...', '2025-12-26 10:30:00'),
('Dropbox', 'OAuth2', 'app_key=xyz789', 'sl.BqwE3rT...', 'rt_9Qw8E7...', '2025-12-26 15:45:00'),
('AWS S3', 'AccessKey', 'bucket=treephotos', 'AKIAIOSFODNN7...', NULL, NULL);

---------------------------------------------------------
-- U_TreeType
---------------------------------------------------------
INSERT INTO stp.u_treetype (treetypename, avglifeyears, propertylist) VALUES
('Oak Tree', 300, '{"carbonOffset": "22kg/year", "height": "20-30m"}'),
('Pine Tree', 150, '{"carbonOffset": "15kg/year", "height": "15-45m"}'),
('Mango Tree', 100, '{"carbonOffset": "18kg/year", "fruit": "true", "height": "10-15m"}'),
('Banyan Tree', 500, '{"carbonOffset": "25kg/year", "height": "20-25m", "sacred": "true"}'),
('Neem Tree', 200, '{"carbonOffset": "20kg/year", "medicinal": "true", "height": "15-20m"}'),
('Teak Tree', 100, '{"carbonOffset": "19kg/year", "timber": "true", "height": "30-40m"}'),
('Bamboo', 40, '{"carbonOffset": "12kg/year", "fastGrowing": "true", "height": "10-20m"}');

---------------------------------------------------------
-- U_Donor
---------------------------------------------------------
INSERT INTO stp.u_donor (donorname, mobilenumber, city, emailaddr, country, state, propertylist, birthdt, userid, ts) VALUES
('Rajesh Kumar', '+91-9876543210', 'Mumbai', 'rajesh.kumar@email.com', 'India', 'Maharashtra', '{"vip": "true", "newsletter": "true"}', '1985-03-15', 'admin001', '2024-01-10 09:00:00'),
('Sarah Johnson', '+1-555-0123', 'New York', 'sarah.j@email.com', 'USA', 'New York', '{"corporate": "true", "company": "TechCorp"}', '1990-07-22', 'admin001', '2024-01-15 10:30:00'),
('Priya Sharma', '+91-9123456789', 'Bangalore', 'priya.sharma@email.com', 'India', 'Karnataka', '{"newsletter": "true"}', '1988-11-30', 'admin002', '2024-02-01 14:20:00'),
('Michael Chen', '+86-138-0000-1234', 'Shanghai', 'michael.chen@email.com', 'China', 'Shanghai', '{"language": "zh", "newsletter": "true"}', '1982-05-18', 'admin001', '2024-02-10 08:45:00'),
('Fatima Al-Sayed', '+971-50-123-4567', 'Dubai', 'fatima.as@email.com', 'UAE', 'Dubai', '{"vip": "true", "corporate": "true"}', '1975-09-08', 'admin003', '2024-03-05 11:00:00'),
('John Smith', '+44-7700-900123', 'London', 'john.smith@email.com', 'UK', 'England', '{"newsletter": "false"}', '1995-12-25', 'admin002', '2024-03-20 16:30:00'),
('Aisha Patel', '+91-9988776655', 'Ahmedabad', 'aisha.patel@email.com', 'India', 'Gujarat', '{"newsletter": "true", "student": "true"}', '2000-01-10', 'admin001', '2024-04-15 09:15:00'),
('Carlos Rodriguez', '+52-55-1234-5678', 'Mexico City', 'carlos.r@email.com', 'Mexico', 'CDMX', '{"language": "es"}', '1978-06-14', 'admin003', '2024-05-01 10:00:00');

---------------------------------------------------------
-- U_Project
-- Note: projectlocation uses GEOGRAPHY(Point, 4326) with ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
---------------------------------------------------------
INSERT INTO stp.u_project (projectname, startdt, projectlocation, treecntpledged, treecntplanted, projectid, propertylist, userid, ts) VALUES
('Green Mumbai Initiative', '2024-01-15', ST_SetSRID(ST_MakePoint(72.8777, 19.0760), 4326), 5000, 3250, 'PROJ-2024-001', '{"sdgGoal": "13,15", "status": "active"}', 'admin001', '2024-01-10 09:00:00'),
('Amazon Reforestation', '2024-02-01', ST_SetSRID(ST_MakePoint(-62.2159, -3.4653), 4326), 10000, 4500, 'PROJ-2024-002', '{"sdgGoal": "15", "status": "active", "partnership": "WWF"}', 'admin001', '2024-01-25 10:30:00'),
('Urban Forest NYC', '2024-03-01', ST_SetSRID(ST_MakePoint(-73.9855, 40.7580), 4326), 2000, 1800, 'PROJ-2024-003', '{"sdgGoal": "11,13", "status": "active", "urban": "true"}', 'admin002', '2024-02-20 14:00:00'),
('Himalayan Conservation', '2024-04-01', ST_SetSRID(ST_MakePoint(79.0193, 30.0668), 4326), 8000, 2100, 'PROJ-2024-004', '{"sdgGoal": "15", "status": "active", "altitude": "high"}', 'admin001', '2024-03-15 08:30:00'),
('Desert Greening Dubai', '2024-05-15', ST_SetSRID(ST_MakePoint(55.2708, 25.2048), 4326), 3000, 1200, 'PROJ-2024-005', '{"sdgGoal": "13,15", "status": "active", "climate": "arid"}', 'admin003', '2024-05-01 11:00:00'),
('School Forest Program', '2024-06-01', ST_SetSRID(ST_MakePoint(77.5946, 12.9716), 4326), 5000, 800, 'PROJ-2024-006', '{"sdgGoal": "4,13", "status": "active", "educational": "true"}', 'admin002', '2024-05-20 09:45:00');

---------------------------------------------------------
-- U_Pledge
---------------------------------------------------------
INSERT INTO stp.u_pledge (projectidn, donoridn, treecntpledged, pledgets, treecntplanted, propertylist) VALUES
(1, 1, 100, '2024-01-15 10:00:00', 100, '{"paymentMethod": "creditCard", "amount": "5000"}'),
(1, 2, 500, '2024-01-20 14:30:00', 450, '{"paymentMethod": "bankTransfer", "amount": "25000", "corporate": "true"}'),
(2, 3, 50, '2024-02-05 09:15:00', 50, '{"paymentMethod": "upi", "amount": "2500"}'),
(2, 4, 200, '2024-02-15 11:45:00', 150, '{"paymentMethod": "wechat", "amount": "10000"}'),
(3, 2, 300, '2024-03-10 16:00:00', 300, '{"paymentMethod": "bankTransfer", "amount": "15000", "corporate": "true"}'),
(3, 6, 25, '2024-03-25 10:30:00', 25, '{"paymentMethod": "paypal", "amount": "1250"}'),
(4, 1, 150, '2024-04-05 08:00:00', 80, '{"paymentMethod": "creditCard", "amount": "7500"}'),
(4, 5, 1000, '2024-04-20 12:00:00', 300, '{"paymentMethod": "bankTransfer", "amount": "50000", "corporate": "true"}'),
(5, 5, 500, '2024-05-18 10:00:00', 200, '{"paymentMethod": "bankTransfer", "amount": "25000"}'),
(5, 8, 75, '2024-05-25 15:30:00', 40, '{"paymentMethod": "creditCard", "amount": "3750"}'),
(6, 7, 30, '2024-06-05 09:00:00', 15, '{"paymentMethod": "upi", "amount": "1500", "student": "true"}'),
(6, 3, 100, '2024-06-10 11:00:00', 20, '{"paymentMethod": "upi", "amount": "5000"}');

---------------------------------------------------------
-- U_Tree
-- Note: treelocation uses GEOGRAPHY(Point, 4326) with ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
---------------------------------------------------------
INSERT INTO stp.u_tree (treelocation, treetypeidn, pledgeidn, titlename, treeid, propertylist) VALUES
-- Pledge 1 (100 trees planted in Mumbai area)
(ST_SetSRID(ST_MakePoint(72.8777, 19.0760), 4326), 1, 1, 'In Memory of Grandpa Kumar', 'TREE-2024-000001', '{"gps": "verified", "qrCode": "QR001"}'),
(ST_SetSRID(ST_MakePoint(72.8779, 19.0762), 4326), 2, 1, NULL, 'TREE-2024-000002', '{"gps": "verified", "qrCode": "QR002"}'),
(ST_SetSRID(ST_MakePoint(72.8781, 19.0765), 4326), 5, 1, NULL, 'TREE-2024-000003', '{"gps": "verified", "qrCode": "QR003"}'),
-- Pledge 2 (450 trees - showing first few in Mumbai)
(ST_SetSRID(ST_MakePoint(72.8785, 19.0770), 4326), 3, 2, 'TechCorp Green Initiative', 'TREE-2024-000101', '{"gps": "verified", "corporate": "true"}'),
(ST_SetSRID(ST_MakePoint(72.8787, 19.0772), 4326), 4, 2, NULL, 'TREE-2024-000102', '{"gps": "verified", "corporate": "true"}'),
(ST_SetSRID(ST_MakePoint(72.8790, 19.0775), 4326), 1, 2, NULL, 'TREE-2024-000103', '{"gps": "verified", "corporate": "true"}'),
-- Pledge 3 (50 trees in Amazon)
(ST_SetSRID(ST_MakePoint(-62.2159, -3.4653), 4326), 2, 3, 'For Future Generations', 'TREE-2024-000201', '{"gps": "verified", "rainforest": "true"}'),
(ST_SetSRID(ST_MakePoint(-62.2161, -3.4655), 4326), 6, 3, NULL, 'TREE-2024-000202', '{"gps": "verified", "rainforest": "true"}'),
-- Pledge 4 (150 trees in Amazon)
(ST_SetSRID(ST_MakePoint(-62.2165, -3.4660), 4326), 1, 4, NULL, 'TREE-2024-000301', '{"gps": "verified"}'),
(ST_SetSRID(ST_MakePoint(-62.2167, -3.4662), 4326), 5, 4, NULL, 'TREE-2024-000302', '{"gps": "verified"}'),
-- Pledge 5 (300 trees in NYC)
(ST_SetSRID(ST_MakePoint(-73.9855, 40.7580), 4326), 2, 5, 'NYC Clean Air Project', 'TREE-2024-000401', '{"gps": "verified", "urban": "true"}'),
(ST_SetSRID(ST_MakePoint(-73.9857, 40.7582), 4326), 7, 5, NULL, 'TREE-2024-000402', '{"gps": "verified", "urban": "true"}'),
-- Pledge 6 (25 trees in NYC)
(ST_SetSRID(ST_MakePoint(-73.9860, 40.7585), 4326), 3, 6, 'Birthday Tree 2024', 'TREE-2024-000501', '{"gps": "verified", "urban": "true"}'),
-- Pledge 7 (80 trees in Himalayas)
(ST_SetSRID(ST_MakePoint(79.0193, 30.0668), 4326), 4, 7, NULL, 'TREE-2024-000601', '{"gps": "verified", "altitude": "1800m"}'),
(ST_SetSRID(ST_MakePoint(79.0195, 30.0670), 4326), 5, 7, NULL, 'TREE-2024-000602', '{"gps": "verified", "altitude": "1750m"}'),
-- Pledge 8 (300 trees in Himalayas)
(ST_SetSRID(ST_MakePoint(79.0197, 30.0672), 4326), 1, 8, 'Corporate Sustainability Initiative', 'TREE-2024-000701', '{"gps": "verified", "corporate": "true"}'),
(ST_SetSRID(ST_MakePoint(79.0200, 30.0675), 4326), 6, 8, NULL, 'TREE-2024-000702', '{"gps": "verified", "corporate": "true"}'),
-- Pledge 9 (200 trees in Dubai)
(ST_SetSRID(ST_MakePoint(55.2708, 25.2048), 4326), 5, 9, NULL, 'TREE-2024-000801', '{"gps": "verified", "irrigation": "drip"}'),
(ST_SetSRID(ST_MakePoint(55.2710, 25.2050), 4326), 3, 9, NULL, 'TREE-2024-000802', '{"gps": "verified", "irrigation": "drip"}'),
-- Pledge 10 (40 trees in Dubai)
(ST_SetSRID(ST_MakePoint(55.2712, 25.2052), 4326), 7, 10, NULL, 'TREE-2024-000901', '{"gps": "verified", "fastGrowing": "true"}'),
-- Pledge 11 (15 trees for School Program)
(ST_SetSRID(ST_MakePoint(72.5714, 23.0225), 4326), 2, 11, 'Student Environmental Club', 'TREE-2024-001001', '{"gps": "verified", "school": "true"}'),
-- Pledge 12 (20 trees for School Program)
(ST_SetSRID(ST_MakePoint(77.5946, 12.9716), 4326), 5, 12, NULL, 'TREE-2024-001101', '{"gps": "verified", "school": "true"}');

---------------------------------------------------------
-- U_File
---------------------------------------------------------
INSERT INTO stp.u_file (filepath, filename, filetype, filestoreid, createdts, provideridn) VALUES
('/photos/2024/01/', 'tree_001_planted.jpg', 'image/jpeg', 'gdrive_abc123xyz', '2024-01-20 10:00:00', 1),
('/photos/2024/01/', 'tree_001_6months.jpg', 'image/jpeg', 'gdrive_def456uvw', '2024-07-20 09:30:00', 1),
('/photos/2024/01/', 'tree_002_planted.jpg', 'image/jpeg', 'gdrive_ghi789rst', '2024-01-21 11:15:00', 1),
('/photos/2024/01/', 'tree_003_planted.jpg', 'image/jpeg', 'dropbox_jkl012mno', '2024-01-22 14:30:00', 2),
('/photos/2024/02/', 'tree_101_planted.jpg', 'image/jpeg', 's3_pqr345stu', '2024-02-10 08:45:00', 3),
('/photos/2024/02/', 'tree_101_3months.jpg', 'image/jpeg', 's3_vwx678yza', '2024-05-10 10:00:00', 3),
('/photos/2024/03/', 'tree_201_planted.jpg', 'image/jpeg', 'gdrive_bcd901efg', '2024-03-15 12:00:00', 1),
('/photos/2024/03/', 'tree_301_planted.jpg', 'image/jpeg', 'dropbox_hij234klm', '2024-03-25 09:15:00', 2),
('/photos/2024/04/', 'tree_401_planted.jpg', 'image/jpeg', 's3_nop567qrs', '2024-04-05 15:30:00', 3),
('/photos/2024/05/', 'tree_501_planted.jpg', 'image/jpeg', 'gdrive_tuv890wxy', '2024-05-20 11:45:00', 1);

---------------------------------------------------------
-- U_TreePhoto
-- Note: photolocation uses GEOGRAPHY(Point, 4326) with ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
---------------------------------------------------------
INSERT INTO stp.u_treephoto (treeidn, uploadts, donorsentts, photolocation, propertylist, fileidn, photots, donoridn, userid) VALUES
(1, '2024-01-20 10:00:00', '2024-01-22 14:30:00', ST_SetSRID(ST_MakePoint(72.8777, 19.0760), 4326), '{"stage": "planted", "photographer": "field_team_01"}', 1, '2024-01-20 09:45:00', 1, 'admin001'),
(1, '2024-07-20 09:30:00', '2024-07-23 10:00:00', ST_SetSRID(ST_MakePoint(72.8777, 19.0760), 4326), '{"stage": "6months", "height": "1.2m", "health": "excellent"}', 2, '2024-07-20 09:00:00', 1, 'admin001'),
(2, '2024-01-21 11:15:00', '2024-01-24 16:45:00', ST_SetSRID(ST_MakePoint(72.8779, 19.0762), 4326), '{"stage": "planted", "photographer": "field_team_01"}', 3, '2024-01-21 11:00:00', 1, 'admin001'),
(3, '2024-01-22 14:30:00', '2024-01-25 09:15:00', ST_SetSRID(ST_MakePoint(72.8781, 19.0765), 4326), '{"stage": "planted", "photographer": "field_team_02"}', 4, '2024-01-22 14:15:00', 1, 'admin002'),
(4, '2024-02-10 08:45:00', '2024-02-12 10:30:00', ST_SetSRID(ST_MakePoint(72.8785, 19.0770), 4326), '{"stage": "planted", "photographer": "corporate_team"}', 5, '2024-02-10 08:30:00', 2, 'admin001'),
(4, '2024-05-10 10:00:00', '2024-05-13 14:00:00', ST_SetSRID(ST_MakePoint(72.8785, 19.0770), 4326), '{"stage": "3months", "height": "0.8m", "health": "good"}', 6, '2024-05-10 09:30:00', 2, 'admin001'),
(7, '2024-03-15 12:00:00', '2024-03-18 11:00:00', ST_SetSRID(ST_MakePoint(-62.2159, -3.4653), 4326), '{"stage": "planted", "photographer": "field_team_03"}', 7, '2024-03-15 11:30:00', 3, 'admin002'),
(9, '2024-03-25 09:15:00', '2024-03-28 15:30:00', ST_SetSRID(ST_MakePoint(-62.2165, -3.4660), 4326), '{"stage": "planted", "photographer": "field_team_04"}', 8, '2024-03-25 09:00:00', 4, 'admin001'),
(11, '2024-04-05 15:30:00', '2024-04-08 10:45:00', ST_SetSRID(ST_MakePoint(-73.9855, 40.7580), 4326), '{"stage": "planted", "photographer": "urban_team"}', 9, '2024-04-05 15:00:00', 2, 'admin002'),
(13, '2024-05-20 11:45:00', '2024-05-23 09:30:00', ST_SetSRID(ST_MakePoint(-73.9860, 40.7585), 4326), '{"stage": "planted", "photographer": "volunteer_01"}', 10, '2024-05-20 11:30:00', 6, 'admin001');

---------------------------------------------------------
-- U_DonorSendLog
---------------------------------------------------------
INSERT INTO stp.u_donorsendlog (treeidn, uploadts, sendts, sendstatus) VALUES
(1, '2024-01-20 10:00:00', '2024-01-22 14:30:00', 'sent'),
(1, '2024-07-20 09:30:00', '2024-07-23 10:00:00', 'sent'),
(2, '2024-01-21 11:15:00', '2024-01-24 16:45:00', 'sent'),
(3, '2024-01-22 14:30:00', '2024-01-25 09:15:00', 'sent'),
(4, '2024-02-10 08:45:00', '2024-02-12 10:30:00', 'sent'),
(4, '2024-05-10 10:00:00', '2024-05-13 14:00:00', 'sent'),
(7, '2024-03-15 12:00:00', '2024-03-18 11:00:00', 'sent'),
(9, '2024-03-25 09:15:00', '2024-03-28 15:30:00', 'sent'),
(11, '2024-04-05 15:30:00', '2024-04-08 10:45:00', 'sent'),
(13, '2024-05-20 11:45:00', '2024-05-23 09:30:00', 'sent'),
-- Some pending sends
(14, '2024-12-20 10:00:00', NULL, 'pending'),
(15, '2024-12-21 11:30:00', NULL, 'pending'),
(16, '2024-12-22 09:15:00', NULL, 'failed');

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