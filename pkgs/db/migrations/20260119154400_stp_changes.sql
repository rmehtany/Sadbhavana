-- +goose Up
-- +goose StatementBegin
SELECT 'up SQL query';

---------------------------------------------------------
-- U_Donor
---------------------------------------------------------
drop table if exists stp.u_donor;
CREATE TABLE stp.u_donor (
    donoridn      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mobilenumber  varchar(64) NOT NULL,
    donorname     varchar(128) NOT NULL,
    emailaddr     varchar(64),
    city          varchar(64),
    country       varchar(64),
    birthdt       date,
    propertylist  jsonb NOT NULL,
    UserIdn       INT NOT NULL,
    ts            timestamptz NOT NULL
);

---------------------------------------------------------
-- U_DonorSendLog
---------------------------------------------------------
drop table if exists stp.u_donorsendlog;
CREATE TABLE stp.u_donorsendlog (
    idn          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    treeidn      integer NOT NULL,
    uploadts     timestamptz NOT NULL,
    sendts       timestamptz,
    sendstatus   varchar(64)
);

CREATE UNIQUE INDEX xak1u_donorsendlog
    ON stp.u_donorsendlog (treeidn, uploadts);

---------------------------------------------------------
-- U_File
---------------------------------------------------------
drop table if exists stp.u_file;
CREATE TABLE stp.u_file (
    fileidn      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provideridn  integer NOT null,
    filestoreid  varchar(256) NOT NULL,
    filepath     varchar(2048) NOT NULL,
    filename     varchar(256) NOT NULL,
    filetype     varchar(64) NOT NULL,
    ts          timestamptz NOT NULL
);

CREATE UNIQUE INDEX xak1u_file
    ON stp.u_file (provideridn, filestoreid, filepath, filename);

---------------------------------------------------------
-- U_Pledge
---------------------------------------------------------
drop table if exists stp.u_pledge;
CREATE TABLE stp.u_pledge (
    pledgeidn        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    donoridn         integer NOT NULL,
    projectidn       integer NOT NULL,
    pledgets         timestamptz NOT NULL,
    treecntpledged   integer,
    treecntplanted   integer,
    pledgecredit     jsonb,
    propertylist     jsonb NOT NULL,
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
    propertylist     jsonb NOT NULL,
    useridn          int NOT NULL,
    ts               timestamptz NOT NULL
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
    authtype      varchar(64) NOT NULL,
    authconfig    jsonb NOT NULL,
    tokenconfig   jsonb NOT NULL
);

CREATE UNIQUE INDEX xak1u_provider
    ON stp.u_provider (providername);

---------------------------------------------------------
-- U_Tree
---------------------------------------------------------
drop table if exists stp.u_tree;
CREATE TABLE stp.u_tree (
    treeidn       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    treeid        varchar(64) NOT NULL,
    pledgeidn     integer NOT NULL,
    creditname    varchar(64),
    treetypeidn   integer,
    treelocation  geography(Point, 4326),
    propertylist  jsonb NOT NULL
);

CREATE UNIQUE INDEX xak1u_tree
    ON stp.u_tree (treeid);

---------------------------------------------------------
-- U_TreePhoto
---------------------------------------------------------
drop table if exists stp.u_treephoto;
CREATE TABLE stp.u_treephoto (
    treeidn        integer NOT NULL,
    uploadts       timestamptz NOT NULL,
    donoridn       integer NOT NULL,
    fileidn        integer NOT NULL,
    photolocation  GEOGRAPHY(Point, 4326) NOT NULL,
    photots        timestamptz NOT NULL,
    propertylist   jsonb NOT NULL,
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
    propertylist   jsonb NOT NULL
);

CREATE UNIQUE INDEX xak1u_treetype
    ON stp.u_treetype (treetypename);

---------------------------------------------------------
-- U_User
---------------------------------------------------------
drop table if exists stp.u_user;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
SELECT 'down SQL query';
drop table if exists stp.u_user;
drop table if exists stp.u_treetype;
drop table if exists stp.u_treephoto;
drop table if exists stp.u_tree;
drop table if exists stp.u_provider;
drop table if exists stp.u_project;
drop table if exists stp.u_pledge;
drop table if exists stp.u_file;
drop table if exists stp.u_donorsendlog;
drop table if exists stp.u_donor;
-- +goose StatementEnd
