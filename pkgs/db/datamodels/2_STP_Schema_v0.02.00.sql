create extension if not exists postgis;
create extension if not exists dblink;
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- PostgreSQL version

-- Schema (if not already created)
CREATE SCHEMA IF NOT EXISTS stp;

---------------------------------------------------------
-- U_Donor
---------------------------------------------------------
drop table if exists stp.u_donor;
CREATE TABLE stp.u_donor (
    donoridn      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    donorname     varchar(128) NOT NULL,
    mobilenumber  varchar(128) NOT NULL,
    city          varchar(64) NOT NULL,
    emailaddr     varchar(64),
    country       varchar(64) NOT NULL,
    state         varchar(64) NOT NULL,
    propertylist  varchar(256) NOT NULL,
    birthdt       date,
    userid        varchar(32) NOT NULL,
    ts            timestamp
);

---------------------------------------------------------
-- U_DonorSendLog
---------------------------------------------------------
drop table if exists stp.u_donorsendlog;
CREATE TABLE stp.u_donorsendlog (
    idn          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    treeidn      integer NOT NULL,
    uploadts     timestamp NOT NULL,
    sendts       timestamp,
    sendstatus   varchar(64)
);

---------------------------------------------------------
-- U_File
---------------------------------------------------------
drop table if exists stp.u_file;
CREATE TABLE stp.u_file (
    fileidn      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    filepath     varchar(64),
    filename     varchar(64) NOT NULL,
    filetype     varchar(64) NOT NULL,
    filestoreid  varchar(64),
    createdts    timestamp NOT NULL,
    provideridn  integer NOT NULL
);

---------------------------------------------------------
-- U_Pledge
---------------------------------------------------------
drop table if exists stp.u_pledge;
CREATE TABLE stp.u_pledge (
    pledgeidn        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    projectidn       integer NOT NULL,
    donoridn         integer NOT NULL,
    treecntpledged   integer,
    pledgets         timestamp NOT NULL,
    treecntplanted   integer,
    propertylist     varchar(256) NOT NULL
);

CREATE UNIQUE INDEX xak1u_pledge
    ON stp.u_pledge (projectidn, donoridn, pledgets);

---------------------------------------------------------
-- U_Project
---------------------------------------------------------
drop table if exists stp.u_project;
CREATE TABLE stp.u_project (
    projectidn       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    projectname      varchar(128) NOT NULL,
    startdt          date NOT NULL,
    projectlocation  GEOGRAPHY(Point, 4326) NOT NULL,
    treecntpledged   integer,
    treecntplanted   integer,
    projectid        varchar(64) NOT NULL,
    propertylist     varchar(256) NOT NULL,
    userid           varchar(32) NOT NULL,
    ts               timestamp NOT NULL
);

CREATE UNIQUE INDEX xak1u_project
    ON stp.u_project (projectid);

---------------------------------------------------------
-- U_Provider
---------------------------------------------------------
drop table if exists stp.u_provider;
CREATE TABLE stp.u_provider (
    provideridn   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    providername  varchar(64) NOT NULL,
    authtype      varchar(64),
    authconfig    varchar(64),
    accesstoken   varchar(64),
    refreshtoken  varchar(64),
    expirets      timestamp
);

---------------------------------------------------------
-- U_Tree
---------------------------------------------------------
drop table if exists stp.u_tree;
CREATE TABLE stp.u_tree (
    treeidn       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    treelocation  GEOGRAPHY(Point, 4326) NOT NULL,
    treetypeidn   integer NOT NULL,
    pledgeidn     integer NOT NULL,
    titlename     varchar(64),
    treeid        varchar(64) NOT NULL,
    propertylist  varchar(256) NOT NULL
);

CREATE UNIQUE INDEX xak1u_tree
    ON stp.u_tree (treeid);

---------------------------------------------------------
-- U_TreePhoto
---------------------------------------------------------
drop table if exists stp.u_treephoto;
CREATE TABLE stp.u_treephoto (
    treeidn        integer NOT NULL,
    uploadts       timestamp NOT NULL,
    donorsentts    timestamp,
    photolocation  GEOGRAPHY(Point, 4326) NOT NULL,
    propertylist   varchar(256) NOT NULL,
    fileidn        integer NOT NULL,
    photots        timestamp NOT NULL,
    donoridn       integer NOT NULL,
    userid         varchar(32) NOT NULL,
    PRIMARY KEY (treeidn, uploadts)
);

---------------------------------------------------------
-- U_TreeType
---------------------------------------------------------
drop table if exists stp.u_treetype;
CREATE TABLE stp.u_treetype (
    treetypeidn    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    treetypename   varchar(128) NOT NULL,
    avglifeyears   integer,
    propertylist   varchar(256) NOT NULL
);

---------------------------------------------------------
-- U_User
---------------------------------------------------------
drop table if exists stp.u_user;
CREATE TABLE stp.u_user (
    userid          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username        char(18),
    useridcreator   char(18),
    ts              char(18),
    mobilenumber    char(18)
);