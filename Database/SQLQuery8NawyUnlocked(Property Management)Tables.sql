-- Nawy Unlocked (Property Management) Tables

-- TABLE: MANAGEMENT_CONTRACT (Nawy Unlocked)

CREATE TABLE nawy.MANAGEMENT_CONTRACT (
    contract_id             BIGINT IDENTITY(1,1)    NOT NULL,
    property_id             BIGINT                  NOT NULL,
    owner_user_id           BIGINT                  NOT NULL,
    service_type            NVARCHAR(50)            NOT NULL,
    management_fee_percent  DECIMAL(5,4)            NOT NULL CONSTRAINT DF_MGMT_fee DEFAULT (0.1000),
    financing_percent       DECIMAL(5,4)            NOT NULL CONSTRAINT DF_MGMT_financing DEFAULT (0.5000),
    contract_start          DATE                    NOT NULL,
    contract_end            DATE                    NULL,
    status                  NVARCHAR(20)            NOT NULL CONSTRAINT DF_MGMT_status DEFAULT ('active'),

    CONSTRAINT PK_MANAGEMENT_CONTRACT PRIMARY KEY CLUSTERED (contract_id),
    CONSTRAINT FK_MGMT_CONTRACT_PROPERTY FOREIGN KEY (property_id)
        REFERENCES nawy.PROPERTY(property_id) ON DELETE CASCADE,
    CONSTRAINT FK_MGMT_CONTRACT_OWNER FOREIGN KEY (owner_user_id)
        REFERENCES nawy.[USER](user_id),
    CONSTRAINT CK_MGMT_CONTRACT_service CHECK (service_type IN
        ('finishing','furnishing','full_management','rental_only')),
    CONSTRAINT CK_MGMT_CONTRACT_status CHECK (status IN ('active','expired','terminated')),
    CONSTRAINT CK_MGMT_CONTRACT_fee CHECK (management_fee_percent BETWEEN 0 AND 1),
    CONSTRAINT CK_MGMT_CONTRACT_financing CHECK (financing_percent BETWEEN 0 AND 0.5),
    CONSTRAINT CK_MGMT_CONTRACT_dates CHECK (contract_end IS NULL OR contract_end >= contract_start)
);
GO


-- TABLE: FINISHING_PROJECT

CREATE TABLE nawy.FINISHING_PROJECT (
    project_id          BIGINT IDENTITY(1,1)    NOT NULL,
    contract_id         BIGINT                  NOT NULL,
    scope               NVARCHAR(50)            NOT NULL,
    budget              DECIMAL(12,2)           NULL,
    actual_cost         DECIMAL(12,2)           NULL,
    start_date          DATE                    NULL,
    completion_date     DATE                    NULL,
    status              NVARCHAR(20)            NOT NULL CONSTRAINT DF_FINISHING_status DEFAULT ('planned'),

    CONSTRAINT PK_FINISHING_PROJECT PRIMARY KEY CLUSTERED (project_id),
    CONSTRAINT FK_FINISHING_CONTRACT FOREIGN KEY (contract_id)
        REFERENCES nawy.MANAGEMENT_CONTRACT(contract_id) ON DELETE CASCADE,
    CONSTRAINT CK_FINISHING_scope CHECK (scope IN
        ('core_shell','semi_finished','refurbishment','furnishing')),
    CONSTRAINT CK_FINISHING_status CHECK (status IN ('planned','in_progress','completed')),
    CONSTRAINT CK_FINISHING_budget CHECK (budget IS NULL OR budget >= 0),
    CONSTRAINT CK_FINISHING_actual CHECK (actual_cost IS NULL OR actual_cost >= 0),
    CONSTRAINT CK_FINISHING_dates CHECK (completion_date IS NULL OR start_date IS NULL OR completion_date >= start_date)
);
GO


-- TABLE: TENANT

CREATE TABLE nawy.TENANT (
    tenant_id           BIGINT IDENTITY(1,1)    NOT NULL,
    user_id             BIGINT                  NOT NULL,
    verification_status NVARCHAR(20)            NOT NULL CONSTRAINT DF_TENANT_verification DEFAULT ('pending'),
    employment_status   NVARCHAR(50)            NULL,
    monthly_income      DECIMAL(12,2)           NULL,

    CONSTRAINT PK_TENANT PRIMARY KEY CLUSTERED (tenant_id),
    CONSTRAINT UQ_TENANT_user UNIQUE (user_id),
    CONSTRAINT FK_TENANT_USER FOREIGN KEY (user_id)
        REFERENCES nawy.[USER](user_id) ON DELETE CASCADE,
    CONSTRAINT CK_TENANT_verification CHECK (verification_status IN ('pending','verified')),
    CONSTRAINT CK_TENANT_income CHECK (monthly_income IS NULL OR monthly_income >= 0)
);
GO


-- TABLE: LEASE

CREATE TABLE nawy.LEASE (
    lease_id            BIGINT IDENTITY(1,1)    NOT NULL,
    property_id         BIGINT                  NOT NULL,
    contract_id         BIGINT                  NOT NULL,
    tenant_id           BIGINT                  NOT NULL,
    start_date          DATE                    NOT NULL,
    end_date            DATE                    NOT NULL,
    monthly_rent        DECIMAL(12,2)           NOT NULL,
    security_deposit    DECIMAL(12,2)           NULL,
    status              NVARCHAR(20)            NOT NULL CONSTRAINT DF_LEASE_status DEFAULT ('active'),

    CONSTRAINT PK_LEASE PRIMARY KEY CLUSTERED (lease_id),
    CONSTRAINT FK_LEASE_PROPERTY FOREIGN KEY (property_id)
        REFERENCES nawy.PROPERTY(property_id),
    CONSTRAINT FK_LEASE_CONTRACT FOREIGN KEY (contract_id)
        REFERENCES nawy.MANAGEMENT_CONTRACT(contract_id),
    CONSTRAINT FK_LEASE_TENANT FOREIGN KEY (tenant_id)
        REFERENCES nawy.TENANT(tenant_id),
    CONSTRAINT CK_LEASE_status CHECK (status IN ('active','expired','terminated')),
    CONSTRAINT CK_LEASE_dates CHECK (end_date > start_date),
    CONSTRAINT CK_LEASE_rent CHECK (monthly_rent > 0),
    CONSTRAINT CK_LEASE_deposit CHECK (security_deposit IS NULL OR security_deposit >= 0)
);
GO


-- TABLE: RENT_PAYMENT

CREATE TABLE nawy.RENT_PAYMENT (
    rent_payment_id BIGINT IDENTITY(1,1)    NOT NULL,
    lease_id        BIGINT                  NOT NULL,
    amount          DECIMAL(12,2)           NOT NULL,
    due_date        DATE                    NOT NULL,
    paid_date       DATE                    NULL,
    status          NVARCHAR(20)            NOT NULL CONSTRAINT DF_RENT_PAYMENT_status DEFAULT ('pending'),

    CONSTRAINT PK_RENT_PAYMENT PRIMARY KEY CLUSTERED (rent_payment_id),
    CONSTRAINT FK_RENT_PAYMENT_LEASE FOREIGN KEY (lease_id)
        REFERENCES nawy.LEASE(lease_id) ON DELETE CASCADE,
    CONSTRAINT CK_RENT_PAYMENT_status CHECK (status IN ('pending','paid','overdue')),
    CONSTRAINT CK_RENT_PAYMENT_amount CHECK (amount > 0)
);
GO

