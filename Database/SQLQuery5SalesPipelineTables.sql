-- Sales Pipeline Tables

-- TABLE: LEAD

CREATE TABLE nawy.LEAD (
    lead_id             BIGINT IDENTITY(1,1)    NOT NULL,
    property_id         BIGINT                  NOT NULL,
    buyer_user_id       BIGINT                  NOT NULL,
    broker_id           BIGINT                  NULL,
    status              NVARCHAR(30)            NOT NULL CONSTRAINT DF_LEAD_status DEFAULT ('new'),
    source              NVARCHAR(50)            NULL,
    notes               NVARCHAR(MAX)           NULL,
    created_at          DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_LEAD_created_at DEFAULT (SYSDATETIMEOFFSET()),
    last_activity_at    DATETIMEOFFSET(7)       NULL,

    CONSTRAINT PK_LEAD PRIMARY KEY CLUSTERED (lead_id),
    CONSTRAINT FK_LEAD_PROPERTY FOREIGN KEY (property_id)
        REFERENCES nawy.PROPERTY(property_id) ON DELETE CASCADE,
    CONSTRAINT FK_LEAD_BUYER FOREIGN KEY (buyer_user_id)
        REFERENCES nawy.[USER](user_id),
    CONSTRAINT FK_LEAD_BROKER FOREIGN KEY (broker_id)
        REFERENCES nawy.BROKER(broker_id),
    CONSTRAINT CK_LEAD_status CHECK (status IN
        ('new','contacted','viewing','negotiation','closed_won','closed_lost')),
    CONSTRAINT CK_LEAD_source CHECK (source IS NULL OR source IN
        ('website','app','broker_referral','walk_in','developer_referral'))
);
GO


-- TABLE: DEAL

CREATE TABLE nawy.DEAL (
    deal_id         BIGINT IDENTITY(1,1)    NOT NULL,
    lead_id         BIGINT                  NULL,
    property_id     BIGINT                  NOT NULL,
    buyer_user_id   BIGINT                  NOT NULL,
    broker_id       BIGINT                  NULL,
    sale_price      DECIMAL(15,2)           NOT NULL,
    payment_type    NVARCHAR(20)            NOT NULL,
    status          NVARCHAR(20)            NOT NULL CONSTRAINT DF_DEAL_status DEFAULT ('pending'),
    closed_at       DATETIMEOFFSET(7)       NULL,

    CONSTRAINT PK_DEAL PRIMARY KEY CLUSTERED (deal_id),
    CONSTRAINT FK_DEAL_LEAD FOREIGN KEY (lead_id)
        REFERENCES nawy.LEAD(lead_id) ON DELETE SET NULL,
    CONSTRAINT FK_DEAL_PROPERTY FOREIGN KEY (property_id)
        REFERENCES nawy.PROPERTY(property_id),
    CONSTRAINT FK_DEAL_BUYER FOREIGN KEY (buyer_user_id)
        REFERENCES nawy.[USER](user_id),
    CONSTRAINT FK_DEAL_BROKER FOREIGN KEY (broker_id)
        REFERENCES nawy.BROKER(broker_id),
    CONSTRAINT CK_DEAL_payment_type CHECK (payment_type IN ('cash','installment','mortgage')),
    CONSTRAINT CK_DEAL_status CHECK (status IN ('pending','approved','completed','cancelled')),
    CONSTRAINT CK_DEAL_sale_price CHECK (sale_price > 0)
);
GO


-- TABLE: COMMISSION

CREATE TABLE nawy.COMMISSION (
    commission_id       BIGINT IDENTITY(1,1)    NOT NULL,
    deal_id             BIGINT                  NOT NULL,
    broker_id           BIGINT                  NOT NULL,
    commission_amount   DECIMAL(12,2)           NOT NULL,
    commission_rate     DECIMAL(5,4)            NULL,
    status              NVARCHAR(20)            NOT NULL CONSTRAINT DF_COMMISSION_status DEFAULT ('pending'),
    paid_at             DATETIMEOFFSET(7)       NULL,

    CONSTRAINT PK_COMMISSION PRIMARY KEY CLUSTERED (commission_id),
    CONSTRAINT FK_COMMISSION_DEAL FOREIGN KEY (deal_id)
        REFERENCES nawy.DEAL(deal_id) ON DELETE CASCADE,
    CONSTRAINT FK_COMMISSION_BROKER FOREIGN KEY (broker_id)
        REFERENCES nawy.BROKER(broker_id),
    CONSTRAINT CK_COMMISSION_status CHECK (status IN ('pending','paid')),
    CONSTRAINT CK_COMMISSION_amount CHECK (commission_amount > 0),
    CONSTRAINT CK_COMMISSION_rate CHECK (commission_rate IS NULL OR commission_rate BETWEEN 0 AND 1)
);
GO


