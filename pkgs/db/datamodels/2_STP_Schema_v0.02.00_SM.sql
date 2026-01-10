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
    mobilenumber  varchar(64) NOT NULL,
    emailaddr     varchar(64),
    city          varchar(64) NOT NULL,
    country       varchar(64) NOT NULL,
    state         varchar(64) NOT NULL,
    birthdt       date,
    propertylist  varchar(256) NOT NULL,
    UserIdn       INT NOT NULL,
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
    provideridn  integer NOT NULL
    filestoreid  varchar(64),
    filepath     varchar(64),
    filename     varchar(64) NOT NULL,
    filetype     varchar(64) NOT NULL,
    createdts    timestamp NOT NULL,
);

---------------------------------------------------------
-- U_Pledge
---------------------------------------------------------
drop table if exists stp.u_pledge;
CREATE TABLE stp.u_pledge (
    pledgeidn        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    projectidn       integer NOT NULL,
    donoridn         integer NOT NULL,
    pledgets         timestamp NOT NULL,
    treecntpledged   integer,
    treecntplanted   integer,
    pledgecredit     jsonb,
    propertylist     varchar(256) NOT null,
    UserIdn          INT NOT NULL
);

CREATE UNIQUE INDEX xak1u_pledge
    ON stp.u_pledge (projectidn, donoridn, pledgets);

---------------------------------------------------------
-- U_Project
---------------------------------------------------------
drop table if exists stp.u_project;
CREATE TABLE stp.u_project (
    projectidn       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    projectid        varchar(64) NOT NULL,
    projectname      varchar(128) NOT NULL,
    projectlocation  GEOGRAPHY(Point, 4326) NOT NULL,
    startdt          date NOT NULL,
    treecntpledged   integer,
    treecntplanted   integer,
    propertylist     varchar(256) NOT NULL,
    useridn          int NOT NULL,
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
    providername  varchar(128) NOT NULL,
    authtype      varchar(256),
    authconfig    varchar(256),
    accesstoken   varchar(256),
    refreshtoken  varchar(256),
    expirets      timestamp
);

---------------------------------------------------------
-- U_Tree
---------------------------------------------------------
drop table if exists stp.u_tree;
CREATE TABLE stp.u_tree (
    treeidn       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    treeid        varchar(64) NOT NULL,
    pledgeidn     integer NOT NULL,
    creditname    varchar(64),
    treetypeidn   integer NOT NULL,
    treelocation  GEOGRAPHY(Point, 4326) NOT NULL,
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
    donoridn       integer NOT NULL,
    fileidn        integer NOT NULL,
    photolocation  GEOGRAPHY(Point, 4326) NOT NULL,
    photots        timestamp NOT NULL,
    donorsentts    timestamp,
    propertylist   varchar(256) NOT NULL,
    useridn         int NOT NULL,
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
    useridn         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username        varchar(128),
    mobilenumber    varchar(64),
    useridncreator  INT,
    ts              TIMESTAMP
);