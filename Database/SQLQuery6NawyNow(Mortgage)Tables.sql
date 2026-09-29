-- Nawy Now (Mortgage) Tables

-- TABLE: MORTGAGE_APPLICATION (Nawy Now)

CREATE TABLE nawy.MORTGAGE_APPLICATION (
    application_id      BIGINT IDENTITY(1,1)    NOT NULL,
    user_id             BIGINT                  NOT NULL,
    property_id         BIGINT                  NOT NULL,
    property_price      DECIMAL(15,2)           NOT NULL,
    down_payment        DECIMAL(15,2)           NOT NULL,
    loan_amount         DECIMAL(15,2)           NOT NULL,
    installment_months  INT                     NOT NULL,
    interest_rate       DECIMAL(5,4)            NULL,
    monthly_payment     DECIMAL(12,2)           NOT NULL,
    status              NVARCHAR(30)            NOT NULL CONSTRAINT DF_MORTGAGE_status DEFAULT ('submitted'),
    submitted_at        DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_MORTGAGE_submitted_at DEFAULT (SYSDATETIMEOFFSET()),
    approved_at         DATETIMEOFFSET(7)       NULL,

    CONSTRAINT PK_MORTGAGE_APPLICATION PRIMARY KEY CLUSTERED (application_id),
    CONSTRAINT FK_MORTGAGE_USER FOREIGN KEY (user_id)
        REFERENCES nawy.[USER](user_id),
    CONSTRAINT FK_MORTGAGE_PROPERTY FOREIGN KEY (property_id)
        REFERENCES nawy.PROPERTY(property_id),
    CONSTRAINT CK_MORTGAGE_status CHECK (status IN
        ('submitted','under_review','approved','rejected','disbursed')),
    CONSTRAINT CK_MORTGAGE_months CHECK (installment_months BETWEEN 36 AND 120),
    CONSTRAINT CK_MORTGAGE_price CHECK (property_price > 0),
    CONSTRAINT CK_MORTGAGE_down CHECK (down_payment >= 0),
    CONSTRAINT CK_MORTGAGE_loan CHECK (loan_amount > 0),
    CONSTRAINT CK_MORTGAGE_monthly CHECK (monthly_payment > 0),
    -- Business rule: down payment >= 10% of price
    CONSTRAINT CK_MORTGAGE_down_min CHECK (down_payment >= property_price * 0.10),
    -- Business rule: loan = price - down
    CONSTRAINT CK_MORTGAGE_loan_calc CHECK (loan_amount = property_price - down_payment)
);
GO


-- TABLE: MORTGAGE_PAYMENT

CREATE TABLE nawy.MORTGAGE_PAYMENT (
    payment_id          BIGINT IDENTITY(1,1)    NOT NULL,
    application_id      BIGINT                  NOT NULL,
    installment_number  INT                     NOT NULL,
    amount_due          DECIMAL(12,2)           NOT NULL,
    amount_paid         DECIMAL(12,2)           NULL,
    due_date            DATE                    NOT NULL,
    paid_date           DATE                    NULL,
    status              NVARCHAR(20)            NOT NULL CONSTRAINT DF_MORTGAGE_PAYMENT_status DEFAULT ('pending'),

    CONSTRAINT PK_MORTGAGE_PAYMENT PRIMARY KEY CLUSTERED (payment_id),
    CONSTRAINT UQ_MORTGAGE_PAYMENT_app_inst UNIQUE (application_id, installment_number),
    CONSTRAINT FK_MORTGAGE_PAYMENT_APP FOREIGN KEY (application_id)
        REFERENCES nawy.MORTGAGE_APPLICATION(application_id) ON DELETE CASCADE,
    CONSTRAINT CK_MORTGAGE_PAYMENT_status CHECK (status IN ('pending','paid','overdue')),
    CONSTRAINT CK_MORTGAGE_PAYMENT_number CHECK (installment_number >= 1),
    CONSTRAINT CK_MORTGAGE_PAYMENT_amount_due CHECK (amount_due > 0),
    CONSTRAINT CK_MORTGAGE_PAYMENT_amount_paid CHECK (amount_paid IS NULL OR amount_paid >= 0)
);
GO


