-- Escrow Table


-- TABLE: ESCROW_ACCOUNT

CREATE TABLE nawy.ESCROW_ACCOUNT (
    escrow_id           BIGINT IDENTITY(1,1)    NOT NULL,
    deal_id             BIGINT                  NULL,
    mortgage_id         BIGINT                  NULL,
    property_id         BIGINT                  NOT NULL,
    bank_name           NVARCHAR(255)           NOT NULL,
    account_number      NVARCHAR(50)            NULL,
    deposit_amount      DECIMAL(15,2)           NOT NULL,
    release_condition   NVARCHAR(MAX)           NULL,
    release_date        DATE                    NULL,
    status              NVARCHAR(20)            NOT NULL CONSTRAINT DF_ESCROW_status DEFAULT ('active'),

    CONSTRAINT PK_ESCROW_ACCOUNT PRIMARY KEY CLUSTERED (escrow_id),
    CONSTRAINT FK_ESCROW_DEAL FOREIGN KEY (deal_id)
        REFERENCES nawy.DEAL(deal_id) ON DELETE SET NULL,
    CONSTRAINT FK_ESCROW_MORTGAGE FOREIGN KEY (mortgage_id)
        REFERENCES nawy.MORTGAGE_APPLICATION(application_id) ON DELETE SET NULL,
    CONSTRAINT FK_ESCROW_PROPERTY FOREIGN KEY (property_id)
        REFERENCES nawy.PROPERTY(property_id) ON DELETE CASCADE,
    CONSTRAINT CK_ESCROW_status CHECK (status IN ('active','released','disputed')),
    CONSTRAINT CK_ESCROW_deposit CHECK (deposit_amount > 0),
    -- Business rule: at least one parent reference required
    CONSTRAINT CK_ESCROW_parent CHECK (deal_id IS NOT NULL OR mortgage_id IS NOT NULL),
    -- Business rule: released status requires release date
    CONSTRAINT CK_ESCROW_released CHECK (status <> 'released' OR release_date IS NOT NULL)
);
GO

