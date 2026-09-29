-- Nawy Shares (Fractional Investment) Tables

-- TABLE: SHARE_OFFERING (Nawy Shares)

CREATE TABLE nawy.SHARE_OFFERING (
    offering_id             BIGINT IDENTITY(1,1)    NOT NULL,
    property_id             BIGINT                  NOT NULL,
    total_value             DECIMAL(15,2)           NOT NULL,
    share_price             DECIMAL(12,2)           NOT NULL,
    total_shares            INT                     NOT NULL,
    shares_available        INT                     NOT NULL,
    offering_open_date      DATE                    NOT NULL,
    offering_close_date     DATE                    NOT NULL,
    exit_condition          NVARCHAR(MAX)           NULL,
    status                  NVARCHAR(20)            NOT NULL CONSTRAINT DF_SHARE_OFFERING_status DEFAULT ('upcoming'),

    CONSTRAINT PK_SHARE_OFFERING PRIMARY KEY CLUSTERED (offering_id),
    CONSTRAINT UQ_SHARE_OFFERING_property UNIQUE (property_id),
    CONSTRAINT FK_SHARE_OFFERING_PROPERTY FOREIGN KEY (property_id)
        REFERENCES nawy.PROPERTY(property_id) ON DELETE CASCADE,
    CONSTRAINT CK_SHARE_OFFERING_status CHECK (status IN ('upcoming','open','closed','sold_out')),
    CONSTRAINT CK_SHARE_OFFERING_total_value CHECK (total_value > 0),
    CONSTRAINT CK_SHARE_OFFERING_share_price CHECK (share_price > 0),
    CONSTRAINT CK_SHARE_OFFERING_total_shares CHECK (total_shares > 0),
    CONSTRAINT CK_SHARE_OFFERING_available CHECK (shares_available BETWEEN 0 AND total_shares),
    CONSTRAINT CK_SHARE_OFFERING_dates CHECK (offering_close_date >= offering_open_date)
);
GO


-- TABLE: SHARE_INVESTMENT

CREATE TABLE nawy.SHARE_INVESTMENT (
    investment_id       BIGINT IDENTITY(1,1)    NOT NULL,
    offering_id         BIGINT                  NOT NULL,
    user_id             BIGINT                  NOT NULL,
    shares_purchased    INT                     NOT NULL,
    total_amount        DECIMAL(12,2)           NOT NULL,
    investment_date     DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_SHARE_INVESTMENT_date DEFAULT (SYSDATETIMEOFFSET()),
    status              NVARCHAR(20)            NOT NULL CONSTRAINT DF_SHARE_INVESTMENT_status DEFAULT ('active'),

    CONSTRAINT PK_SHARE_INVESTMENT PRIMARY KEY CLUSTERED (investment_id),
    CONSTRAINT FK_SHARE_INVESTMENT_OFFERING FOREIGN KEY (offering_id)
        REFERENCES nawy.SHARE_OFFERING(offering_id) ON DELETE CASCADE,
    CONSTRAINT FK_SHARE_INVESTMENT_USER FOREIGN KEY (user_id)
        REFERENCES nawy.[USER](user_id),
    CONSTRAINT CK_SHARE_INVESTMENT_status CHECK (status IN ('active','exited')),
    CONSTRAINT CK_SHARE_INVESTMENT_shares CHECK (shares_purchased > 0),
    CONSTRAINT CK_SHARE_INVESTMENT_amount CHECK (total_amount > 0)
);
GO


-- TABLE: SHARE_EXIT

CREATE TABLE nawy.SHARE_EXIT (
    exit_id                 BIGINT IDENTITY(1,1)    NOT NULL,
    investment_id           BIGINT                  NOT NULL,
    exit_price_per_share    DECIMAL(12,2)           NOT NULL,
    total_sale_value        DECIMAL(15,2)           NOT NULL,
    exit_fee_percent        DECIMAL(5,4)            NOT NULL CONSTRAINT DF_SHARE_EXIT_fee DEFAULT (0.0250),
    profit_loss             DECIMAL(12,2)           NULL,
    exit_date               DATE                    NOT NULL,
    status                  NVARCHAR(20)            NOT NULL CONSTRAINT DF_SHARE_EXIT_status DEFAULT ('pending'),

    CONSTRAINT PK_SHARE_EXIT PRIMARY KEY CLUSTERED (exit_id),
    CONSTRAINT UQ_SHARE_EXIT_investment UNIQUE (investment_id),
    CONSTRAINT FK_SHARE_EXIT_INVESTMENT FOREIGN KEY (investment_id)
        REFERENCES nawy.SHARE_INVESTMENT(investment_id) ON DELETE CASCADE,
    CONSTRAINT CK_SHARE_EXIT_status CHECK (status IN ('pending','completed')),
    CONSTRAINT CK_SHARE_EXIT_price CHECK (exit_price_per_share > 0),
    CONSTRAINT CK_SHARE_EXIT_value CHECK (total_sale_value > 0),
    CONSTRAINT CK_SHARE_EXIT_fee CHECK (exit_fee_percent BETWEEN 0 AND 1)
);
GO


