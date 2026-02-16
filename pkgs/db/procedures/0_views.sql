-- Database Views for Sadbhavana Tree Project (STP)
-- This file provides views for easier data retrieval and analysis.

-- 1. stp.V_Project - Project summary with latitude/longitude
CREATE OR REPLACE VIEW stp.V_Project AS
SELECT 
    projectidn,
    projectid,
    projectname,
    startdt,
    treecntpledged,
    treecntplanted,
    ST_Y(projectlocation::geometry) AS latitude,
    ST_X(projectlocation::geometry) AS longitude,
    propertylist,
    useridn,
    ts
FROM stp.u_project;

-- 2. stp.V_Donor - Donor summary
CREATE OR REPLACE VIEW stp.V_Donor AS
SELECT 
    donoridn,
    mobilenumber,
    donorname,
    emailaddr,
    city,
    country,
    birthdt,
    propertylist,
    useridn,
    ts
FROM stp.u_donor;

-- 3. stp.V_Pledge - Pledge summary joined with Project and Donor
CREATE OR REPLACE VIEW stp.V_Pledge AS
SELECT 
    p.pledgeidn,
    p.pledgets,
    p.treecntpledged,
    p.treecntplanted,
    p.pledgecredit,
    p.propertylist AS pledge_propertylist,
    p.useridn AS pledge_useridn,
    -- Project details
    pr.projectidn,
    pr.projectid,
    pr.projectname,
    -- Donor details
    d.donoridn,
    d.donorname,
    d.mobilenumber,
    d.emailaddr
FROM stp.u_pledge p
    JOIN stp.u_project pr 
        ON p.projectidn = pr.projectidn
    JOIN stp.u_donor d 
        ON p.donoridn = d.donoridn;

-- 4. stp.V_Tree - Individual tree details with Project, Donor and TreeType
CREATE OR REPLACE VIEW stp.V_Tree AS
SELECT 
    t.treeidn,
    t.treeid,
    t.creditname,
    ST_Y(t.treelocation::geometry) AS latitude,
    ST_X(t.treelocation::geometry) AS longitude,
    t.propertylist AS tree_propertylist,
    -- Tree Type details
    tt.treetypeidn,
    tt.treetypename,
    -- Pledge/Project/Donor context
    p.pledgeidn,
    pr.projectid,
    pr.projectname,
    d.donorname,
    d.mobilenumber
FROM stp.u_tree t
    JOIN stp.u_treetype tt 
        ON t.treetypeidn = tt.treetypeidn
    JOIN stp.u_pledge p 
        ON t.pledgeidn = p.pledgeidn
    JOIN stp.u_project pr 
        ON p.projectidn = pr.projectidn
    JOIN stp.u_donor d 
        ON p.donoridn = d.donoridn;

-- 5. stp.V_TreePhoto - Photo details with Tree, File and Provider info
CREATE OR REPLACE VIEW stp.V_TreePhoto AS
SELECT 
    tp.treeidn,
    tp.uploadts,
    tp.photots,
    ST_Y(tp.photolocation::geometry) AS photo_latitude,
    ST_X(tp.photolocation::geometry) AS photo_longitude,
    tp.propertylist AS photo_propertylist,
    tp.useridn AS photo_useridn,
    -- Tree details
    t.treeid,
    -- File details
    f.fileidn,
    f.filestoreid,
    f.filepath,
    f.filename,
    f.filetype,
    -- Provider details
    prov.provideridn,
    prov.providername
FROM stp.u_treephoto tp
    JOIN stp.u_tree t 
        ON tp.treeidn = t.treeidn
    JOIN stp.u_file f 
        ON tp.fileidn = f.fileidn
    JOIN stp.u_provider prov 
        ON f.provideridn = prov.provideridn;
