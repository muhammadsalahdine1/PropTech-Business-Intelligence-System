# Nawy Proptech Platform — Database Design

> **A complete, production-ready data model for Egypt's largest proptech ecosystem**

![SQL Server](https://img.shields.io/badge/SQL%20Server-2019%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Tables](https://img.shields.io/badge/tables-20-orange)
![Relationships](https://img.shields.io/badge/relationships-34-yellow)
![Views](https://img.shields.io/badge/analytical%20views-23-purple)

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Business Context](#-business-context)
- [Architecture Principles](#-architecture-principles)
- [Entity-Relationship Diagram](#-entity-relationship-diagram)
- [Table Descriptions](#-table-descriptions)
- [Relationship Mapping](#-relationship-mapping)
- [Data Dictionary](#-data-dictionary)
- [Constraints & Business Rules](#-constraints--business-rules)
- [Indexes & Performance](#-indexes--performance)
- [Analytical Views](#-analytical-views)

---

## 🎯 Overview

This repository contains the **complete database design and implementation** for a Nawy-style proptech platform — a vertically integrated real estate ecosystem serving buyers, sellers, investors, and brokers across Egypt and Africa.

The design models Nawy's **five distinct business lines**:

| Business Line | Function | Revenue Model |
|---------------|----------|---------------|
| **Nawy Properties** | Multi-listing service (MLS) for buying/selling | Listing fees + transaction commissions |
| **Nawy Partners** | B2B platform for MSME brokers | Commission share on closed deals |
| **Nawy Now** | FRA-licensed mortgage origination | Interest on mortgage loans |
| **Nawy Shares** | Fractional ownership platform | Exit fees + management fees |
| **Nawy Unlocked** | Property finishing, furnishing & rental management | Management fees + finishing financing |

### 📦 Deliverables

| Deliverable | Status |
|-------------|--------|
| **20 tables** covering all business operations | ✅ |
| **34 relationships** with full referential integrity | ✅ |
| **23 analytical views** for BI tools | ✅ |
| **~13,000 sample records** across 5 years (2021–2026) | ✅ |
| **Complete SQL Server DDL** and data generation scripts | ✅ |
| **Regulatory compliance** with Egyptian FRA requirements | ✅ |

---

## 🏢 Business Context

### What is Nawy?

Nawy is Egypt's leading proptech company, serving over **1 million monthly active users** and **3,000+ MSME real estate brokerages**. The platform connects property buyers, sellers, developers, investors, and brokers through a unified digital experience.

### Why This Data Model Exists

A traditional real estate platform would only need a `PROPERTY` and `USER` table. Nawy is different — it operates **five complementary business lines** that must share data while remaining functionally independent:

**1. Same property, multiple purposes**
A single property can simultaneously be:
- A listing on **Nawy Properties**
- The target of a **Nawy Now** mortgage application
- The underlying asset of a **Nawy Shares** offering
- A managed unit under **Nawy Unlocked**

**2. Same user, multiple roles**
A user can be a buyer, seller, investor, broker, or landlord at the same time. Nawy's growth strategy depends on cross-selling across these roles.

**3. Regulated financial services**
Nawy Now and Nawy Shares are licensed by Egypt's **Financial Regulatory Authority (FRA)**, requiring strict KYC, escrow, and reporting.

**4. Data-driven decision making**
The platform uses machine learning and tailored algorithms to recommend properties and predict buyer behavior. This requires a rich, well-structured data foundation.

This data model was designed to support all four requirements without compromise.

---

## 🏗️ Architecture Principles

The database design follows **seven core principles**:

| # | Principle | Implementation |
|---|-----------|----------------|
| 1 | **Single Source of Identity** | All actors trace back to `USER.user_id` |
| 2 | **Single Source of Asset** | All property transactions trace back to `PROPERTY.property_id` |
| 3 | **Separation of Business Lines** | Each service (Now, Shares, Unlocked) has dedicated tables |
| 4 | **Explicit Financial Flows** | Every money movement has its own table with status tracking |
| 5 | **Regulatory Traceability** | Full audit trails for FRA and Real Estate Public Authority compliance |
| 6 | **Analytical Enablement** | Denormalized views for BI tools (Tableau, Power BI) |
| 7 | **Referential Integrity** | Strict FK constraints with CASCADE/SET NULL semantics |

---

## 📊 Entity-Relationship Diagram

### High-Level Domain View

```mermaid
graph TB
    subgraph "User Domain"
        USER[USER]
        BROKER[BROKER]
        BROKER_TEAM[BROKER_TEAM]
        TENANT[TENANT]
    end

    subgraph "Property Domain"
        DEVELOPER[DEVELOPER]
        PROPERTY[PROPERTY]
        PROPERTY_MEDIA[PROPERTY_MEDIA]
    end

    subgraph "Sales Pipeline"
        LEAD[LEAD]
        DEAL[DEAL]
        COMMISSION[COMMISSION]
    end

    subgraph "Nawy Now"
        MORTGAGE_APPLICATION[MORTGAGE_APPLICATION]
        MORTGAGE_PAYMENT[MORTGAGE_PAYMENT]
    end

    subgraph "Nawy Shares"
        SHARE_OFFERING[SHARE_OFFERING]
        SHARE_INVESTMENT[SHARE_INVESTMENT]
        SHARE_EXIT[SHARE_EXIT]
    end

    subgraph "Nawy Unlocked"
        MANAGEMENT_CONTRACT[MANAGEMENT_CONTRACT]
        FINISHING_PROJECT[FINISHING_PROJECT]
        LEASE[LEASE]
        RENT_PAYMENT[RENT_PAYMENT]
    end

    subgraph "Compliance"
        ESCROW_ACCOUNT[ESCROW_ACCOUNT]
    end

    USER --> BROKER
    USER --> TENANT
    USER --> LEAD
    USER --> MORTGAGE_APPLICATION
    USER --> SHARE_INVESTMENT
    USER --> MANAGEMENT_CONTRACT
    USER --> PROPERTY

    BROKER --> BROKER_TEAM
    BROKER --> PROPERTY
    BROKER --> LEAD
    BROKER --> DEAL
    BROKER --> COMMISSION

    DEVELOPER --> PROPERTY
    PROPERTY --> PROPERTY_MEDIA
    PROPERTY --> LEAD
    PROPERTY --> DEAL
    PROPERTY --> MORTGAGE_APPLICATION
    PROPERTY --> SHARE_OFFERING
    PROPERTY --> MANAGEMENT_CONTRACT
    PROPERTY --> LEASE
    PROPERTY --> ESCROW_ACCOUNT

    LEAD --> DEAL
    DEAL --> COMMISSION
    DEAL --> ESCROW_ACCOUNT

    MORTGAGE_APPLICATION --> MORTGAGE_PAYMENT
    MORTGAGE_APPLICATION --> ESCROW_ACCOUNT

    SHARE_OFFERING --> SHARE_INVESTMENT
    SHARE_INVESTMENT --> SHARE_EXIT

    MANAGEMENT_CONTRACT --> FINISHING_PROJECT
    MANAGEMENT_CONTRACT --> LEASE
    LEASE --> RENT_PAYMENT
    TENANT --> LEASE
```

### Detailed ERD

```mermaid
erDiagram
    USER ||--o| BROKER : "can be"
    USER ||--o{ BROKER_TEAM : "member of"
    USER ||--o{ PROPERTY : "owns"
    USER ||--o{ LEAD : "creates"
    USER ||--o{ DEAL : "buys"
    USER ||--o{ MORTGAGE_APPLICATION : "applies for"
    USER ||--o{ SHARE_INVESTMENT : "invests"
    USER ||--o{ MANAGEMENT_CONTRACT : "engages"
    USER ||--o| TENANT : "can be"

    BROKER ||--o{ BROKER_TEAM : "manages"
    BROKER ||--o{ PROPERTY : "lists"
    BROKER ||--o{ LEAD : "handles"
    BROKER ||--o{ DEAL : "closes"
    BROKER ||--o{ COMMISSION : "earns"

    DEVELOPER ||--o{ PROPERTY : "develops"

    PROPERTY ||--o{ PROPERTY_MEDIA : "has"
    PROPERTY ||--o{ LEAD : "generates"
    PROPERTY ||--o{ DEAL : "sold in"
    PROPERTY ||--o{ MORTGAGE_APPLICATION : "financed under"
    PROPERTY ||--o| SHARE_OFFERING : "underlies"
    PROPERTY ||--o| MANAGEMENT_CONTRACT : "managed under"
    PROPERTY ||--o{ LEASE : "rented under"
    PROPERTY ||--o{ ESCROW_ACCOUNT : "secured by"

    LEAD ||--o| DEAL : "converts to"
    DEAL ||--o| COMMISSION : "generates"
    DEAL ||--o| ESCROW_ACCOUNT : "may use"

    MORTGAGE_APPLICATION ||--o{ MORTGAGE_PAYMENT : "has"
    MORTGAGE_APPLICATION ||--o{ ESCROW_ACCOUNT : "may use"

    SHARE_OFFERING ||--o{ SHARE_INVESTMENT : "receives"
    SHARE_INVESTMENT ||--o| SHARE_EXIT : "can exit"

    MANAGEMENT_CONTRACT ||--o| FINISHING_PROJECT : "includes"
    MANAGEMENT_CONTRACT ||--o{ LEASE : "administers"
    TENANT ||--o{ LEASE : "signs"
    LEASE ||--o{ RENT_PAYMENT : "has"
```

### Relationship Summary

| Domain | Tables | Key Relationships |
|--------|--------|-------------------|
| **User** | 4 | USER extends to BROKER, TENANT; BROKER manages BROKER_TEAM |
| **Property** | 3 | DEVELOPER supplies PROPERTY; PROPERTY has PROPERTY_MEDIA |
| **Sales** | 3 | LEAD converts to DEAL; DEAL generates COMMISSION |
| **Nawy Now** | 2 | MORTGAGE_APPLICATION has many MORTGAGE_PAYMENT |
| **Nawy Shares** | 3 | SHARE_OFFERING receives SHARE_INVESTMENT; investment has SHARE_EXIT |
| **Nawy Unlocked** | 4 | MANAGEMENT_CONTRACT includes FINISHING_PROJECT and LEASE; LEASE has RENT_PAYMENT |
| **Compliance** | 1 | ESCROW_ACCOUNT linked to DEAL or MORTGAGE_APPLICATION |

---

## 📋 Table Descriptions

### Group 1 — User & Access Management

#### `USER`
Central identity table for all platform participants.

| Column | Type | Description |
|--------|------|-------------|
| `user_id` | BIGINT (PK) | Unique identifier |
| `email` | NVARCHAR(255) | Login identifier (unique) |
| `phone` | NVARCHAR(20) | Mobile number (unique) |
| `full_name` | NVARCHAR(255) | Display name |
| `user_type` | NVARCHAR(50) | buyer, seller, investor, broker, admin |
| `national_id` | NVARCHAR(14) | Egyptian national ID (unique) |
| `password_hash` | NVARCHAR(MAX) | Bcrypt hash |
| `is_verified` | BIT | Email/phone verified |
| `created_at` | DATETIMEOFFSET | Registration timestamp |
| `updated_at` | DATETIMEOFFSET | Last profile change |

#### `BROKER`
Extended profile for MSME real estate brokers on Nawy Partners.

| Column | Type | Description |
|--------|------|-------------|
| `broker_id` | BIGINT (PK) | Unique identifier |
| `user_id` | BIGINT (FK) | References `USER` (unique) |
| `broker_type` | NVARCHAR(50) | freelancer, agency |
| `agency_name` | NVARCHAR(255) | Agency name (NULL for freelancers) |
| `license_number` | NVARCHAR(100) | Real Estate Public Authority license |
| `commission_rate` | DECIMAL(5,4) | Default commission (2.5%) |
| `team_size` | INT | Number of sub-agents |
| `status` | NVARCHAR(20) | active, suspended, inactive |
| `joined_at` | DATETIMEOFFSET | Platform join date |

#### `BROKER_TEAM`
Junction table for agency brokers managing sub-agents.

| Column | Type | Description |
|--------|------|-------------|
| `team_id` | BIGINT (PK) | Unique identifier |
| `broker_id` | BIGINT (FK) | Agency broker |
| `member_user_id` | BIGINT (FK) | Team member |
| `role` | NVARCHAR(50) | senior_agent, junior_agent |
| `added_at` | DATETIMEOFFSET | Join date |

#### `TENANT`
Extended profile for verified renters under Nawy Unlocked.

| Column | Type | Description |
|--------|------|-------------|
| `tenant_id` | BIGINT (PK) | Unique identifier |
| `user_id` | BIGINT (FK) | References `USER` (unique) |
| `verification_status` | NVARCHAR(20) | pending, verified |
| `employment_status` | NVARCHAR(50) | employed, self_employed, etc. |
| `monthly_income` | DECIMAL(12,2) | For affordability checks |

---

### Group 2 — Property & Listings

#### `DEVELOPER`
Real estate developer companies.

| Column | Type | Description |
|--------|------|-------------|
| `developer_id` | BIGINT (PK) | Unique identifier |
| `name` | NVARCHAR(255) | Company name |
| `description` | NVARCHAR(MAX) | Company overview |
| `contact_email` | NVARCHAR(255) | B2B contact |
| `contact_phone` | NVARCHAR(20) | B2B phone |
| `total_projects` | INT | Active project count |
| `partnership_tier` | NVARCHAR(20) | standard, premium, exclusive |
| `created_at` | DATETIMEOFFSET | Record creation |

#### `PROPERTY`
Core asset table — central to all business lines.

| Column | Type | Description |
|--------|------|-------------|
| `property_id` | BIGINT (PK) | Unique identifier |
| `title` | NVARCHAR(500) | Listing title |
| `description` | NVARCHAR(MAX) | Full description |
| `property_type` | NVARCHAR(50) | apartment, villa, townhouse, office, chalet, duplex |
| `listing_type` | NVARCHAR(20) | primary, resale, rental |
| `city` | NVARCHAR(100) | City name |
| `district` | NVARCHAR(100) | Neighborhood |
| `compound_name` | NVARCHAR(255) | Compound/project name |
| `latitude`, `longitude` | DECIMAL | GPS coordinates |
| `bedrooms`, `bathrooms` | INT | Room counts |
| `area_sqm` | DECIMAL(10,2) | Area in square meters |
| `finishing_status` | NVARCHAR(50) | shell, semi_finished, finished, luxury |
| `furnished_status` | NVARCHAR(50) | unfurnished, semi_furnished, fully_furnished |
| `price` | DECIMAL(15,2) | Listing price |
| `currency` | NVARCHAR(3) | EGP, USD |
| `delivery_date` | DATE | Expected delivery (off-plan) |
| `status` | NVARCHAR(20) | active, sold, rented, reserved, under_offer |
| `developer_id` | BIGINT (FK) | References `DEVELOPER` |
| `owner_user_id` | BIGINT (FK) | References `USER` |
| `listing_broker_id` | BIGINT (FK) | References `BROKER` |

#### `PROPERTY_MEDIA`
Images, videos, and virtual tours per property.

| Column | Type | Description |
|--------|------|-------------|
| `media_id` | BIGINT (PK) | Unique identifier |
| `property_id` | BIGINT (FK) | References `PROPERTY` |
| `media_type` | NVARCHAR(20) | image, video, virtual_tour |
| `url` | NVARCHAR(MAX) | CDN URL |
| `display_order` | INT | Sort order |
| `is_primary` | BIT | Primary image flag |
| `uploaded_at` | DATETIMEOFFSET | Upload timestamp |

---

### Group 3 — Sales Pipeline

#### `LEAD`
Buyer interest and sales funnel tracking.

| Column | Type | Description |
|--------|------|-------------|
| `lead_id` | BIGINT (PK) | Unique identifier |
| `property_id` | BIGINT (FK) | References `PROPERTY` |
| `buyer_user_id` | BIGINT (FK) | References `USER` |
| `broker_id` | BIGINT (FK) | Assigned broker |
| `status` | NVARCHAR(30) | new, contacted, viewing, negotiation, closed_won, closed_lost |
| `source` | NVARCHAR(50) | website, app, broker_referral, walk_in |
| `notes` | NVARCHAR(MAX) | Broker notes |
| `created_at` | DATETIMEOFFSET | Lead creation |
| `last_activity_at` | DATETIMEOFFSET | Last interaction |

#### `DEAL`
Completed property transactions.

| Column | Type | Description |
|--------|------|-------------|
| `deal_id` | BIGINT (PK) | Unique identifier |
| `lead_id` | BIGINT (FK) | Originating lead |
| `property_id` | BIGINT (FK) | Sold property |
| `buyer_user_id` | BIGINT (FK) | Buyer |
| `broker_id` | BIGINT (FK) | Closing broker |
| `sale_price` | DECIMAL(15,2) | Final sale price |
| `payment_type` | NVARCHAR(20) | cash, installment, mortgage |
| `status` | NVARCHAR(20) | pending, approved, completed, cancelled |
| `closed_at` | DATETIMEOFFSET | Closing timestamp |

#### `COMMISSION`
Broker commission payments from completed deals.

| Column | Type | Description |
|--------|------|-------------|
| `commission_id` | BIGINT (PK) | Unique identifier |
| `deal_id` | BIGINT (FK) | References `DEAL` |
| `broker_id` | BIGINT (FK) | Receiving broker |
| `commission_amount` | DECIMAL(12,2) | Amount |
| `commission_rate` | DECIMAL(5,4) | Applied rate |
| `status` | NVARCHAR(20) | pending, paid |
| `paid_at` | DATETIMEOFFSET | Payment timestamp |

---

### Group 4 — Nawy Now (Mortgage)

#### `MORTGAGE_APPLICATION`
FRA-licensed mortgage origination applications.

| Column | Type | Description |
|--------|------|-------------|
| `application_id` | BIGINT (PK) | Unique identifier |
| `user_id` | BIGINT (FK) | Applicant |
| `property_id` | BIGINT (FK) | Property to finance |
| `property_price` | DECIMAL(15,2) | Full price |
| `down_payment` | DECIMAL(15,2) | ≥ 10% of price |
| `loan_amount` | DECIMAL(15,2) | = price − down |
| `installment_months` | INT | 36 to 120 |
| `interest_rate` | DECIMAL(5,4) | Annual rate |
| `monthly_payment` | DECIMAL(12,2) | Fixed installment |
| `status` | NVARCHAR(30) | submitted, under_review, approved, rejected, disbursed |
| `submitted_at` | DATETIMEOFFSET | Submission |
| `approved_at` | DATETIMEOFFSET | Approval timestamp |

#### `MORTGAGE_PAYMENT`
Individual installment payments.

| Column | Type | Description |
|--------|------|-------------|
| `payment_id` | BIGINT (PK) | Unique identifier |
| `application_id` | BIGINT (FK) | Parent application |
| `installment_number` | INT | Sequential number |
| `amount_due` | DECIMAL(12,2) | Expected payment |
| `amount_paid` | DECIMAL(12,2) | Actual payment |
| `due_date` | DATE | Due date |
| `paid_date` | DATE | Payment date |
| `status` | NVARCHAR(20) | pending, paid, overdue |

---

### Group 5 — Nawy Shares (Fractional Investment)

#### `SHARE_OFFERING`
Fractional ownership offerings.

| Column | Type | Description |
|--------|------|-------------|
| `offering_id` | BIGINT (PK) | Unique identifier |
| `property_id` | BIGINT (FK) | Underlying property (unique) |
| `total_value` | DECIMAL(15,2) | Total property value |
| `share_price` | DECIMAL(12,2) | Price per share |
| `total_shares` | INT | Total shares available |
| `shares_available` | INT | Remaining shares |
| `offering_open_date` | DATE | Subscription start |
| `offering_close_date` | DATE | Subscription end |
| `exit_condition` | NVARCHAR(MAX) | Exit criteria |
| `status` | NVARCHAR(20) | upcoming, open, closed, sold_out |

#### `SHARE_INVESTMENT`
Individual investor purchases of fractional shares.

| Column | Type | Description |
|--------|------|-------------|
| `investment_id` | BIGINT (PK) | Unique identifier |
| `offering_id` | BIGINT (FK) | Parent offering |
| `user_id` | BIGINT (FK) | Investor |
| `shares_purchased` | INT | Number of shares |
| `total_amount` | DECIMAL(12,2) | Amount paid |
| `investment_date` | DATETIMEOFFSET | Purchase date |
| `status` | NVARCHAR(20) | active, exited |

#### `SHARE_EXIT`
Records the sale/exit of a fractional investment.

| Column | Type | Description |
|--------|------|-------------|
| `exit_id` | BIGINT (PK) | Unique identifier |
| `investment_id` | BIGINT (FK) | Investment being exited (unique) |
| `exit_price_per_share` | DECIMAL(12,2) | Sale price per share |
| `total_sale_value` | DECIMAL(15,2) | Total proceeds |
| `exit_fee_percent` | DECIMAL(5,4) | 2.5%–5% |
| `profit_loss` | DECIMAL(12,2) | Net gain/loss |
| `exit_date` | DATE | Exit date |
| `status` | NVARCHAR(20) | pending, completed |

---

### Group 6 — Nawy Unlocked (Property Management)

#### `MANAGEMENT_CONTRACT`
Property management agreements.

| Column | Type | Description |
|--------|------|-------------|
| `contract_id` | BIGINT (PK) | Unique identifier |
| `property_id` | BIGINT (FK) | Managed property |
| `owner_user_id` | BIGINT (FK) | Property owner |
| `service_type` | NVARCHAR(50) | finishing, furnishing, full_management, rental_only |
| `management_fee_percent` | DECIMAL(5,4) | Fee on rental income |
| `financing_percent` | DECIMAL(5,4) | Up to 50% of finishing costs |
| `contract_start` | DATE | Start date |
| `contract_end` | DATE | End date |
| `status` | NVARCHAR(20) | active, expired, terminated |

#### `FINISHING_PROJECT`
Finishing and furnishing work under a management contract.

| Column | Type | Description |
|--------|------|-------------|
| `project_id` | BIGINT (PK) | Unique identifier |
| `contract_id` | BIGINT (FK) | Parent contract |
| `scope` | NVARCHAR(50) | core_shell, semi_finished, refurbishment, furnishing |
| `budget` | DECIMAL(12,2) | Planned budget |
| `actual_cost` | DECIMAL(12,2) | Actual cost |
| `start_date` | DATE | Work start |
| `completion_date` | DATE | Work completion |
| `status` | NVARCHAR(20) | planned, in_progress, completed |

#### `LEASE`
Rental agreements between tenants and managed properties.

| Column | Type | Description |
|--------|------|-------------|
| `lease_id` | BIGINT (PK) | Unique identifier |
| `property_id` | BIGINT (FK) | Rented property |
| `contract_id` | BIGINT (FK) | Parent management contract |
| `tenant_id` | BIGINT (FK) | Tenant |
| `start_date` | DATE | Lease start |
| `end_date` | DATE | Lease end |
| `monthly_rent` | DECIMAL(12,2) | Monthly amount |
| `security_deposit` | DECIMAL(12,2) | Refundable deposit |
| `status` | NVARCHAR(20) | active, expired, terminated |

#### `RENT_PAYMENT`
Individual rent payments.

| Column | Type | Description |
|--------|------|-------------|
| `rent_payment_id` | BIGINT (PK) | Unique identifier |
| `lease_id` | BIGINT (FK) | Parent lease |
| `amount` | DECIMAL(12,2) | Payment amount |
| `due_date` | DATE | Due date |
| `paid_date` | DATE | Payment date |
| `status` | NVARCHAR(20) | pending, paid, overdue |

---

### Group 7 — Compliance

#### `ESCROW_ACCOUNT`
Regulatory escrow accounts for off-plan and mortgage transactions.

| Column | Type | Description |
|--------|------|-------------|
| `escrow_id` | BIGINT (PK) | Unique identifier |
| `deal_id` | BIGINT (FK) | Associated deal (nullable) |
| `mortgage_id` | BIGINT (FK) | Associated mortgage (nullable) |
| `property_id` | BIGINT (FK) | Secured property |
| `bank_name` | NVARCHAR(255) | Escrow bank |
| `account_number` | NVARCHAR(50) | Bank account reference |
| `deposit_amount` | DECIMAL(15,2) | Amount held |
| `release_condition` | NVARCHAR(MAX) | Release conditions |
| `release_date` | DATE | Actual release |
| `status` | NVARCHAR(20) | active, released, disputed |

---

## 🔗 Relationship Mapping

### Complete Relationship Matrix

| # | Parent Table | Child Table | Cardinality | FK Column | On Delete |
|---|--------------|-------------|-------------|-----------|-----------|
| 1 | USER | BROKER | 1:0..1 | broker.user_id | CASCADE |
| 2 | BROKER | BROKER_TEAM | 1:N | broker_team.broker_id | CASCADE |
| 3 | USER | BROKER_TEAM | 1:N | broker_team.member_user_id | NO ACTION |
| 4 | USER | PROPERTY (owner) | 1:N | property.owner_user_id | NO ACTION |
| 5 | BROKER | PROPERTY (agent) | 1:N | property.listing_broker_id | NO ACTION |
| 6 | DEVELOPER | PROPERTY | 1:N | property.developer_id | SET NULL |
| 7 | PROPERTY | PROPERTY_MEDIA | 1:N | property_media.property_id | CASCADE |
| 8 | PROPERTY | LEAD | 1:N | lead.property_id | CASCADE |
| 9 | USER | LEAD | 1:N | lead.buyer_user_id | NO ACTION |
| 10 | BROKER | LEAD | 1:N | lead.broker_id | NO ACTION |
| 11 | LEAD | DEAL | 1:0..1 | deal.lead_id | SET NULL |
| 12 | PROPERTY | DEAL | 1:N | deal.property_id | NO ACTION |
| 13 | USER | DEAL | 1:N | deal.buyer_user_id | NO ACTION |
| 14 | BROKER | DEAL | 1:N | deal.broker_id | NO ACTION |
| 15 | DEAL | COMMISSION | 1:0..1 | commission.deal_id | CASCADE |
| 16 | BROKER | COMMISSION | 1:N | commission.broker_id | NO ACTION |
| 17 | USER | MORTGAGE_APPLICATION | 1:N | mortgage_application.user_id | NO ACTION |
| 18 | PROPERTY | MORTGAGE_APPLICATION | 1:N | mortgage_application.property_id | NO ACTION |
| 19 | MORTGAGE_APPLICATION | MORTGAGE_PAYMENT | 1:N | mortgage_payment.application_id | CASCADE |
| 20 | PROPERTY | SHARE_OFFERING | 1:0..1 | share_offering.property_id | CASCADE |
| 21 | SHARE_OFFERING | SHARE_INVESTMENT | 1:N | share_investment.offering_id | CASCADE |
| 22 | USER | SHARE_INVESTMENT | 1:N | share_investment.user_id | NO ACTION |
| 23 | SHARE_INVESTMENT | SHARE_EXIT | 1:0..1 | share_exit.investment_id | CASCADE |
| 24 | PROPERTY | MANAGEMENT_CONTRACT | 1:0..1 | management_contract.property_id | CASCADE |
| 25 | USER | MANAGEMENT_CONTRACT | 1:N | management_contract.owner_user_id | NO ACTION |
| 26 | MANAGEMENT_CONTRACT | FINISHING_PROJECT | 1:0..1 | finishing_project.contract_id | CASCADE |
| 27 | MANAGEMENT_CONTRACT | LEASE | 1:N | lease.contract_id | NO ACTION |
| 28 | PROPERTY | LEASE | 1:N | lease.property_id | NO ACTION |
| 29 | USER | TENANT | 1:0..1 | tenant.user_id | CASCADE |
| 30 | TENANT | LEASE | 1:N | lease.tenant_id | NO ACTION |
| 31 | LEASE | RENT_PAYMENT | 1:N | rent_payment.lease_id | CASCADE |
| 32 | DEAL | ESCROW_ACCOUNT | 1:0..1 | escrow_account.deal_id | SET NULL |
| 33 | MORTGAGE_APPLICATION | ESCROW_ACCOUNT | 1:N | escrow_account.mortgage_id | SET NULL |
| 34 | PROPERTY | ESCROW_ACCOUNT | 1:N | escrow_account.property_id | CASCADE |

### Relationship Explanations

**1. USER → BROKER (1:0..1)**
A user may optionally register as a broker. This preserves the single identity while extending broker-specific attributes like license, commission rate, and team size.

**2. BROKER → BROKER_TEAM (1:N)**
An agency broker can manage multiple team members. This reflects Nawy Partners' team management feature for agency accounts.

**6. DEVELOPER → PROPERTY (1:N)**
A developer can have many properties. Primary listings must have a developer; resale listings may have NULL (owned by individuals).

**11. LEAD → DEAL (1:0..1)**
A lead may convert to at most one deal. Not every lead converts — only those reaching `closed_won` status.

**15. DEAL → COMMISSION (1:0..1)**
A completed deal generates exactly one commission. Cancelled or pending deals have no commission.

**20. PROPERTY → SHARE_OFFERING (1:0..1)**
A property may have at most one active fractional offering. This constraint prevents oversubscription of the same asset.

**24. PROPERTY → MANAGEMENT_CONTRACT (1:0..1)**
A property may have at most one active management contract. Enforced via a filtered unique index on `(property_id) WHERE status = 'active'`.

**31. LEASE → RENT_PAYMENT (1:N)**
A lease generates recurring rent payments (typically 12–24 installments). This enables occupancy and default analytics.

**32–34. ESCROW_ACCOUNT relationships**
An escrow account references either a `DEAL` (for off-plan resale) or a `MORTGAGE_APPLICATION` (for mortgage disbursements), plus the underlying `PROPERTY`. The CHECK constraint ensures at least one parent reference exists.

---

## 📖 Data Dictionary

### Naming Conventions

| Pattern | Meaning | Example |
|---------|---------|---------|
| `*_id` | Primary key | `user_id`, `property_id` |
| `*_at` | Timestamp | `created_at`, `paid_at` |
| `*_date` | Date only | `due_date`, `delivery_date` |
| `is_*` | Boolean flag | `is_verified`, `is_primary` |
| `*_status` | Enum-like state | `status`, `payment_status` |
| `*_type` | Classification | `property_type`, `broker_type` |
| `*_percent` | Decimal 0–1 | `commission_rate`, `exit_fee_percent` |

### Common Column Types

| Type | Use |
|------|-----|
| `BIGINT IDENTITY(1,1)` | Primary keys |
| `NVARCHAR(n)` | Unicode strings (Arabic names, Egyptian addresses) |
| `NVARCHAR(MAX)` | Long text (descriptions, notes) |
| `DECIMAL(15,2)` | Monetary amounts (EGP) |
| `DECIMAL(5,4)` | Rates and percentages (0.0000–1.0000) |
| `DATETIMEOFFSET(7)` | Timezone-aware timestamps |
| `DATE` | Date-only values |
| `BIT` | Booleans |

### Table Naming Prefixes

| Prefix | Purpose | Example |
|--------|---------|---------|
| `PK_` | Primary key | `PK_USER` |
| `FK_` | Foreign key | `FK_PROPERTY_DEVELOPER` |
| `UQ_` | Unique constraint | `UQ_USER_email` |
| `UX_` | Unique index | `UX_LEASE_active_property` |
| `IX_` | Non-unique index | `IX_PROPERTY_city_district` |
| `CK_` | Check constraint | `CK_PROPERTY_type` |
| `DF_` | Default constraint | `DF_USER_created_at` |

---

## ⚖️ Constraints & Business Rules

### CHECK Constraints

| Constraint | Table | Rule |
|-----------|-------|------|
| `CK_USER_user_type` | USER | user_type IN (buyer, seller, investor, broker, admin) |
| `CK_BROKER_commission_rate` | BROKER | 0 ≤ commission_rate ≤ 1 |
| `CK_PROPERTY_type` | PROPERTY | property_type IN (apartment, villa, townhouse, office, chalet, duplex) |
| `CK_PROPERTY_primary_has_developer` | PROPERTY | Primary listings must have a developer |
| `CK_PROPERTY_resale_has_owner` | PROPERTY | Resale listings must have an owner |
| `CK_MORTGAGE_months` | MORTGAGE_APPLICATION | 36 ≤ installment_months ≤ 120 |
| `CK_MORTGAGE_down_min` | MORTGAGE_APPLICATION | down_payment ≥ 10% of property_price |
| `CK_SHARE_OFFERING_available` | SHARE_OFFERING | 0 ≤ shares_available ≤ total_shares |
| `CK_SHARE_EXIT_value` | SHARE_EXIT | total_sale_value > 0 |
| `CK_MGMT_CONTRACT_financing` | MANAGEMENT_CONTRACT | 0 ≤ financing_percent ≤ 0.5 |
| `CK_LEASE_dates` | LEASE | end_date > start_date |
| `CK_ESCROW_parent` | ESCROW_ACCOUNT | deal_id IS NOT NULL OR mortgage_id IS NOT NULL |
| `CK_ESCROW_released` | ESCROW_ACCOUNT | status = 'released' requires release_date |

### Unique Constraints

| Constraint | Table | Column(s) |
|-----------|-------|-----------|
| `UQ_USER_email` | USER | email |
| `UQ_USER_phone` | USER | phone |
| `UQ_USER_national_id` | USER | national_id |
| `UQ_BROKER_user_id` | BROKER | user_id |
| `UQ_BROKER_license_number` | BROKER | license_number |
| `UQ_TENANT_user` | TENANT | user_id |
| `UQ_SHARE_OFFERING_property` | SHARE_OFFERING | property_id |
| `UQ_SHARE_EXIT_investment` | SHARE_EXIT | investment_id |

### Filtered Unique Indexes

| Index | Table | Rule |
|-------|-------|------|
| `UX_PROPERTY_MEDIA_primary` | PROPERTY_MEDIA | Only one `is_primary = 1` per property |
| `UX_MGMT_CONTRACT_active_property` | MANAGEMENT_CONTRACT | Only one `active` contract per property |
| `UX_LEASE_active_property` | LEASE | Only one `active` lease per property |

---

## 🚀 Indexes & Performance

### Non-Clustered Indexes

```sql
-- USER
CREATE INDEX IX_USER_user_type ON nawy.[USER](user_type);

-- BROKER
CREATE INDEX IX_BROKER_status ON nawy.BROKER(status);

-- PROPERTY
CREATE INDEX IX_PROPERTY_city_district ON nawy.PROPERTY(city, district);
CREATE INDEX IX_PROPERTY_type_status ON nawy.PROPERTY(property_type, status);
CREATE INDEX IX_PROPERTY_price ON nawy.PROPERTY(price);
CREATE INDEX IX_PROPERTY_developer ON nawy.PROPERTY(developer_id) WHERE developer_id IS NOT NULL;
CREATE INDEX IX_PROPERTY_owner ON nawy.PROPERTY(owner_user_id) WHERE owner_user_id IS NOT NULL;
CREATE INDEX IX_PROPERTY_broker ON nawy.PROPERTY(listing_broker_id) WHERE listing_broker_id IS NOT NULL;

-- LEAD
CREATE INDEX IX_LEAD_broker_status ON nawy.LEAD(broker_id, status);
CREATE INDEX IX_LEAD_property ON nawy.LEAD(property_id);
CREATE INDEX IX_LEAD_buyer ON nawy.LEAD(buyer_user_id);

-- DEAL
CREATE INDEX IX_DEAL_property ON nawy.DEAL(property_id);
CREATE INDEX IX_DEAL_broker ON nawy.DEAL(broker_id) WHERE broker_id IS NOT NULL;
CREATE INDEX IX_DEAL_status ON nawy.DEAL(status);

-- COMMISSION
CREATE INDEX IX_COMMISSION_broker_status ON nawy.COMMISSION(broker_id, status);

-- MORTGAGE
CREATE INDEX IX_MORTGAGE_user ON nawy.MORTGAGE_APPLICATION(user_id);
CREATE INDEX IX_MORTGAGE_property ON nawy.MORTGAGE_APPLICATION(property_id);
CREATE INDEX IX_MORTGAGE_status ON nawy.MORTGAGE_APPLICATION(status);
CREATE INDEX IX_MORTGAGE_PAYMENT_status_due ON nawy.MORTGAGE_PAYMENT(status, due_date);

-- SHARES
CREATE INDEX IX_SHARE_OFFERING_status ON nawy.SHARE_OFFERING(status);
CREATE INDEX IX_SHARE_INVESTMENT_user ON nawy.SHARE_INVESTMENT(user_id);
CREATE INDEX IX_SHARE_INVESTMENT_offering ON nawy.SHARE_INVESTMENT(offering_id);

-- MGMT / LEASE
CREATE INDEX IX_MGMT_owner ON nawy.MANAGEMENT_CONTRACT(owner_user_id);
CREATE INDEX IX_LEASE_tenant ON nawy.LEASE(tenant_id);
CREATE INDEX IX_LEASE_status ON nawy.LEASE(status);
CREATE INDEX IX_RENT_PAYMENT_status_due ON nawy.RENT_PAYMENT(status, due_date);

-- ESCROW
CREATE INDEX IX_ESCROW_status ON nawy.ESCROW_ACCOUNT(status);
CREATE INDEX IX_ESCROW_property ON nawy.ESCROW_ACCOUNT(property_id);
```

---

## 📈 Analytical Views

23 views organized into 8 domains:

### User Analytics

| View | Purpose |
|------|---------|
| `vw_UserProfile` | Enriched user dimension with broker/tenant attributes |
| `vw_UserCrossSell` | Cross-business engagement flags |
| `vw_UserLifetimeValue` | Total revenue per user across all business lines |

### Property Analytics

| View | Purpose |
|------|---------|
| `vw_PropertyFull` | Denormalized property master with developer/broker/owner |
| `vw_PropertyPricing` | Aggregated pricing statistics by location/type |
| `vw_PropertyRevenue` | Total revenue per property across all services |

### Sales Pipeline

| View | Purpose |
|------|---------|
| `vw_SalesFunnel` | Lead-to-deal conversion tracking |
| `vw_BrokerPerformance` | Broker KPIs: leads, deals, commissions |
| `vw_DealSummary` | Closed deals with full context and price delta |

### Nawy Now

| View | Purpose |
|------|---------|
| `vw_MortgagePortfolio` | Complete mortgage portfolio view |
| `vw_MortgagePaymentStatus` | Installment tracking with late payment flags |
| `vw_MortgageRisk` | Borrower risk scoring with category |

### Nawy Shares

| View | Purpose |
|------|---------|
| `vw_SharesOfferingPerformance` | Offering KPIs: sold %, investors, raised |
| `vw_SharesInvestorROI` | ROI per investor per investment |
| `vw_SharesPipeline` | Current state of all offerings |

### Nawy Unlocked

| View | Purpose |
|------|---------|
| `vw_OccupancyRates` | Occupancy status per managed property |
| `vw_RentalIncome` | Rental revenue per property with fee breakdown |
| `vw_ManagementPerformance` | Service line P&L by city and service type |

### Compliance

| View | Purpose |
|------|---------|
| `vw_EscrowCompliance` | Escrow usage and release tracking |
| `vw_EscrowHoldTime` | Average holding period analysis |

### Executive

| View | Purpose |
|------|---------|
| `vw_MarketOverview` | Market KPIs by city and property type |
| `vw_ExecutiveDashboard` | Single-screen top-level KPIs |
| `vw_RevenueByBusinessLine` | Revenue split across all 5 business lines |


