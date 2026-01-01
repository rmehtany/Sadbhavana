CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS dblink;
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- Schema (if not already created)
CREATE SCHEMA IF NOT EXISTS stp;

-- U_Donor
drop table if exists stp.U_Donor;
CREATE TABLE stp.U_Donor (
    DonorIdn        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    DonorName       varchar(128) NOT NULL,
    MobileNumber    varchar(64) NOT NULL,
    City            varchar(64) NOT NULL,
    EmailAddr       varchar(64),
    Country         varchar(64) NOT NULL,
    State           varchar(64) NOT NULL,
    BirthDt         date,
    PropertyList    varchar(256) NOT NULL,
    UserIdn         integer NOT NULL,
    Ts              timestamp
);

-- U_DonorSendLog
drop table if exists stp.U_DonorSendLog;
CREATE TABLE stp.U_DonorSendLog (
    Idn             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    TreeIdn         integer NOT NULL,
    UploadTs        timestamp NOT NULL,
    SendTs          timestamp,
    SendStatus      varchar(64)
);

-- U_File
drop table if exists stp.U_File;
CREATE TABLE stp.U_File (
    FileIdn         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    FilePath        varchar(64),
    FileName        varchar(64) NOT NULL,
    FileType        varchar(64) NOT NULL,
    FileStoreId     varchar(64),
    CreatedTs       timestamp NOT NULL,
    ProviderIdn     integer NOT NULL
);

-- U_Pledge
drop table if exists stp.U_Pledge;
CREATE TABLE stp.U_Pledge (
    PledgeIdn       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ProjectIdn      integer NOT NULL,
    DonorIdn        integer NOT NULL,
    PledgeTs        timestamp NOT NULL,
    TreeCntPledged  integer,
    TreeCntPlanted  integer,
    PledgeCredit    jsonb,
    PropertyList    varchar(256) NOT NULL,
    UserIdn         integer NOT NULL
);

CREATE UNIQUE INDEX XAK1U_Pledge ON stp.U_Pledge (
    ProjectIdn,
    DonorIdn,
    PledgeTs
);

-- U_Project
drop table if exists stp.U_Project;
CREATE TABLE stp.U_Project (
    ProjectIdn      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ProjectId       varchar(64) NOT NULL,
    ProjectName     varchar(128) NOT NULL,
    ProjectLocation geography(POINT,4326) NOT NULL, -- requires PostGIS
    TreeCntPledged  integer,
    TreeCntPlanted  integer,
    StartDt         date NOT NULL,
    PropertyList    varchar(256) NOT NULL,
    UserIdn         integer NOT NULL,
    Ts              timestamp NOT NULL
);

CREATE UNIQUE INDEX XAK1U_Project ON U_Project (ProjectId);

-- U_Provider
drop table if exists stp.U_Provider;
CREATE TABLE stp.U_Provider (
    ProviderIdn     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ProviderName    varchar(128) NOT NULL,
    AuthType        varchar(64),
    AuthConfig      varchar(64),
    AccessToken     varchar(64),
    RefreshToken    varchar(64),
    ExpireTs        timestamp
);

-- U_Tree
drop table if exists stp.U_Tree;
CREATE TABLE stp.U_Tree (
    TreeIdn         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    TreeLocation    geography(POINT,4326) NOT NULL, -- requires PostGIS
    TreeTypeIdn     integer NOT NULL,
    PledgeIdn       integer NOT NULL,
    CreditName      varchar(64),
    TreeId          varchar(64) NOT NULL,
    PropertyList    varchar(256) NOT NULL
);

CREATE UNIQUE INDEX XAK1U_Tree ON U_Tree (TreeId);

-- U_TreePhoto
drop table if exists stp.U_TreePhoto;
CREATE TABLE stp.U_TreePhoto (
    TreeIdn         integer NOT NULL,
    UploadTs        timestamp NOT NULL,
    DonorSentTs     timestamp,
    PhotoLocation   varchar(64) NOT NULL,
    FileIdn         integer NOT NULL,
    PhotoTs         timestamp NOT NULL,
    DonorIdn        integer NOT NULL,
    PropertyList    varchar(256) NOT NULL,
    UserIdn         integer NOT NULL
);

-- U_TreeType
drop table if exists stp.U_TreeType;
CREATE TABLE stp.U_TreeType (
    TreeTypeIdn     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    TreeTypeName    varchar(128) NOT NULL,
    AvgLifeYears    integer,
    PropertyList    varchar(256) NOT NULL
);

-- U_User
drop table if exists stp.U_User;
CREATE TABLE stp.U_User (
    UserIdn         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    UserName        varchar(128) NOT NULL,
    MobileNumber    varchar(64),
    UserIdnCreator  integer NOT NULL,
    Ts              timestamp
);