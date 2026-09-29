-- Property Tables

-- TABLE: DEVELOPER

CREATE TABLE nawy.DEVELOPER (
    developer_id    BIGINT IDENTITY(1,1)    NOT NULL,
    name            NVARCHAR(255)           NOT NULL,
    description     NVARCHAR(MAX)           NULL,
    contact_email   NVARCHAR(255)           NULL,
    contact_phone   NVARCHAR(20)            NULL,
    total_projects  INT                     NOT NULL CONSTRAINT DF_DEVELOPER_total_projects DEFAULT (0),
    partnership_tier NVARCHAR(20)           NOT NULL CONSTRAINT DF_DEVELOPER_tier DEFAULT ('standard'),
    created_at      DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_DEVELOPER_created_at DEFAULT (SYSDATETIMEOFFSET()),

    CONSTRAINT PK_DEVELOPER PRIMARY KEY CLUSTERED (developer_id),
    CONSTRAINT CK_DEVELOPER_tier CHECK (partnership_tier IN ('standard','premium','exclusive')),
    CONSTRAINT CK_DEVELOPER_total_projects CHECK (total_projects >= 0)
);
GO


-- TABLE: PROPERTY

CREATE TABLE nawy.PROPERTY (
    property_id         BIGINT IDENTITY(1,1)    NOT NULL,
    title               NVARCHAR(500)           NOT NULL,
    description         NVARCHAR(MAX)           NULL,
    property_type       NVARCHAR(50)            NOT NULL,
    listing_type        NVARCHAR(20)            NOT NULL,
    city                NVARCHAR(100)           NOT NULL,
    district            NVARCHAR(100)           NULL,
    compound_name       NVARCHAR(255)           NULL,
    latitude            DECIMAL(10,8)           NULL,
    longitude           DECIMAL(11,8)           NULL,
    bedrooms            INT                     NULL,
    bathrooms           INT                     NULL,
    area_sqm            DECIMAL(10,2)           NULL,
    finishing_status    NVARCHAR(50)            NULL,
    furnished_status    NVARCHAR(50)            NULL,
    price               DECIMAL(15,2)           NOT NULL,
    currency            NVARCHAR(3)             NOT NULL CONSTRAINT DF_PROPERTY_currency DEFAULT ('EGP'),
    delivery_date       DATE                    NULL,
    status              NVARCHAR(20)            NOT NULL CONSTRAINT DF_PROPERTY_status DEFAULT ('active'),
    developer_id        BIGINT                  NULL,
    owner_user_id       BIGINT                  NULL,
    listing_broker_id   BIGINT                  NULL,
    created_at          DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_PROPERTY_created_at DEFAULT (SYSDATETIMEOFFSET()),
    updated_at          DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_PROPERTY_updated_at DEFAULT (SYSDATETIMEOFFSET()),

    CONSTRAINT PK_PROPERTY PRIMARY KEY CLUSTERED (property_id),
    CONSTRAINT FK_PROPERTY_DEVELOPER FOREIGN KEY (developer_id)
        REFERENCES nawy.DEVELOPER(developer_id) ON DELETE SET NULL,
    CONSTRAINT FK_PROPERTY_OWNER FOREIGN KEY (owner_user_id)
        REFERENCES nawy.[USER](user_id),  -- No cascade (multiple paths)
    CONSTRAINT FK_PROPERTY_BROKER FOREIGN KEY (listing_broker_id)
        REFERENCES nawy.BROKER(broker_id),  -- No cascade (multiple paths)
    CONSTRAINT CK_PROPERTY_type CHECK (property_type IN
        ('apartment','villa','townhouse','office','chalet','duplex')),
    CONSTRAINT CK_PROPERTY_listing_type CHECK (listing_type IN ('primary','resale','rental')),
    CONSTRAINT CK_PROPERTY_finishing CHECK (finishing_status IS NULL OR finishing_status IN
        ('shell','semi_finished','finished','luxury')),
    CONSTRAINT CK_PROPERTY_furnished CHECK (furnished_status IS NULL OR furnished_status IN
        ('unfurnished','semi_furnished','fully_furnished')),
    CONSTRAINT CK_PROPERTY_status CHECK (status IN
        ('active','sold','rented','reserved','under_offer')),
    CONSTRAINT CK_PROPERTY_currency CHECK (currency IN ('EGP','USD')),
    CONSTRAINT CK_PROPERTY_price CHECK (price > 0),
    CONSTRAINT CK_PROPERTY_area CHECK (area_sqm IS NULL OR area_sqm > 0),
    CONSTRAINT CK_PROPERTY_bedrooms CHECK (bedrooms IS NULL OR bedrooms >= 0),
    CONSTRAINT CK_PROPERTY_bathrooms CHECK (bathrooms IS NULL OR bathrooms >= 0),
    -- Business rule: primary listings must have developer
    CONSTRAINT CK_PROPERTY_primary_has_developer CHECK
        (listing_type <> 'primary' OR developer_id IS NOT NULL),
    -- Business rule: resale listings must have owner
    CONSTRAINT CK_PROPERTY_resale_has_owner CHECK
        (listing_type <> 'resale' OR owner_user_id IS NOT NULL)
);
GO


-- TABLE: PROPERTY_MEDIA

CREATE TABLE nawy.PROPERTY_MEDIA (
    media_id        BIGINT IDENTITY(1,1)    NOT NULL,
    property_id     BIGINT                  NOT NULL,
    media_type      NVARCHAR(20)            NOT NULL,
    url             NVARCHAR(MAX)           NOT NULL,
    display_order   INT                     NOT NULL CONSTRAINT DF_PROPERTY_MEDIA_order DEFAULT (0),
    is_primary      BIT                     NOT NULL CONSTRAINT DF_PROPERTY_MEDIA_is_primary DEFAULT (0),
    uploaded_at     DATETIMEOFFSET(7)       NOT NULL CONSTRAINT DF_PROPERTY_MEDIA_uploaded_at DEFAULT (SYSDATETIMEOFFSET()),

    CONSTRAINT PK_PROPERTY_MEDIA PRIMARY KEY CLUSTERED (media_id),
    CONSTRAINT FK_PROPERTY_MEDIA_PROPERTY FOREIGN KEY (property_id)
        REFERENCES nawy.PROPERTY(property_id) ON DELETE CASCADE,
    CONSTRAINT CK_PROPERTY_MEDIA_type CHECK (media_type IN ('image','video','virtual_tour')),
    CONSTRAINT CK_PROPERTY_MEDIA_order CHECK (display_order >= 0)
);
GO

