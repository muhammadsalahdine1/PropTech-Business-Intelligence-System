-- User & Access Tables

-- TABLE: USER
CREATE TABLE nawy.[USER] (
    user_id         BIGINT IDENTITY(1,1)    NOT NULL,
    email           NVARCHAR(255)           NOT NULL,
    phone           NVARCHAR(20)            NOT NULL,
    full_name       NVARCHAR(255)           NOT NULL,
    user_type       NVARCHAR(50)            NOT NULL,
    national_id     NVARCHAR(14)            NULL,
    password_hash   NVARCHAR(MAX)           NOT NULL,
    is_verified     BIT                     NOT NULL CONSTRAINT DF_USER_is_verified DEFAULT (0),
    created_at      DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_USER_created_at DEFAULT (SYSDATETIMEOFFSET()),
    updated_at      DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_USER_updated_at DEFAULT (SYSDATETIMEOFFSET()),

    CONSTRAINT PK_USER PRIMARY KEY CLUSTERED (user_id),
    CONSTRAINT UQ_USER_email UNIQUE (email),
    CONSTRAINT UQ_USER_phone UNIQUE (phone),
    CONSTRAINT UQ_USER_national_id UNIQUE (national_id),
    CONSTRAINT CK_USER_user_type CHECK (user_type IN ('buyer','seller','investor','broker','admin'))
);
GO



-- TABLE: BROKER

CREATE TABLE nawy.BROKER (
    broker_id       BIGINT IDENTITY(1,1)    NOT NULL,
    user_id         BIGINT                  NOT NULL,
    broker_type     NVARCHAR(50)            NOT NULL,
    agency_name     NVARCHAR(255)           NULL,
    license_number  NVARCHAR(100)           NOT NULL,
    commission_rate DECIMAL(5,4)            NOT NULL CONSTRAINT DF_BROKER_commission_rate DEFAULT (0.0250),
    team_size       INT                     NOT NULL CONSTRAINT DF_BROKER_team_size DEFAULT (0),
    status          NVARCHAR(20)            NOT NULL CONSTRAINT DF_BROKER_status DEFAULT ('active'),
    joined_at       DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_BROKER_joined_at DEFAULT (SYSDATETIMEOFFSET()),

    CONSTRAINT PK_BROKER PRIMARY KEY CLUSTERED (broker_id),
    CONSTRAINT UQ_BROKER_user_id UNIQUE (user_id),
    CONSTRAINT UQ_BROKER_license_number UNIQUE (license_number),
    CONSTRAINT FK_BROKER_USER FOREIGN KEY (user_id)
        REFERENCES nawy.[USER](user_id) ON DELETE CASCADE,
    CONSTRAINT CK_BROKER_type CHECK (broker_type IN ('freelancer','agency')),
    CONSTRAINT CK_BROKER_status CHECK (status IN ('active','suspended','inactive')),
    CONSTRAINT CK_BROKER_commission_rate CHECK (commission_rate BETWEEN 0 AND 1),
    CONSTRAINT CK_BROKER_team_size CHECK (team_size >= 0)
);
GO


-- TABLE: BROKER_TEAM

CREATE TABLE nawy.BROKER_TEAM (
    team_id         BIGINT IDENTITY(1,1)    NOT NULL,
    broker_id       BIGINT                  NOT NULL,
    member_user_id  BIGINT                  NOT NULL,
    role            NVARCHAR(50)            NOT NULL,
    added_at        DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_BROKER_TEAM_added_at DEFAULT (SYSDATETIMEOFFSET()),

    CONSTRAINT PK_BROKER_TEAM PRIMARY KEY CLUSTERED (team_id),
    CONSTRAINT UQ_BROKER_TEAM_broker_member UNIQUE (broker_id, member_user_id),
    CONSTRAINT FK_BROKER_TEAM_BROKER FOREIGN KEY (broker_id)
        REFERENCES nawy.BROKER(broker_id) ON DELETE CASCADE,
    CONSTRAINT FK_BROKER_TEAM_USER FOREIGN KEY (member_user_id)
        REFERENCES nawy.[USER](user_id),  -- No cascade (avoid multiple cascade paths)
    CONSTRAINT CK_BROKER_TEAM_role CHECK (role IN ('senior_agent','junior_agent'))
);
GO