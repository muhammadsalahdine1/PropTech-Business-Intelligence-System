# Nawy Proptech Platform — Dimensional Model Documentation

> **Complete reference for the Kimball star schema powering Nawy's analytics**



## 📖 Table of Contents

- [Introduction](#-introduction)
- [Modeling Approach](#-modeling-approach)
- [The Bus Matrix](#-the-bus-matrix)
- [Dimension Design Standards](#-dimension-design-standards)
- [Fact Table Design Standards](#-fact-table-design-standards)
- [Conformed Dimensions in Detail](#-conformed-dimensions-in-detail)
- [Fact Tables in Detail](#-fact-tables-in-detail)
- [Grain Declaration Reference](#-grain-declaration-reference)
- [Additive, Semi-Additive, Non-Additive Measures](#-additive-semi-additive-non-additive-measures)
- [Slowly Changing Dimensions](#-slowly-changing-dimensions)
- [Special Members and Null Handling](#-special-members-and-null-handling)
- [Degenerate Dimensions](#-degenerate-dimensions)
- [Junk Dimensions](#-junk-dimensions)
- [Role-Playing Dimensions](#-role-playing-dimensions)
- [Snowflaking Decisions](#-snowflaking-decisions)
- [Aggregate Design](#-aggregate-design)
- [Modeling Anti-Patterns Avoided](#-modeling-anti-patterns-avoided)
- [Query Examples](#-query-examples)






## 🎯 Introduction

### What Is This Document?

This is the **authoritative dimensional modeling reference** for the Nawy Proptech data warehouse. It documents:

- Every dimension table (structure, grain, attributes)
- Every fact table (grain, measures, dimensions)
- The relationships between them (the bus matrix)
- Design decisions and why they were made
- Standards for extending the model

### Who Should Read This?

| Role | What You'll Get |
|------|-----------------|
| **Data Analysts** | How to join tables correctly, which grain to use |
| **BI Developers** | Dimension hierarchies, measure semantics |
| **Data Engineers** | ETL design, SCD strategy, late-arriving handling |
| **Data Architects** | Design rationale, extension guidelines |
| **Business Stakeholders** | What questions the model can answer |

### Where This Fits

This document assumes the warehouse follows the **three-layer Medallion architecture**:

- **Bronze** — Raw ingestion (append-only)
- **Silver** — Cleansed, deduplicated, historized
- **Gold** — Dimensional model (this document)

The Gold layer contains **8 dimensions** and **15 fact tables**, all sharing **conformed dimensions**.

## 🏗️ Modeling Approach

### Why Kimball Dimensional?

We chose **Kimball dimensional modeling** over alternatives for five reasons:

| Reason | Benefit |
|--------|---------|
| **Business-first** | Model around processes, not sources |
| **Query performance** | Star joins are fast; no deep nesting |
| **BI tool friendly** | Tableau/Power BI work natively |
| **Extensible** | Adding a fact doesn't break existing reports |
| **Conformed** | Same dimensions shared across business lines |

### Comparison to Alternatives

| Approach | Pros | Cons | Why We Didn't Choose |
|----------|------|------|----------------------|
| **3NF (Inmon)** | Flexible, normalized | Complex queries | Too slow for BI |
| **Data Vault 2.0** | Audit, scalability | Complex, requires tooling | Overkill for mid-size DW |
| **Kimball Star** | Fast, simple, BI-friendly | Some redundancy | ✅ Our choice |
| **Wide tables** | Simple | Rigid, hard to extend | Breaks at scale |

### Hybrid Application

We applied a **hybrid approach**:

- **Kimball** for the Gold layer (dimensional)
- **Medallion** for layered processing (Bronze → Silver → Gold)
- **SCD Type 2** for historical tracking
- **Columnstore + Partitioning** for physical performance

---

## 🔲 The Bus Matrix

The **bus matrix** is the master plan. It documents which dimensions apply to which fact tables.

| Fact Table | DimDate | DimUser | DimProperty | DimBroker | DimDeveloper | DimGeography | DimProduct | DimStatus |
|------------|:-------:|:-------:|:-----------:|:---------:|:------------:|:------------:|:----------:|:---------:|
| **FactPropertyListing** | ✅✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **FactLead** | ✅✅ | ✅ | ✅ | ✅ | — | ✅ | ✅ | ✅ |
| **FactDeal** | ✅✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **FactCommission** | ✅ | ✅ | ✅ | ✅ | — | — | ✅ | ✅ |
| **FactMortgageApplication** | ✅✅ | ✅ | ✅ | — | — | ✅ | ✅ | ✅ |
| **FactMortgagePayment** | ✅✅ | ✅ | ✅ | — | — | — | — | ✅ |
| **FactShareOffering** | ✅ | — | ✅ | — | ✅ | ✅ | ✅ | ✅ |
| **FactShareInvestment** | ✅ | ✅ | ✅ | — | ✅ | ✅ | ✅ | ✅ |
| **FactShareExit** | ✅ | ✅ | ✅ | — | ✅ | ✅ | — | ✅ |
| **FactManagementContract** | ✅ | ✅ | ✅ | — | — | ✅ | ✅ | ✅ |
| **FactLease** | ✅✅ | ✅✅ | ✅ | — | — | ✅ | — | ✅ |
| **FactRentPayment** | ✅✅ | ✅✅ | ✅ | — | — | — | — | ✅ |
| **FactEscrow** | ✅ | ✅ | ✅ | — | — | ✅ | ✅ | ✅ |
| **FactUserActivity** | ✅ | ✅ | — | — | — | — | ✅ | — |
| **FactRevenue** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |

**Legend**:
- ✅ = Dimension applies
- ✅✅ = Multiple roles (role-playing dimension)
- — = Not applicable

**Reading the matrix**:
- **Columns** = Conformed dimensions (the "conformed" part means shared across facts)
- **Rows** = Business processes (fact tables)
- **Intersections** = Dimension-fact relationships

### Why the Bus Matrix Matters

1. **Consistency** — Same metrics computed the same way across reports
2. **Reusability** — Build a dimension once, use everywhere
3. **Scalability** — Add a fact without redesigning dimensions
4. **Extensibility** — New business lines fit the same framework

---

## 📐 Dimension Design Standards

### Every Dimension Must Have

| Attribute Type | Purpose | Example |
|----------------|---------|---------|
| **Surrogate Key** | DW-internal PK, never reused | `user_key BIGINT IDENTITY` |
| **Natural Key** | Source system identifier | `user_id BIGINT` |
| **Business Key** | Human-meaningful identifier | `email NVARCHAR(255)` |
| **Descriptive Attributes** | Dimensions for filtering/grouping | `full_name`, `city` |
| **Hierarchy Attributes** | Drill-down support | `city → district → compound` |
| **SCD Columns** (Type 2 only) | Historical tracking | `valid_from`, `valid_to`, `is_current` |
| **Audit Columns** | Data lineage | `created_at`, `updated_at`, `source_system` |

### Dimension Design Rules

| Rule | Rationale |
|------|-----------|
| **Surrogate keys are integers, not natural keys** | Faster joins, decoupled from source |
| **Surrogate keys are never reused** | Prevents historical confusion |
| **Dimensions are wide, not tall** | Denormalized for query performance |
| **Attributes are textual or numeric** | No computation at dimension level |
| **NULLs avoided** | Use "-1 Unknown" or "-2 N/A" members |
| **Fixed column order** | Keys first, then attributes alphabetically |
| **Documented with extended properties** | Self-describing schema |

### Dimension Naming

| Pattern | Example |
|---------|---------|
| `Dim<EntityName>` | `DimUser`, `DimProperty` |
| Surrogate key: `<entity>_key` | `user_key`, `property_key` |
| Natural key: `<entity>_id` | `user_id`, `property_id` |
| SCD columns: `valid_from`, `valid_to`, `is_current` | standard |
| Audit columns: `_created_at`, `_updated_at`, `_source` | prefixed with underscore |

---

## 📊 Fact Table Design Standards

### Fact Table Types

We use **three fact table types** depending on the business process:

| Type | When Used | Example | Characteristics |
|------|-----------|---------|-----------------|
| **Transaction** | Event occurs at point in time | `FactDeal` | One row per event, immutable |
| **Periodic Snapshot** | State measured at intervals | `FactPropertyListing` | One row per entity per period |
| **Accumulating Snapshot** | Process with defined start/end | `FactMortgageApplication` | One row per entity, updated as stages complete |

### Every Fact Table Must Have

| Attribute Type | Purpose | Example |
|----------------|---------|---------|
| **Surrogate Key** | PK of the fact table | `deal_key BIGINT IDENTITY` |
| **Foreign Keys** | Links to dimensions | `date_key`, `user_key`, `property_key` |
| **Degenerate Dimensions** | Business identifiers without a dim table | `deal_number VARCHAR(50)` |
| **Additive Measures** | Can be summed across all dimensions | `gmv_egp`, `commission_egp` |
| **Semi-Additive Measures** | Can be summed across some dimensions | `balance_egp` (not across time) |
| **Non-Additive Measures** | Cannot be summed | `discount_pct`, `roi_pct` |
| **Audit Columns** | Data lineage | `_created_at`, `_source_batch_id` |

### Fact Table Design Rules

| Rule | Rationale |
|------|-----------|
| **Every FK is NOT NULL** | Use "-1 Unknown" if needed |
| **Facts are numeric and additive where possible** | Enables `SUM()` across any dimension |
| **Facts are transactional or snapshot — never mixed** | Grain clarity |
| **Degenerate dimensions included for drill-through** | Traceability back to source |
| **No descriptive text in fact tables** | Text belongs in dimensions |
| **Fact tables have clustered columnstore** | Fast scans at scale |

---

## 📋 Conformed Dimensions in Detail

### DIM 1 — `DimDate`

**Purpose**: Universal time dimension used by every fact table.

**Grain**: One row per calendar day.

**Range**: 2020-01-01 to 2030-12-31 (11 years).

**Type**: Static (Type 0 — never changes).

**Key Structure**:
- `date_key INT` — smart key in YYYYMMDD format (e.g., 20260930)
- `date DATE` — full date

**Attributes**:

| Column | Type | Description |
|--------|------|-------------|
| `date_key` | INT | PK, YYYYMMDD smart key |
| `date` | DATE | Full calendar date |
| `day_of_week` | INT | 1=Sunday ... 7=Saturday |
| `day_name` | NVARCHAR(20) | Sunday, Monday, ... |
| `day_of_month` | INT | 1–31 |
| `day_of_year` | INT | 1–366 |
| `week_of_year` | INT | 1–53 |
| `month` | INT | 1–12 |
| `month_name` | NVARCHAR(20) | January, February, ... |
| `month_short` | NVARCHAR(3) | Jan, Feb, ... |
| `quarter` | INT | 1–4 |
| `quarter_name` | NVARCHAR(10) | Q1, Q2, Q3, Q4 |
| `year` | INT | 2020–2030 |
| `year_month` | NVARCHAR(7) | "2026-09" |
| `year_quarter` | NVARCHAR(7) | "2026-Q3" |
| `is_weekend` | BIT | 1 if Friday or Saturday |
| `is_holiday` | BIT | 1 if Egyptian public holiday |
| `holiday_name` | NVARCHAR(50) | Holiday name |
| `is_ramadan` | BIT | Islamic calendar flag |
| `is_business_day` | BIT | Working day |
| `fiscal_year` | INT | Fiscal calendar year |
| `fiscal_quarter` | INT | Fiscal quarter |
| `is_current_year` | BIT | Convenience flag |

**Special Members**:
- `date_key = -1` — "Unknown Date"
- `date_key = 0` — "Not Applicable" (for dimension-only use)

**Why YYYYMMDD smart key?**
- Sortable, filterable without joins
- Human-readable in queries
- Enables range queries: `WHERE date_key BETWEEN 20260101 AND 20260930`

---

### DIM 2 — `DimUser` (SCD Type 2)

**Purpose**: Unified user dimension tracking all platform participants.

**Grain**: One row per user per version.

**Type**: Slowly Changing Dimension — **Type 2**.

**Source**: `nawy.USER` + `nawy.BROKER` + `nawy.TENANT`

**Key Structure**:
- `user_key BIGINT IDENTITY` — surrogate key
- `user_id BIGINT` — natural key from OLTP

**Attributes**:

| Column | Type | SCD | Description |
|--------|------|:---:|-------------|
| `user_key` | BIGINT | — | PK, surrogate key |
| `user_id` | BIGINT | — | Natural key from OLTP |
| `email` | NVARCHAR(255) | ✅ | Current email (PII) |
| `full_name` | NVARCHAR(255) | ✅ | Current full name |
| `phone` | NVARCHAR(20) | ✅ | Current phone (PII) |
| `user_type` | NVARCHAR(50) | ✅ | buyer/seller/investor/broker/admin |
| `national_id_masked` | NVARCHAR(20) | ✅ | Masked NID |
| `is_verified` | BIT | ✅ | Verification flag |
| `registration_date` | DATE | — | Date registered |
| `registration_year` | INT | — | Year for cohort analysis |
| `registration_month` | NVARCHAR(7) | — | For monthly cohort |
| `country` | NVARCHAR(50) | — | Country (default: Egypt) |
| `city` | NVARCHAR(100) | ✅ | Current city |
| `district` | NVARCHAR(100) | ✅ | Current district |
| `acquisition_channel` | NVARCHAR(50) | — | website/app/referral |
| `lifetime_days` | INT | ✅ | Days since registration |
| `business_lines_engaged` | INT | ✅ | Count of business lines |
| `is_broker` | BIT | ✅ | Has broker profile |
| `is_tenant` | BIT | ✅ | Has tenant profile |
| `is_vip` | BIT | ✅ | Derived from CLV |
| `clv_tier` | NVARCHAR(20) | ✅ | VIP/High/Standard/Low |
| `valid_from` | DATETIMEOFFSET | — | SCD Type 2 |
| `valid_to` | DATETIMEOFFSET | — | SCD Type 2 |
| `is_current` | BIT | — | SCD Type 2 flag |

**Tracked Attributes** (SCD Type 2 triggers):
- `email`, `full_name`, `phone`, `user_type`, `city`, `is_verified`, `is_vip`

**Non-Tracked Attributes** (Type 1 — overwrite):
- `national_id_masked`, `business_lines_engaged`, `clv_tier`

**Hierarchies**:
```
City → District → User
```

**Special Members**:
- `user_key = -1` — "Unknown User"
- `user_key = -2` — "Inferred User" (late-arriving)

---

### DIM 3 — `DimProperty` (SCD Type 2)

**Purpose**: Property dimension with full listing history.

**Grain**: One row per property per version.

**Type**: Slowly Changing Dimension — **Type 2**.

**Source**: `nawy.PROPERTY` + `nawy.DEVELOPER`

**Attributes**:

| Column | Type | SCD | Description |
|--------|------|:---:|-------------|
| `property_key` | BIGINT | — | PK |
| `property_id` | BIGINT | — | Natural key |
| `title` | NVARCHAR(500) | ✅ | Listing title |
| `property_type` | NVARCHAR(50) | ✅ | apartment/villa/chalet |
| `listing_type` | NVARCHAR(20) | ✅ | primary/resale/rental |
| `bedrooms` | INT | ✅ | Room count |
| `bathrooms` | INT | ✅ | Bathroom count |
| `area_sqm` | DECIMAL(10,2) | ✅ | Area |
| `finishing_status` | NVARCHAR(50) | ✅ | shell/finished |
| `furnished_status` | NVARCHAR(50) | ✅ | unfurnished/furnished |
| `current_price_egp` | DECIMAL(15,2) | ✅ | Current price |
| `current_status` | NVARCHAR(20) | ✅ | active/sold/rented |
| `latitude` | DECIMAL(10,8) | — | Location |
| `longitude` | DECIMAL(11,8) | — | Location |
| `developer_id` | BIGINT | ✅ | FK |
| `developer_name` | NVARCHAR(255) | ✅ | Denormalized |
| `compound_name` | NVARCHAR(255) | ✅ | Compound |
| `city` | NVARCHAR(100) | ✅ | City |
| `district` | NVARCHAR(100) | ✅ | District |
| `geography_key` | BIGINT | — | FK to DimGeography |
| `listing_date` | DATE | — | First listed |
| `days_on_market` | INT | ✅ | Days since listing |
| `delivery_date` | DATE | ✅ | Expected delivery |
| `valid_from` | DATETIMEOFFSET | — | SCD Type 2 |
| `valid_to` | DATETIMEOFFSET | — | SCD Type 2 |
| `is_current` | BIT | — | SCD flag |

**Tracked Attributes** (SCD Type 2 triggers):
- `current_price_egp`, `current_status`, `finishing_status`, `furnished_status`

**Hierarchies**:
```
Geography: Country → City → District → Compound
Type: Category → Property Type → Bedrooms
```

---

### DIM 4 — `DimBroker` (SCD Type 2)

**Purpose**: Broker dimension for Nawy Partners.

**Grain**: One row per broker per version.

**Type**: SCD Type 2.

**Source**: `nawy.BROKER` + `nawy.USER`

**Attributes**:

| Column | Type | SCD | Description |
|--------|------|:---:|-------------|
| `broker_key` | BIGINT | — | PK |
| `broker_id` | BIGINT | — | Natural key |
| `broker_name` | NVARCHAR(255) | ✅ | Full name |
| `email` | NVARCHAR(255) | ✅ | Contact (PII) |
| `broker_type` | NVARCHAR(50) | ✅ | freelancer/agency |
| `agency_name` | NVARCHAR(255) | ✅ | Agency |
| `license_number` | NVARCHAR(100) | ✅ | License |
| `commission_rate` | DECIMAL(5,4) | ✅ | Rate |
| `team_size` | INT | ✅ | Sub-agents |
| `status` | NVARCHAR(20) | ✅ | active/suspended |
| `joined_date` | DATE | — | Join date |
| `tenure_days` | INT | ✅ | Days on platform |
| `performance_tier` | NVARCHAR(20) | ✅ | Platinum/Gold/Silver/Bronze |
| `valid_from` | DATETIMEOFFSET | — | SCD |
| `valid_to` | DATETIMEOFFSET | — | SCD |
| `is_current` | BIT | — | SCD |

**Tracked Attributes**:
- `broker_type`, `commission_rate`, `team_size`, `status`, `performance_tier`

---

### DIM 5 — `DimDeveloper`

**Purpose**: Real estate developer dimension.

**Grain**: One row per developer.

**Type**: SCD Type 1 (overwrite).

**Source**: `nawy.DEVELOPER`

**Attributes**:

| Column | Type | Description |
|--------|------|-------------|
| `developer_key` | BIGINT | PK |
| `developer_id` | BIGINT | Natural key |
| `name` | NVARCHAR(255) | Company name |
| `partnership_tier` | NVARCHAR(20) | standard/premium/exclusive |
| `contact_email` | NVARCHAR(255) | B2B contact |
| `contact_phone` | NVARCHAR(20) | B2B phone |
| `total_projects` | INT | Project count |
| `joined_date` | DATE | First partnership |
| `is_active` | BIT | Active flag |

**Why Type 1?**
Developer attributes rarely change and are not critical for historical analysis. Overwriting is acceptable.

---

### DIM 6 — `DimGeography`

**Purpose**: Conformed geographic hierarchy.

**Grain**: One row per unique location (city/district/compound).

**Type**: SCD Type 1.

**Source**: Derived from `nawy.PROPERTY` distinct locations.

**Attributes**:

| Column | Type | Description |
|--------|------|-------------|
| `geography_key` | BIGINT | PK |
| `country` | NVARCHAR(50) | Egypt |
| `city` | NVARCHAR(100) | Cairo, Giza, Alexandria |
| `district` | NVARCHAR(100) | New Cairo, Sheikh Zayed |
| `compound` | NVARCHAR(255) | Villette, Marassi, Badya |
| `region` | NVARCHAR(50) | Greater Cairo, North Coast |
| `latitude` | DECIMAL(10,8) | Centroid |
| `longitude` | DECIMAL(11,8) | Centroid |
| `is_coastal` | BIT | Coastal flag |
| `is_new_development` | BIT | New development flag |
| `avg_price_per_sqm_egp` | DECIMAL(15,2) | Static cache |

**Hierarchy**:
```
Country → Region → City → District → Compound
```

**Why Denormalized?**
Adding rows (new locations) is cheap; query performance is more valuable than avoiding a few redundant strings.

---

### DIM 7 — `DimProduct`

**Purpose**: Product/service dimension across all business lines.

**Grain**: One row per product/service.

**Type**: SCD Type 0 (static).

**Attributes**:

| Column | Type | Description |
|--------|------|-------------|
| `product_key` | BIGINT | PK |
| `product_code` | NVARCHAR(50) | Unique code |
| `product_name` | NVARCHAR(255) | Display name |
| `business_line` | NVARCHAR(50) | Properties/Partners/Now/Shares/Unlocked |
| `service_type` | NVARCHAR(50) | Category |
| `revenue_model` | NVARCHAR(50) | commission/interest/fee/subscription |
| `is_recurring` | BIT | Recurring revenue flag |

**Product Members**:

| Code | Name | Business Line |
|------|------|---------------|
| PROP_LIST | Property Listing | Properties |
| LEAD_CAPTURE | Lead Capture | Properties |
| BROKER_COMM | Broker Commission | Partners |
| MORTGAGE | Mortgage Loan | Now |
| SHARE_OFF | Fractional Offering | Shares |
| SHARE_INV | Fractional Investment | Shares |
| MGMT_FULL | Full Management | Unlocked |
| MGMT_RENT | Rental Only | Unlocked |
| FINISHING | Finishing Service | Unlocked |

---

### DIM 8 — `DimStatus`

**Purpose**: Status dimension for all workflow states.

**Grain**: One row per (entity_type, status_code).

**Type**: SCD Type 0 (static).

**Attributes**:

| Column | Type | Description |
|--------|------|-------------|
| `status_key` | BIGINT | PK |
| `entity_type` | NVARCHAR(50) | lead/deal/mortgage/lease |
| `status_code` | NVARCHAR(50) | Raw status value |
| `status_name` | NVARCHAR(100) | Display name |
| `is_terminal` | BIT | Final state |
| `is_won` | BIT | Positive outcome |
| `is_lost` | BIT | Negative outcome |
| `sort_order` | INT | Funnel ordering |

**Example Members**:

| entity_type | status_code | status_name | is_terminal | is_won |
|-------------|-------------|-------------|:-----------:|:------:|
| lead | new | New | 0 | 0 |
| lead | contacted | Contacted | 0 | 0 |
| lead | viewing | Viewing | 0 | 0 |
| lead | negotiation | Negotiation | 0 | 0 |
| lead | closed_won | Closed Won | 1 | 1 |
| lead | closed_lost | Closed Lost | 1 | 0 |

**Why a separate dimension?**
Enables consistent status reporting across all facts without repeating CASE logic.

---

## 📊 Fact Tables in Detail

### FACT 1 — `FactPropertyListing`

**Business Process**: A property is listed on the platform.

**Type**: **Periodic Snapshot**

**Grain**: One row per property per day.

**Source**: `nawy.PROPERTY`

**Dimensions**: `DimDate`, `DimProperty`, `DimUser (owner)`, `DimBroker`, `DimDeveloper`, `DimGeography`, `DimProduct`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `listing_price_egp` | DECIMAL(15,2) | Additive | Listed price |
| `price_per_sqm_egp` | DECIMAL(15,2) | Non-additive | Computed ratio |
| `bedrooms` | INT | Additive | Bedroom count |
| `area_sqm` | DECIMAL(10,2) | Additive | Area |
| `days_on_market` | INT | Additive | Days since listing |
| `lead_count` | INT | Additive | Leads generated |
| `view_count` | INT | Additive | Views (from activity log) |
| `is_active_flag` | BIT | Additive | Active flag |
| `is_sold_flag` | BIT | Additive | Sold flag |

**Degenerate Dimensions**: `property_id`, `listing_reference_number`

**Why Periodic Snapshot?**
- Captures the state of listings daily
- Enables time-series analysis of inventory
- Supports "how many active listings existed on date X" queries

---

### FACT 2 — `FactLead`

**Business Process**: A prospective buyer expresses interest.

**Type**: **Transaction**

**Grain**: One row per lead.

**Source**: `nawy.LEAD`

**Dimensions**: `DimDate (created, last_activity)`, `DimUser (buyer)`, `DimProperty`, `DimBroker`, `DimGeography`, `DimProduct (source)`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `days_in_pipeline` | INT | Additive | Days open |
| `conversion_days` | INT | Additive | Days to close |
| `lead_count` | INT | Additive | Always 1 |
| `is_won_flag` | BIT | Additive | Won flag |
| `is_lost_flag` | BIT | Additive | Lost flag |
| `is_open_flag` | BIT | Additive | Open flag |

**Degenerate Dimensions**: `lead_id`, `source`

**Role-Playing Dimensions**:
- `DimDate` plays two roles: `created_date_key` and `last_activity_date_key`

---

### FACT 3 — `FactDeal`

**Business Process**: A property transaction is completed.

**Type**: **Transaction**

**Grain**: One row per completed deal.

**Source**: `nawy.DEAL`

**Dimensions**: `DimDate (closed)`, `DimUser (buyer)`, `DimProperty`, `DimBroker`, `DimDeveloper`, `DimGeography`, `DimProduct (payment type)`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `sale_price_egp` | DECIMAL(18,2) | Additive | Final sale price |
| `list_price_egp` | DECIMAL(18,2) | Additive | Original list price |
| `discount_egp` | DECIMAL(18,2) | Additive | Discount amount |
| `discount_pct` | DECIMAL(5,2) | Non-additive | Discount % |
| `gmv_egp` | DECIMAL(18,2) | Additive | GMV |
| `commission_egp` | DECIMAL(18,2) | Additive | Commission |
| `days_to_close` | INT | Additive | Days from lead |
| `deal_count` | INT | Additive | Always 1 |

**Degenerate Dimensions**: `deal_id`, `payment_type_code`

---

### FACT 4 — `FactCommission`

**Business Process**: A broker earns a commission.

**Type**: **Transaction**

**Grain**: One row per commission payment.

**Source**: `nawy.COMMISSION`

**Dimensions**: `DimDate (paid)`, `DimBroker`, `DimProperty`, `DimProduct`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `commission_amount_egp` | DECIMAL(18,2) | Additive | Amount |
| `commission_rate` | DECIMAL(5,4) | Non-additive | Rate |
| `days_to_payment` | INT | Additive | Days from deal |
| `is_paid_flag` | BIT | Additive | Paid flag |

**Degenerate Dimensions**: `commission_id`, `deal_id`

---

### FACT 5 — `FactMortgageApplication`

**Business Process**: A user applies for a Nawy Now mortgage.

**Type**: **Accumulating Snapshot**

**Grain**: One row per mortgage application.

**Source**: `nawy.MORTGAGE_APPLICATION`

**Dimensions**: `DimDate (submitted, approved)`, `DimUser`, `DimProperty`, `DimGeography`, `DimProduct`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `property_price_egp` | DECIMAL(18,2) | Additive | Property price |
| `down_payment_egp` | DECIMAL(18,2) | Additive | Down payment |
| `loan_amount_egp` | DECIMAL(18,2) | Additive | Loan amount |
| `monthly_payment_egp` | DECIMAL(18,2) | Additive | Monthly installment |
| `installment_months` | INT | Additive | Term |
| `interest_rate` | DECIMAL(5,4) | Non-additive | Annual rate |
| `days_to_approval` | INT | Additive | Submission → approval |
| `is_approved_flag` | BIT | Additive | Approved |
| `is_disbursed_flag` | BIT | Additive | Disbursed |

**Why Accumulating Snapshot?**
- Application flows through stages (submitted → under_review → approved → disbursed)
- Row is **updated** as stages complete
- Enables process duration analysis

**Role-Playing Dimensions**:
- `DimDate`: `submitted_date_key` and `approved_date_key`

---

### FACT 6 — `FactMortgagePayment`

**Business Process**: A mortgage installment is due or paid.

**Type**: **Transaction**

**Grain**: One row per installment.

**Source**: `nawy.MORTGAGE_PAYMENT`

**Dimensions**: `DimDate (due, paid)`, `DimUser`, `DimProperty`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `amount_due_egp` | DECIMAL(18,2) | Additive | Amount due |
| `amount_paid_egp` | DECIMAL(18,2) | Additive | Amount paid |
| `amount_outstanding_egp` | DECIMAL(18,2) | Additive | Outstanding |
| `days_late` | INT | Additive | Days late |
| `is_paid_flag` | BIT | Additive | Paid |
| `is_overdue_flag` | BIT | Additive | Overdue |

**Role-Playing Dimensions**:
- `DimDate`: `due_date_key` and `paid_date_key`

---

### FACT 7 — `FactShareOffering`

**Business Process**: A property is offered for fractional investment.

**Type**: **Periodic Snapshot**

**Grain**: One row per offering per day.

**Source**: `nawy.SHARE_OFFERING`

**Dimensions**: `DimDate`, `DimProperty`, `DimDeveloper`, `DimGeography`, `DimProduct`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `total_value_egp` | DECIMAL(18,2) | Additive | Offering value |
| `share_price_egp` | DECIMAL(18,2) | Non-additive | Price per share |
| `total_shares` | INT | Additive | Total shares |
| `shares_sold` | INT | Additive | Sold shares |
| `shares_available` | INT | Additive | Available |
| `subscribed_egp` | DECIMAL(18,2) | Additive | Subscribed value |
| `sold_pct` | DECIMAL(5,2) | Non-additive | % sold |

---

### FACT 8 — `FactShareInvestment`

**Business Process**: A user invests in a fractional offering.

**Type**: **Transaction**

**Grain**: One row per investment.

**Source**: `nawy.SHARE_INVESTMENT`

**Dimensions**: `DimDate (investment date)`, `DimUser (investor)`, `DimProperty`, `DimDeveloper`, `DimGeography`, `DimProduct`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `shares_purchased` | INT | Additive | Shares bought |
| `total_amount_egp` | DECIMAL(18,2) | Additive | Amount |
| `price_per_share_egp` | DECIMAL(18,2) | Non-additive | Price |
| `investment_count` | INT | Additive | Always 1 |
| `is_active_flag` | BIT | Additive | Active |

---

### FACT 9 — `FactShareExit`

**Business Process**: A fractional investor exits.

**Type**: **Transaction**

**Grain**: One row per exit.

**Source**: `nawy.SHARE_EXIT`

**Dimensions**: `DimDate (exit date)`, `DimUser (investor)`, `DimProperty`, `DimDeveloper`, `DimGeography`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `exit_price_per_share_egp` | DECIMAL(18,2) | Non-additive | Exit price |
| `total_sale_value_egp` | DECIMAL(18,2) | Additive | Proceeds |
| `exit_fee_egp` | DECIMAL(18,2) | Additive | Platform fee |
| `profit_loss_egp` | DECIMAL(18,2) | Additive | Gain/loss |
| `roi_pct` | DECIMAL(10,2) | Non-additive | Return % |
| `holding_days` | INT | Additive | Days held |

---

### FACT 10 — `FactManagementContract`

**Business Process**: A property owner signs a management contract.

**Type**: **Periodic Snapshot**

**Grain**: One row per contract per day.

**Source**: `nawy.MANAGEMENT_CONTRACT`

**Dimensions**: `DimDate`, `DimUser (owner)`, `DimProperty`, `DimGeography`, `DimProduct (service type)`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `management_fee_pct` | DECIMAL(5,4) | Non-additive | Fee % |
| `financing_pct` | DECIMAL(5,4) | Non-additive | Financed % |
| `contract_days` | INT | Additive | Days active |
| `is_active_flag` | BIT | Additive | Active |
| `contract_count` | INT | Additive | Always 1 |

---

### FACT 11 — `FactLease`

**Business Process**: A tenant signs a lease.

**Type**: **Accumulating Snapshot**

**Grain**: One row per lease.

**Source**: `nawy.LEASE`

**Dimensions**: `DimDate (start, end)`, `DimUser (tenant)`, `DimUser (owner)`, `DimProperty`, `DimGeography`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `monthly_rent_egp` | DECIMAL(18,2) | Additive | Monthly rent |
| `security_deposit_egp` | DECIMAL(18,2) | Additive | Deposit |
| `lease_days` | INT | Additive | Length |
| `is_active_flag` | BIT | Additive | Active |
| `is_expired_flag` | BIT | Additive | Expired |

**Role-Playing Dimensions**:
- `DimUser`: `tenant_key` and `owner_key`
- `DimDate`: `start_date_key` and `end_date_key`

---

### FACT 12 — `FactRentPayment`

**Business Process**: A rent installment is due or paid.

**Type**: **Transaction**

**Grain**: One row per installment.

**Source**: `nawy.RENT_PAYMENT`

**Dimensions**: `DimDate (due, paid)`, `DimUser (tenant)`, `DimUser (owner)`, `DimProperty`, `DimGeography`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `amount_egp` | DECIMAL(18,2) | Additive | Rent amount |
| `management_fee_egp` | DECIMAL(18,2) | Additive | Nawy fee |
| `net_to_owner_egp` | DECIMAL(18,2) | Additive | Owner payout |
| `days_late` | INT | Additive | Days late |
| `is_paid_flag` | BIT | Additive | Paid |
| `is_overdue_flag` | BIT | Additive | Overdue |

**Role-Playing Dimensions**:
- `DimUser`: `tenant_key` and `owner_key`
- `DimDate`: `due_date_key` and `paid_date_key`

---

### FACT 13 — `FactEscrow`

**Business Process**: Funds are held in escrow.

**Type**: **Periodic Snapshot**

**Grain**: One row per escrow per day.

**Source**: `nawy.ESCROW_ACCOUNT`

**Dimensions**: `DimDate`, `DimUser`, `DimProperty`, `DimProduct (source type)`, `DimStatus`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `deposit_amount_egp` | DECIMAL(18,2) | Additive | Funds held |
| `holding_days` | INT | Additive | Days held |
| `is_released_flag` | BIT | Additive | Released |
| `is_disputed_flag` | BIT | Additive | Disputed |
| `is_active_flag` | BIT | Additive | Active |

---

### FACT 14 — `FactUserActivity`

**Business Process**: A user performs an action.

**Type**: **Transaction**

**Grain**: One row per activity event.

**Source**: Application event log (extended OLTP)

**Dimensions**: `DimDate`, `DimUser`, `DimProduct (activity type)`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `event_count` | INT | Additive | Always 1 |
| `session_duration_sec` | INT | Additive | Time spent |
| `is_conversion_flag` | BIT | Additive | Converted |

**Why Transaction?**
Each activity is a discrete, immutable event. Perfect for transaction fact type.

---

### FACT 15 — `FactRevenue`

**Business Process**: Revenue is recognized.

**Type**: **Transaction**

**Grain**: One row per revenue recognition event.

**Source**: Derived from 5 sources (commission, mortgage interest, shares fee, management fee, finishing)

**Dimensions**: `DimDate`, `DimUser`, `DimProperty`, `DimBroker`, `DimDeveloper`, `DimGeography`, `DimProduct (revenue source)`

**Measures**:

| Column | Type | Additivity | Description |
|--------|------|:----------:|-------------|
| `revenue_amount_egp` | DECIMAL(18,2) | Additive | Revenue |
| `cost_amount_egp` | DECIMAL(18,2) | Additive | Cost |
| `margin_egp` | DECIMAL(18,2) | Additive | Margin |
| `revenue_count` | INT | Additive | Always 1 |
| `is_recurring_flag` | BIT | Additive | Recurring |

**Why This Fact Exists**:
- Consolidates all revenue across business lines
- Enables unified P&L reporting
- Supports executive dashboards (Query 10)
- Simplifies investor reporting

---

## 📏 Grain Declaration Reference

Every fact table has a **single, documented grain**. This prevents double-counting and ambiguous aggregations.

| Fact Table | Grain (One Row Represents...) |
|-----------|--------------------------------|
| FactPropertyListing | One property's state on one day |
| FactLead | One lead (prospect inquiry) |
| FactDeal | One completed property sale |
| FactCommission | One commission payment to a broker |
| FactMortgageApplication | One mortgage application |
| FactMortgagePayment | One mortgage installment |
| FactShareOffering | One offering's state on one day |
| FactShareInvestment | One investor's purchase in an offering |
| FactShareExit | One investor's exit from an investment |
| FactManagementContract | One contract's state on one day |
| FactLease | One lease agreement |
| FactRentPayment | One rent installment |
| FactEscrow | One escrow account's state on one day |
| FactUserActivity | One user action event |
| FactRevenue | One revenue recognition event |

**Rule**: If you can't state the grain in one sentence, the fact table is wrong.

---

## 🔢 Additive, Semi-Additive, Non-Additive Measures

### Definitions

| Type | Definition | Can Sum Across | Example |
|------|------------|----------------|---------|
| **Additive** | Summable across all dimensions | Time + All others | `revenue_egp` |
| **Semi-Additive** | Summable across some dimensions | All except time | `inventory_count` |
| **Non-Additive** | Not summable | None | `unit_price`, `roi_pct` |

### Measures by Type

**Additive** (most measures):
- All `*_egp` monetary amounts
- `*_count` counters
- `is_*_flag` booleans (sum gives counts)
- `days_*` durations

**Semi-Additive**:
- `price_per_sqm_egp` — can average across time but not sum
- `discount_pct` — can't sum
- `roi_pct` — can't sum
- `interest_rate` — can't sum

**Non-Additive**:
- `share_price_egp` — not addable (each share priced differently)

### Handling Non-Additive in BI

For **ratios and rates**:
1. Sum the numerator
2. Sum the denominator
3. Divide at query time

**Example**:
```sql
-- WRONG: AVG of AVGs
SELECT AVG(discount_pct) FROM FactDeal;

-- RIGHT: Compute from summed components
SELECT
    SUM(discount_egp) / NULLIF(SUM(list_price_egp), 0) AS discount_pct
FROM FactDeal;
```

---

## 🔄 Slowly Changing Dimensions

### SCD Types Applied

| Dimension | Type | Rationale |
|-----------|:----:|-----------|
| `DimUser` | Type 2 | Track user evolution (role changes, verification) |
| `DimProperty` | Type 2 | Track price and status changes |
| `DimBroker` | Type 2 | Track commission rate and tier evolution |
| `DimDeveloper` | Type 1 | Overwrite (contact info only) |
| `DimGeography` | Type 1 | Overwrite (cache refresh) |
| `DimProduct` | Type 0 | Static (never changes) |
| `DimDate` | Type 0 | Static |
| `DimStatus` | Type 0 | Static |

### SCD Type 2 Mechanics

**Three columns implement Type 2**:

| Column | Purpose |
|--------|---------|
| `valid_from` | Timestamp when this version became active |
| `valid_to` | Timestamp when this version was superseded (NULL if current) |
| `is_current` | Boolean flag (1 = current version) |

**Example lifecycle**:

| user_key | user_id | email | city | valid_from | valid_to | is_current |
|----------|---------|-------|------|-----------|----------|:----------:|
| 1 | 42 | a@x.com | Cairo | 2023-01-15 | 2024-03-20 | 0 |
| 2 | 42 | a@x.com | Giza | 2024-03-20 | NULL | 1 |

**Query patterns**:

```sql
-- Current state only
WHERE is_current = 1

-- As-of historical state
WHERE @report_date BETWEEN valid_from AND ISNULL(valid_to, '9999-12-31')

-- Full change history
SELECT * FROM DimUser WHERE user_id = 42 ORDER BY valid_from
```

### SCD Type 2 in Facts

Fact tables store the **surrogate key** at the time of the event:

- A deal closed on 2024-03-15 points to `user_key = 1` (Cairo version)
- A deal closed on 2024-05-10 points to `user_key = 2` (Giza version)

This preserves historical accuracy — reports can answer "where was the buyer living when they bought this property?"

---

## 👻 Special Members and Null Handling

### Unknown Members

Every dimension has an **"-1 Unknown"** row for orphan facts:

| `*_key` | Meaning |
|---------|---------|
| `-1` | Unknown (source data missing) |
| `-2` | Inferred (late-arriving dimension) |
| `0` | Not Applicable (dimension doesn't apply) |

### Why This Matters

- **Facts never have NULL FKs** — always joinable
- **Reports never break** due to missing dimension data
- **Unknown rows are auditable** — trackable for data quality

### NULL Handling Rules

| Layer | Rule |
|-------|------|
| **Bronze** | Preserve NULLs (raw truth) |
| **Silver** | Replace NULLs with defaults where semantically valid |
| **Gold** | Never store NULLs in keys; may store NULLs in measures |

### Example — Unknown User

If a fact refers to a user that doesn't exist in `DimUser` (edge case), the ETL creates an **Inferred Member**:

```sql
INSERT INTO nawy_dw.DimUser
    (user_key, user_id, full_name, is_current, valid_from)
VALUES
    (-2, @user_id, 'Inferred - ' + CAST(@user_id AS NVARCHAR), 1, SYSDATETIMEOFFSET());
```

When the actual dimension arrives, the inferred row is merged.

---

## 🔢 Degenerate Dimensions

### What Are They?

**Degenerate dimensions** are dimension-like attributes stored **directly in the fact table** without a separate dimension table. They have low cardinality and no descriptive attributes.

### Where We Use Them

| Fact Table | Degenerate Dimension | Purpose |
|-----------|----------------------|---------|
| FactLead | `lead_id` | Drill-through to source |
| FactDeal | `deal_id`, `payment_type_code` | Traceability |
| FactCommission | `commission_id`, `deal_id` | Link back to deal |
| FactMortgageApplication | `application_id` | Traceability |
| FactEscrow | `escrow_id`, `account_number` | Regulatory audit |
| FactUserActivity | `session_id` | Session trace |
| FactRevenue | `revenue_id`, `invoice_number` | Financial audit |

### Why Not Separate Tables?

Creating a `DimDeal` with 380 rows and no descriptive attributes provides no analytical value. Storing the ID directly in the fact table is cleaner.

---

## 🗑️ Junk Dimensions

### What Are They?

**Junk dimensions** combine multiple low-cardinality flags/indicators into a single dimension table.

### Where We Use Them

| Junk Dimension | Combines | Used By |
|----------------|----------|---------|
| `DimTransactionFlags` | is_mortgage, is_resale, is_primary, is_urgent | FactDeal |

**Example**:

| flag_key | is_mortgage | is_resale | is_primary | is_urgent |
|---------:|:-----------:|:---------:|:----------:|:---------:|
| 1 | 0 | 0 | 1 | 0 |
| 2 | 1 | 0 | 1 | 0 |
| 3 | 0 | 1 | 0 | 1 |
| ... | ... | ... | ... | ... |

### Why This Helps

Without junk dimensions, you'd need:
- 4 separate `is_*` columns in `FactDeal`
- Each consuming ~1 byte

With a junk dimension:
- 1 foreign key column
- Enables combinational analysis ("mortgages on resale properties")

**Rule**: Use junk dimensions when you have **3+ low-cardinality flags** that are analyzed together.

---

## 🎭 Role-Playing Dimensions

### What Are They?

The **same dimension** used in **multiple roles** within a single fact table. Instead of duplicating the dimension, you use different column names that reference the same `*_key`.

### Where We Use Them

| Fact Table | Dimension | Roles | Column Names |
|-----------|-----------|-------|--------------|
| FactLead | DimDate | Created + Last Activity | `created_date_key`, `last_activity_date_key` |
| FactMortgageApplication | DimDate | Submitted + Approved | `submitted_date_key`, `approved_date_key` |
| FactMortgagePayment | DimDate | Due + Paid | `due_date_key`, `paid_date_key` |
| FactLease | DimDate | Start + End | `start_date_key`, `end_date_key` |
| FactLease | DimUser | Tenant + Owner | `tenant_key`, `owner_key` |
| FactRentPayment | DimDate | Due + Paid | `due_date_key`, `paid_date_key` |
| FactRentPayment | DimUser | Tenant + Owner | `tenant_key`, `owner_key` |

### Query Pattern

```sql
SELECT
    d_due.year_month AS due_month,
    d_paid.year_month AS paid_month,
    SUM(f.amount_egp) AS rent_amount
FROM nawy_dw.FactRentPayment f
JOIN nawy_dw.DimDate d_due ON f.due_date_key = d_due.date_key
JOIN nawy_dw.DimDate d_paid ON f.paid_date_key = d_paid.date_key
GROUP BY d_due.year_month, d_paid.year_month;
```

**Rule**: Never create `DimDueDate` and `DimPaidDate` — use one `DimDate` with two role-playing keys.

---

## ❄️ Snowflaking Decisions

### What Is Snowflaking?

**Snowflaking** means normalizing a dimension into multiple related tables (splitting `DimProperty` into `DimProperty`, `DimPropertyType`, `DimFinishing`).

### Our Rule: **Avoid Snowflaking**

We keep dimensions **denormalized** (flat star schemas) for these reasons:

| Reason | Impact |
|--------|--------|
| **Query performance** | No extra joins |
| **Simplicity** | BI developers understand stars |
| **Tool compatibility** | Tableau/Power BI work best with stars |
| **Storage is cheap** | Extra columns cost pennies |

### Exception: When We Snowflake

We only snowflake when:

1. **Attribute cardinality is huge** — e.g., a `DimCityMap` with 10K+ cities
2. **Attribute groups change independently** — e.g., a `DimDeveloperContact` that changes weekly

Currently, no dimension in our model meets these criteria.

---

## 📊 Aggregate Design

### Why Aggregates?

Pre-computed aggregates deliver **10–100× query speedup** for common dashboard queries.

### Aggregate Tables

| Aggregate | Grain | Refresh | Purpose |
|-----------|-------|---------|---------|
| `AggDailySales` | Date × City × Property Type | Hourly | Sales dashboard |
| `AggDailyRevenue` | Date × Business Line | Hourly | Revenue dashboard |
| `AggMonthlyKPIs` | Month × Business Line | Daily | Executive dashboard |
| `AggBrokerPerformance` | Broker × Month | Daily | Broker leaderboard |
| `AggPropertyPerformance` | Property × Month | Daily | Asset management |
| `AggUserEngagement` | User × Month | Daily | CLV analysis |

### Aggregate Table Structure

Each aggregate table:

- Has the **same dimensional keys** as the base fact
- Contains **pre-summed measures**
- Is populated by a nightly/hourly ETL job
- Is **optional** — reports fall back to base facts if not present

### Example: `AggDailySales`

```sql
CREATE TABLE nawy_dw.AggDailySales (
    date_key INT NOT NULL,
    geography_key BIGINT NOT NULL,
    property_type_key BIGINT NOT NULL,
    payment_type_key BIGINT NOT NULL,
    deal_count INT NOT NULL,
    total_gmv_egp DECIMAL(18,2) NOT NULL,
    total_commission_egp DECIMAL(18,2) NOT NULL,
    avg_deal_size_egp DECIMAL(18,2) NOT NULL,
    _refreshed_at DATETIMEOFFSET NOT NULL
);
```

### Aggregate Selection Strategy

| Query Pattern | Use Aggregate | Fallback to Fact |
|---------------|:-------------:|:----------------:|
| Executive dashboard | ✅ | — |
| Sales trend last 30 days | ✅ | — |
| Broker leaderboard | ✅ | — |
| Drill to specific deal | — | ✅ |
| Ad-hoc analysis | — | ✅ |
| Cross-business CLV | ✅ (AggUserEngagement) | — |

### Aggregate Refresh

- **Incremental** where possible (only new/changed data)
- **Full rebuild** monthly (data quality check)
- **Parallel** refresh across tables
- **Monitored** with alerts on failure

---

## 🚫 Modeling Anti-Patterns Avoided

| Anti-Pattern | Why It's Bad | Our Approach |
|--------------|--------------|--------------|
| **NULL in foreign keys** | Breaks joins | Use "-1 Unknown" member |
| **Mixed grain facts** | Ambiguous aggregation | One grain per fact table |
| **Snowflaked dimensions** | Slow joins | Flat star schemas |
| **Non-additive facts everywhere** | Can't aggregate | Prefer additive; document non-additive |
| **Natural keys as surrogate** | Slow, coupled to source | Use integer surrogate keys |
| **Descriptive text in facts** | Bloats fact tables | Move to dimensions |
| **SCD Type 1 for critical attributes** | Loses history | Type 2 for tracked attributes |
| **Composite keys** | Slow joins | Single integer surrogate |
| **Too many dimensions per fact** | Wide, slow queries | Keep it lean, use role-playing |
| **Dimension attribute bloat** | Slow dimension loads | Only include analytical attributes |
| **Facts without a bus matrix row** | Inconsistent metrics | Every fact has a documented row |
| **Reports bypassing the DW** | Slow, inconsistent | All BI goes through DW |
| **Version churn without business reason** | Data noise | SCD Type 2 only for meaningful changes |
| **Over-modeling (Data Vault for small DW)** | Complexity without benefit | Kimball for mid-size DW |

---

## 🔍 Query Examples

### Example 1 — Sales Dashboard

```sql
-- Total GMV by month and city
SELECT
    d.year_month,
    g.city,
    SUM(f.gmv_egp) AS total_gmv,
    COUNT(f.deal_key) AS deal_count,
    SUM(f.gmv_egp) / COUNT(f.deal_key) AS avg_deal_size
FROM nawy_dw.FactDeal f
JOIN nawy_dw.DimDate d ON f.closed_date_key = d.date_key
JOIN nawy_dw.DimProperty p ON f.property_key = p.property_key AND p.is_current = 1
JOIN nawy_dw.DimGeography g ON p.geography_key = g.geography_key
WHERE d.year = 2026
GROUP BY d.year_month, g.city
ORDER BY d.year_month, total_gmv DESC;
```

### Example 2 — CLV by User

```sql
-- Total lifetime value per user across all business lines
SELECT
    u.user_key,
    u.full_name,
    u.clv_tier,
    SUM(r.revenue_amount_egp) AS total_revenue
FROM nawy_dw.DimUser u
JOIN nawy_dw.FactRevenue r ON u.user_key = r.user_key
WHERE u.is_current = 1
GROUP BY u.user_key, u.full_name, u.clv_tier
ORDER BY total_revenue DESC;
```

### Example 3 — Funnel Analysis

```sql
-- Conversion rates by source
SELECT
    f.source,
    COUNT(*) AS total_leads,
    SUM(f.is_won_flag) AS won,
    SUM(f.is_lost_flag) AS lost,
    CAST(100.0 * SUM(f.is_won_flag) / COUNT(*) AS DECIMAL(5,2)) AS conversion_pct
FROM nawy_dw.FactLead f
GROUP BY f.source
ORDER BY conversion_pct DESC;
```

### Example 4 — SCD Type 2 History

```sql
-- Full history of a specific property's price changes
SELECT
    p.property_key,
    p.current_price_egp,
    p.current_status,
    p.valid_from,
    p.valid_to,
    p.is_current
FROM nawy_dw.DimProperty p
WHERE p.property_id = 42
ORDER BY p.valid_from;
```

### Example 5 — Accumulating Snapshot

```sql
-- Mortgage application process durations
SELECT
    AVG(DATEDIFF(DAY,
        d_submitted.date,
        d_approved.date)) AS avg_days_to_approval,
    COUNT(*) AS total_applications
FROM nawy_dw.FactMortgageApplication f
JOIN nawy_dw.DimDate d_submitted ON f.submitted_date_key = d_submitted.date_key
JOIN nawy_dw.DimDate d_approved ON f.approved_date_key = d_approved.date_key
WHERE f.is_approved_flag = 1;
```

### Example 6 — Role-Playing Dimension

```sql
-- Rent payments received early vs late
SELECT
    CASE
        WHEN d_paid.date < d_due.date THEN 'Early'
        WHEN d_paid.date = d_due.date THEN 'On Time'
        ELSE 'Late'
    END AS payment_timing,
    COUNT(*) AS payment_count,
    SUM(f.amount_egp) AS total_amount
FROM nawy_dw.FactRentPayment f
JOIN nawy_dw.DimDate d_due ON f.due_date_key = d_due.date_key
LEFT JOIN nawy_dw.DimDate d_paid ON f.paid_date_key = d_paid.date_key
WHERE f.is_paid_flag = 1
GROUP BY
    CASE
        WHEN d_paid.date < d_due.date THEN 'Early'
        WHEN d_paid.date = d_due.date THEN 'On Time'
        ELSE 'Late'
    END;
```

---
