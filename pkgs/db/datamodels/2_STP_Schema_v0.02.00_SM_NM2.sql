create extension if not exists postgis;
create extension if not exists dblink;

-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- PostgreSQL version

-- Schema (if not already created)
CREATE SCHEMA IF NOT EXISTS stp;


CREATE TABLE stp.U_Donor
( 
	DonorIdn             integer  NOT NULL ,
	DonorName            varchar(128)  NOT NULL ,
	MobileNumber         varchar(64)  NOT NULL ,
	City                 varchar(64)  NOT NULL ,
	EmailAddr            varchar(64)  NULL ,
	Country              varchar(64)  NOT NULL ,
	State                varchar(64)  NOT NULL ,
	BirthDt              date  NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	UserIdn              integer  NOT NULL ,
	Ts                   timestamp  NULL ,
	CONSTRAINT XPKU_Donor PRIMARY KEY (DonorIdn)
);

CREATE TABLE stp.U_DonorSendLog
( 
	Idn                  integer  NOT NULL ,
	TreeIdn              integer  NOT NULL ,
	UploadTs             timestamp  NOT NULL ,
	SendTs               timestamp  NULL ,
	SendStatus           varchar(64)  NULL ,
	CONSTRAINT XPKU_DonorSendLog PRIMARY KEY (Idn)
);

CREATE TABLE stp.U_File
( 
	FileIdn              integer  NOT NULL ,
	FilePath             varchar(64)  NULL ,
	FileName             varchar(64)  NOT NULL ,
	FileType             varchar(64)  NOT NULL ,
	FileStoreId          varchar(64)  NULL ,
	CreatedTs            timestamp  NOT NULL ,
	ProviderIdn          integer  NOT NULL ,
	CONSTRAINT XPKU_File PRIMARY KEY (FileIdn)
);

CREATE TABLE stp.U_Pledge
( 
	PledgeIdn            integer  NOT NULL ,
	ProjectIdn           integer  NOT NULL ,
	DonorIdn             integer  NOT NULL ,
	PledgeTs             timestamp  NOT NULL ,
	TreeCntPledged       integer  NULL ,
	TreeCntPlanted       integer  NULL ,
	PledgeCredit         jsonb  NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	UserIdn              integer  NOT NULL ,
	CONSTRAINT XPKU_Pledge PRIMARY KEY (PledgeIdn),
	CONSTRAINT XAK1U_Pledge UNIQUE (ProjectIdn,DonorIdn,PledgeTs)
);

CREATE TABLE stp.U_Project
( 
	ProjectIdn           integer  NOT NULL ,
	ProjectId            varchar(64)  NOT NULL ,
	ProjectName          varchar(128)  NOT NULL ,
	ProjectLocation      geography(point,4326)  NOT NULL ,
	TreeCntPledged       integer  NULL ,
	TreeCntPlanted       integer  NULL ,
	StartDt              date  NOT NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	UserIdn              integer  NOT NULL ,
	Ts                   timestamp  NOT NULL ,
	CONSTRAINT XPKU_Project PRIMARY KEY (ProjectIdn),
	CONSTRAINT XAK1U_Project UNIQUE (ProjectId)
);

CREATE TABLE stp.U_Provider
( 
	ProviderIdn          integer  NOT NULL ,
	ProviderName         varchar(128)  NOT NULL ,
	AuthType             varchar(64)  NULL ,
	AuthConfig           varchar(64)  NULL ,
	AccessToken          varchar(64)  NULL ,
	RefreshToken         varchar(64)  NULL ,
	ExpireTs             timestamp  NULL ,
	CONSTRAINT XPKU_Provider PRIMARY KEY (ProviderIdn)
);

CREATE TABLE stp.U_Tree
( 
	TreeIdn              integer  NOT NULL ,
	TreeLocation         geography(point,4326)  NOT NULL ,
	TreeTypeIdn          integer  NOT NULL ,
	PledgeIdn            integer  NOT NULL ,
	CreditName           varchar(64)  NULL ,
	TreeId               varchar(64)  NOT NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	CONSTRAINT XPKU_Tree PRIMARY KEY (TreeIdn),
	CONSTRAINT XAK1U_Tree UNIQUE (TreeId)
);

CREATE TABLE stp.U_TreePhoto
( 
	TreeIdn              integer  NOT NULL ,
	UploadTs             timestamp  NOT NULL ,
	DonorSentTs          timestamp  NULL ,
	PhotoLocation        varchar(64)  NOT NULL ,
	FileIdn              integer  NOT NULL ,
	PhotoTs              timestamp  NOT NULL ,
	DonorIdn             integer  NOT NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	UserIdn              integer  NOT NULL ,
	CONSTRAINT XPKU_TreePhoto PRIMARY KEY (TreeIdn,UploadTs)
);

CREATE TABLE stp.U_TreeType
( 
	TreeTypeIdn          integer  NOT NULL ,
	TreeTypeName         varchar(128)  NOT NULL ,
	AvgLifeYears         integer  NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	CONSTRAINT XPKU_TreeType PRIMARY KEY (TreeTypeIdn)
);

CREATE TABLE stp.U_User
( 
	UserIdn              integer  NOT NULL ,
	UserName             varchar(128)  NOT NULL ,
	MobileNumber         varchar(64)  NULL ,
	UserIdnCreator       integer  NOT NULL ,
	Ts                   timestamp  NULL ,
	CONSTRAINT XPKU_User PRIMARY KEY (UserIdn)
);
