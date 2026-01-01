
CREATE TABLE U_Donor
( 
	DonorIdn             integer  NOT NULL ,
	DonorName            varchar(64)  NOT NULL ,
	MobileNumber         varchar(64)  NOT NULL ,
	City                 varchar(64)  NOT NULL ,
	EmailAddr            varchar(64)  NULL ,
	Country              varchar(64)  NOT NULL ,
	State                varchar(64)  NOT NULL ,
	BirthDt              date  NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	UserIdn              integer  NOT NULL ,
	Ts                   timestamp  NULL 
);

CREATE TABLE U_DonorSendLog
( 
	Idn                  integer  NOT NULL ,
	TreeIdn              integer  NOT NULL ,
	UploadTs             timestamp  NOT NULL ,
	SendTs               timestamp  NULL ,
	SendStatus           varchar(64)  NULL 
);

CREATE TABLE U_File
( 
	FileIdn              integer  NOT NULL ,
	ProviderIdn          integer  NOT NULL ,
	FileStoreId          varchar(64)  NULL ,
	FilePath             varchar(64)  NULL ,
	FileName             varchar(64)  NOT NULL ,
	FileType             varchar(64)  NOT NULL ,
	Ts                   timestamp  NOT NULL 
);

CREATE TABLE U_Pledge
( 
	PledgeIdn            integer  NOT NULL ,
	ProjectIdn           integer  NOT NULL ,
	DonorIdn             integer  NOT NULL ,
	PledgeTs             timestamp  NOT NULL ,
	TreeCntPledged       integer  NULL ,
	TreeCntPlanted       integer  NULL ,
	PledgeCredit         jsonb  NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	UserIdn              integer  NOT NULL 
);

CREATE UNIQUE NONCLUSTERED INDEX XAK1U_Pledge ON U_Pledge
( 
	ProjectIdn            ASC,
	DonorIdn              ASC,
	PledgeTs              ASC
);

CREATE TABLE U_Project
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
	Ts                   timestamp  NOT NULL 
);

CREATE UNIQUE NONCLUSTERED INDEX XAK1U_Project ON U_Project
( 
	ProjectId             ASC
);

CREATE TABLE U_Provider
( 
	ProviderIdn          integer  NOT NULL ,
	ProviderName         varchar(64)  NOT NULL ,
	AuthType             varchar(64)  NULL ,
	AuthConfig           varchar(64)  NULL ,
	AccessToken          varchar(64)  NULL ,
	RefreshToken         varchar(64)  NULL ,
	ExpireTs             timestamp  NULL 
);

CREATE TABLE U_Tree
( 
	TreeIdn              integer  NOT NULL ,
	TreeLocation         geography(point,4326)  NOT NULL ,
	TreeTypeIdn          integer  NOT NULL ,
	PledgeIdn            integer  NOT NULL ,
	CreditName           varchar(64)  NULL ,
	TreeId               varchar(64)  NOT NULL ,
	PropertyList         varchar(256)  NOT NULL 
);

CREATE UNIQUE NONCLUSTERED INDEX XAK1U_Tree ON U_Tree
( 
	TreeId                ASC
);

CREATE TABLE U_TreePhoto
( 
	TreeIdn              integer  NOT NULL ,
	UploadTs             timestamp  NOT NULL ,
	DonorSentTs          timestamp  NULL ,
	PhotoLocation        varchar(64)  NOT NULL ,
	FileIdn              integer  NOT NULL ,
	PhotoTs              timestamp  NOT NULL ,
	DonorIdn             integer  NOT NULL ,
	PropertyList         varchar(256)  NOT NULL ,
	UserIdn              integer  NOT NULL 
);

CREATE TABLE U_TreeType
( 
	TreeTypeIdn          integer  NOT NULL ,
	TreeTypeName         varchar(128)  NOT NULL ,
	AvgLifeYears         integer  NULL ,
	PropertyList         varchar(256)  NOT NULL 
);

CREATE TABLE U_User
( 
	UserIdn              integer  NOT NULL ,
	UserName             varchar(64)  NULL ,
	UserIdnCreator       integer  NOT NULL ,
	MobileNumber         varchar(64)  NULL ,
	Ts                   timestamp  NULL 
);
