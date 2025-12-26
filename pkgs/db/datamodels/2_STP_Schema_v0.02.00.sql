/* 
-- SQL Server version
CREATE TABLE stp.U_Donor
( 
	DonorIdn             integer  NOT NULL  IDENTITY ,
	DonorName            varchar(128)  NOT NULL ,
	MobileNumber         varchar(128)  NOT NULL ,
	City                 varchar(64)  NOT NULL ,
	EmailAddr            varchar(64)  NULL ,
	Country              varchar(64)  NOT NULL ,
	State                varchar(64)  NOT NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	BirthDt              char(18)  NULL ,
	UserId               varchar(32)  NOT NULL ,
	Ts                   datetime  NULL ,
	CONSTRAINT XPKU_Donor PRIMARY KEY  CLUSTERED (DonorIdn ASC)
)
go

CREATE TABLE stp.U_DonorSendLog
( 
	Idn                  integer  NOT NULL  IDENTITY ,
	TreeIdn              integer  NOT NULL ,
	UploadTs             datetime  NOT NULL ,
	SendTs               datetime  NULL ,
	SendStatus           varchar(64)  NULL ,
	CONSTRAINT XPKU_DonorSendLog PRIMARY KEY  CLUSTERED (Idn ASC)
)
go

CREATE TABLE stp.U_File
( 
	FileIdn              integer  NOT NULL  IDENTITY ,
	FilePath             varchar(64)  NULL ,
	FileName             varchar(64)  NOT NULL ,
	FileType             varchar(64)  NOT NULL ,
	FileStoreId          varchar(64)  NULL ,
	CreatedTs            datetime  NOT NULL ,
	ProviderIdn          integer  NOT NULL ,
	CONSTRAINT XPKU_File PRIMARY KEY  CLUSTERED (FileIdn ASC)
)
go

CREATE TABLE stp.U_Pledge
( 
	PledgeIdn            integer  NOT NULL  IDENTITY ,
	ProjectIdn           integer  NOT NULL ,
	DonorIdn             integer  NOT NULL ,
	TreeCntPledged       integer  NULL ,
	PledgeTs             datetime  NOT NULL ,
	TreeCntPlanted       integer  NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	CONSTRAINT XPKU_Pledge PRIMARY KEY  CLUSTERED (PledgeIdn ASC)
)
go

CREATE UNIQUE NONCLUSTERED INDEX XAK1U_Pledge ON stp.U_Pledge
( 
	ProjectIdn            ASC,
	DonorIdn              ASC,
	PledgeTs              ASC
)
go

CREATE TABLE stp.U_Project
( 
	ProjectIdn           integer  NOT NULL  IDENTITY ,
	ProjectName          varchar(128)  NOT NULL ,
	StartDt              date  NOT NULL ,
	ProjectLocation      varchar(64)  NOT NULL ,
	TreeCntPledged       integer  NULL ,
	TreeCntPlanted       integer  NULL ,
	ProjectId            varchar(64)  NOT NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	UserId               varchar(32)  NOT NULL ,
	Ts                   datetime  NOT NULL ,
	CONSTRAINT XPKU_Project PRIMARY KEY  CLUSTERED (ProjectIdn ASC)
)
go

CREATE UNIQUE NONCLUSTERED INDEX XAK1U_Project ON stp.U_Project
( 
	ProjectId             ASC
)
go

CREATE TABLE stp.U_Provider
( 
	ProviderIdn          integer  NOT NULL  IDENTITY ,
	ProviderName         varchar(64)  NOT NULL ,
	AuthType             varchar(64)  NULL ,
	AuthConfig           varchar(64)  NULL ,
	AccessToken          varchar(64)  NULL ,
	RefreshToken         varchar(64)  NULL ,
	ExpireTs             datetime  NULL ,
	CONSTRAINT XPKU_Provider PRIMARY KEY  CLUSTERED (ProviderIdn ASC)
)
go

CREATE TABLE stp.U_Tree
( 
	TreeIdn              integer  NOT NULL  IDENTITY ,
	TreeLocation         varchar(64)  NOT NULL ,
	TreeTypeIdn          integer  NOT NULL ,
	PledgeIdn            integer  NOT NULL ,
	TitleName            varchar(64)  NULL ,
	TreeId               varchar(64)  NOT NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	CONSTRAINT XPKU_Tree PRIMARY KEY  CLUSTERED (TreeIdn ASC)
)
go

CREATE UNIQUE NONCLUSTERED INDEX XAK1U_Tree ON stp.U_Tree
( 
	TreeId                ASC
)
go

CREATE TABLE stp.U_TreePhoto
( 
	TreeIdn              integer  NOT NULL ,
	UploadTs             datetime  NOT NULL ,
	DonorSentTs          datetime  NULL ,
	PhotoLocation        varchar(64)  NOT NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	FileIdn              integer  NOT NULL ,
	PhotoTs              datetime  NOT NULL ,
	DonorIdn             integer  NOT NULL ,
	UserId               varchar(32)  NOT NULL ,
	CONSTRAINT XPKU_TreePhoto PRIMARY KEY  CLUSTERED (TreeIdn ASC,UploadTs ASC)
)
go

CREATE TABLE stp.U_TreeType
( 
	TreeTypeIdn          integer  NOT NULL  IDENTITY ,
	TreeTypeName         varchar(128)  NOT NULL ,
	AvgLifeYears         integer  NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	CONSTRAINT XPKU_TreeType PRIMARY KEY  CLUSTERED (TreeTypeIdn ASC)
)
go

CREATE TABLE stp.U_User
( 
	UserId               integer  NOT NULL  IDENTITY ,
	UserName             char(18)  NULL ,
	UserIdCreator        char(18)  NULL ,
	Ts                   char(18)  NULL ,
	MobileNumber         char(18)  NULL ,
	CONSTRAINT XPKU_User PRIMARY KEY  CLUSTERED (UserId ASC)
)
go
*/
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