# Query 8 — Property Profitability

> **Analytical SQL Query for Nawy Proptech Platform**



## 📖 Table of Contents

- [Business Question](#-business-question)
- [Business Context](#-business-context)
- [The Query](#-the-query)
- [Code Walkthrough](#-code-walkthrough)
- [Expected Output](#-expected-output)
- [Interpretation Guide](#-interpretation-guide)
- [Analytical Extensions](#-analytical-extensions)
- [Performance Notes](#-performance-notes)



## 🎯 Business Question

> **What is the total revenue each property generates across all Nawy business lines, and which assets deliver the highest return on Nawy's investment?**

---

## 💼 Business Context

### Why This Matters to Nawy

Nawy's core competitive advantage is its **asset-centric model**. Unlike traditional brokerages that profit once per transaction, Nawy monetizes each property through **multiple revenue streams** across its five business lines. Understanding property-level profitability is critical for:

1. **Portfolio Management** — Which properties to promote, which to deprioritize
2. **Developer Partnerships** — Negotiate better terms for properties that perform well
3. **Nawy Shares Selection** — Identify properties that generate high returns AND high fees
4. **Investment Committee** — Justify acquisition of new inventory
5. **Operations** — Allocate marketing budget by property ROI

### The Multi-Revenue Model

A single property can generate revenue from up to **five sources**:

| Source | Business Line | Revenue Component |
|--------|---------------|-------------------|
| **1. Broker Commission** | Nawy Partners | 2.5% of sale price |
| **2. Mortgage Interest** | Nawy Now | Loan × interest rate |
| **3. Shares Exit Fee** | Nawy Shares | 2.5–5% of resale value |
| **4. Management Fee** | Nawy Unlocked | 10% of monthly rent |
| **5. Rent Financing** | Nawy Unlocked | Up to 50% of finishing costs |

**Key insight**: A property that sells once through Nawy Partners generates ~2.5% of price. A property that ALSO has fractional investment, mortgage financing, and rental management can generate **15–25% of price** over its lifetime.

### Who Uses This Query

| Role | Purpose |
|------|---------|
| **Asset Management Team** | Portfolio performance review |
| **Nawy Shares Committee** | Property selection for fractional offerings |
| **Developer Relations** | Rank developer performance |
| **Marketing Team** | Allocate ad spend by property ROI |
| **Executive Team** | Report on unit economics |
| **Finance** | Asset-level P&L |

### What "Good" Looks Like

| Property Revenue | Classification | Action |
|------------------|----------------|--------|
| **> 20% of price** | Premium asset | Feature prominently; acquire more like it |
| **10–20% of price** | Strong performer | Continue promoting |
| **5–10% of price** | Standard | Monitor performance |
| **2–5% of price** | Below average | Investigate bottleneck |
| **< 2% of price** | Underperformer | Deprioritize or exit |

### The Compound Effect

Properties in the same compound often show similar performance patterns. This query enables **compound-level analysis** — helping Nawy prioritize exclusive partnerships with developers in high-performing communities.

---

## 🔍 The Query

```sql
-- Query 8: Property-Level Profitability
-- Business Question:
--   What is the total revenue each property generates across
--   all Nawy business lines, and which assets deliver the
--   highest return on Nawy's investment?
--
-- Used By:
--   - Asset management team (portfolio review)
--   - Nawy Shares committee (property selection)
--   - Developer relations (partner ranking)
--   - Marketing (ad spend allocation)
--   - Executive team (unit economics)
--
-- Output:
--   Part 1: Per-property revenue across all business lines
--   Part 2: Summary by city and property type
--   Part 3: Top compounds and developers
--


USE NawyProptechDB;
GO

-- PART 1: PER-PROPERTY REVENUE BREAKDOWN
-- For each property, compute revenue from five sources:
--   1. Broker commission (Nawy Partners)
--   2. Mortgage interest (Nawy Now)
--   3. Shares exit fees (Nawy Shares)
--   4. Management fees (Nawy Unlocked)
--   5. Finishing financing (Nawy Unlocked)
--
-- Also compute revenue as % of listing price to normalize
-- across property size and price range.

WITH property_revenue AS (
    SELECT
        p.property_id,
        p.title,
        p.property_type,
        p.listing_type,
        p.city,
        p.district,
        p.compound_name,
        p.price                                 AS listing_price,
        p.currency,
        p.status                                AS property_status,
        p.created_at                            AS listed_at,
        d.name                                  AS developer_name,
        d.partnership_tier                      AS developer_tier,

        -- Revenue stream 1: Broker commission (from completed deals)
        ISNULL((
            SELECT SUM(c.commission_amount)
            FROM nawy.COMMISSION c
            INNER JOIN nawy.DEAL dl ON c.deal_id = dl.deal_id
            WHERE dl.property_id = p.property_id
              AND c.status = 'paid'
        ), 0) AS commission_revenue,

        -- Revenue stream 2: Mortgage interest (first year approximation)
        ISNULL((
            SELECT SUM(ma.loan_amount * ISNULL(ma.interest_rate, 0))
            FROM nawy.MORTGAGE_APPLICATION ma
            WHERE ma.property_id = p.property_id
              AND ma.status = 'disbursed'
        ), 0) AS mortgage_revenue,

        -- Revenue stream 3: Shares exit fees
        ISNULL((
            SELECT SUM(se.total_sale_value * se.exit_fee_percent)
            FROM nawy.SHARE_EXIT se
            INNER JOIN nawy.SHARE_INVESTMENT si
                ON se.investment_id = si.investment_id
            INNER JOIN nawy.SHARE_OFFERING so
                ON si.offering_id = so.offering_id
            WHERE so.property_id = p.property_id
              AND se.status = 'completed'
        ), 0) AS shares_revenue,

        -- Revenue stream 4: Management fees from rentals
        ISNULL((
            SELECT SUM(rp.amount * mc.management_fee_percent)
            FROM nawy.RENT_PAYMENT rp
            INNER JOIN nawy.LEASE l ON rp.lease_id = l.lease_id
            INNER JOIN nawy.MANAGEMENT_CONTRACT mc ON l.contract_id = mc.contract_id
            WHERE mc.property_id = p.property_id
              AND rp.status = 'paid'
        ), 0) AS management_revenue,

        -- Revenue stream 5: Finishing financing recovered
        ISNULL((
            SELECT SUM(fp.actual_cost * mc.financing_percent)
            FROM nawy.FINISHING_PROJECT fp
            INNER JOIN nawy.MANAGEMENT_CONTRACT mc
                ON fp.contract_id = mc.contract_id
            WHERE mc.property_id = p.property_id
              AND fp.status = 'completed'
        ), 0) AS finishing_revenue

    FROM nawy.PROPERTY p
    LEFT JOIN nawy.DEVELOPER d
        ON p.developer_id = d.developer_id
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY (commission_revenue + mortgage_revenue + shares_revenue
                  + management_revenue + finishing_revenue) DESC
    ) AS rank,
    property_id,
    title,
    property_type,
    listing_type,
    city,
    district,
    compound_name,
    developer_name,
    developer_tier,
    CAST(listing_price AS DECIMAL(15,2))        AS listing_price_egp,
    property_status,

    -- Revenue breakdown
    CAST(commission_revenue AS DECIMAL(18,2))   AS commission_revenue_egp,
    CAST(mortgage_revenue AS DECIMAL(18,2))     AS mortgage_revenue_egp,
    CAST(shares_revenue AS DECIMAL(18,2))       AS shares_revenue_egp,
    CAST(management_revenue AS DECIMAL(18,2))   AS management_revenue_egp,
    CAST(finishing_revenue AS DECIMAL(18,2))    AS finishing_revenue_egp,

    -- Total revenue
    CAST(
        (commission_revenue + mortgage_revenue + shares_revenue
         + management_revenue + finishing_revenue)
        AS DECIMAL(18,2)
    ) AS total_revenue_egp,

    -- Revenue as % of listing price
    CAST(
        CASE WHEN listing_price = 0 THEN 0
             ELSE 100.0 * (commission_revenue + mortgage_revenue + shares_revenue
                          + management_revenue + finishing_revenue)
                        / listing_price
        END AS DECIMAL(10,2)
    ) AS revenue_pct_of_price,

    -- Revenue source count
    (
        CASE WHEN commission_revenue > 0 THEN 1 ELSE 0 END +
        CASE WHEN mortgage_revenue > 0 THEN 1 ELSE 0 END +
        CASE WHEN shares_revenue > 0 THEN 1 ELSE 0 END +
        CASE WHEN management_revenue > 0 THEN 1 ELSE 0 END +
        CASE WHEN finishing_revenue > 0 THEN 1 ELSE 0 END
    ) AS revenue_sources_count,

    -- Performance tier
    CASE
        WHEN (commission_revenue + mortgage_revenue + shares_revenue
              + management_revenue + finishing_revenue) = 0
            THEN 'No Revenue'
        WHEN listing_price > 0
             AND 100.0 * (commission_revenue + mortgage_revenue + shares_revenue
                          + management_revenue + finishing_revenue)
                        / listing_price >= 15
            THEN 'Premium Asset'
        WHEN listing_price > 0
             AND 100.0 * (commission_revenue + mortgage_revenue + shares_revenue
                          + management_revenue + finishing_revenue)
                        / listing_price >= 5
            THEN 'Strong Performer'
        WHEN listing_price > 0
             AND 100.0 * (commission_revenue + mortgage_revenue + shares_revenue
                          + management_revenue + finishing_revenue)
                        / listing_price >= 2
            THEN 'Standard'
        ELSE 'Underperformer'
    END AS performance_tier

FROM property_revenue
ORDER BY total_revenue_egp DESC;
GO

-- PART 2: SUMMARY BY CITY AND PROPERTY TYPE
-- Aggregate property-level profitability to identify the best
-- performing segments.

WITH property_revenue AS (
    SELECT
        p.property_id,
        p.city,
        p.property_type,
        p.price AS listing_price,
        ISNULL((SELECT SUM(c.commission_amount)
                FROM nawy.COMMISSION c
                INNER JOIN nawy.DEAL dl ON c.deal_id = dl.deal_id
                WHERE dl.property_id = p.property_id AND c.status = 'paid'), 0) AS commission_revenue,
        ISNULL((SELECT SUM(ma.loan_amount * ISNULL(ma.interest_rate, 0))
                FROM nawy.MORTGAGE_APPLICATION ma
                WHERE ma.property_id = p.property_id AND ma.status = 'disbursed'), 0) AS mortgage_revenue,
        ISNULL((SELECT SUM(se.total_sale_value * se.exit_fee_percent)
                FROM nawy.SHARE_EXIT se
                INNER JOIN nawy.SHARE_INVESTMENT si ON se.investment_id = si.investment_id
                INNER JOIN nawy.SHARE_OFFERING so ON si.offering_id = so.offering_id
                WHERE so.property_id = p.property_id AND se.status = 'completed'), 0) AS shares_revenue,
        ISNULL((SELECT SUM(rp.amount * mc.management_fee_percent)
                FROM nawy.RENT_PAYMENT rp
                INNER JOIN nawy.LEASE l ON rp.lease_id = l.lease_id
                INNER JOIN nawy.MANAGEMENT_CONTRACT mc ON l.contract_id = mc.contract_id
                WHERE mc.property_id = p.property_id AND rp.status = 'paid'), 0) AS management_revenue,
        ISNULL((SELECT SUM(fp.actual_cost * mc.financing_percent)
                FROM nawy.FINISHING_PROJECT fp
                INNER JOIN nawy.MANAGEMENT_CONTRACT mc ON fp.contract_id = mc.contract_id
                WHERE mc.property_id = p.property_id AND fp.status = 'completed'), 0) AS finishing_revenue
    FROM nawy.PROPERTY p
)
SELECT
    city,
    property_type,
    COUNT(*)                                    AS property_count,
    CAST(AVG(listing_price) AS DECIMAL(15,2))   AS avg_listing_price,
    CAST(SUM(commission_revenue + mortgage_revenue + shares_revenue
             + management_revenue + finishing_revenue) AS DECIMAL(18,2)) AS total_revenue_egp,
    CAST(AVG(commission_revenue + mortgage_revenue + shares_revenue
             + management_revenue + finishing_revenue) AS DECIMAL(18,2)) AS avg_revenue_per_property,
    CAST(
        CASE WHEN SUM(listing_price) = 0 THEN 0
             ELSE 100.0 * SUM(commission_revenue + mortgage_revenue + shares_revenue
                              + management_revenue + finishing_revenue)
                        / SUM(listing_price)
        END AS DECIMAL(10,2)
    ) AS avg_revenue_pct_of_price
FROM property_revenue
GROUP BY city, property_type
HAVING COUNT(*) >= 3
ORDER BY total_revenue_egp DESC;
GO

-- PART 3: TOP COMPOUNDS AND DEVELOPERS
-- Identify which compounds and developers generate the most
-- revenue for Nawy — informs exclusive partnerships.

WITH property_revenue AS (
    SELECT
        p.property_id,
        p.compound_name,
        p.price AS listing_price,
        d.developer_id,
        d.name AS developer_name,
        d.partnership_tier,
        ISNULL((SELECT SUM(c.commission_amount)
                FROM nawy.COMMISSION c
                INNER JOIN nawy.DEAL dl ON c.deal_id = dl.deal_id
                WHERE dl.property_id = p.property_id AND c.status = 'paid'), 0) AS commission_revenue,
        ISNULL((SELECT SUM(ma.loan_amount * ISNULL(ma.interest_rate, 0))
                FROM nawy.MORTGAGE_APPLICATION ma
                WHERE ma.property_id = p.property_id AND ma.status = 'disbursed'), 0) AS mortgage_revenue,
        ISNULL((SELECT SUM(se.total_sale_value * se.exit_fee_percent)
                FROM nawy.SHARE_EXIT se
                INNER JOIN nawy.SHARE_INVESTMENT si ON se.investment_id = si.investment_id
                INNER JOIN nawy.SHARE_OFFERING so ON si.offering_id = so.offering_id
                WHERE so.property_id = p.property_id AND se.status = 'completed'), 0) AS shares_revenue,
        ISNULL((SELECT SUM(rp.amount * mc.management_fee_percent)
                FROM nawy.RENT_PAYMENT rp
                INNER JOIN nawy.LEASE l ON rp.lease_id = l.lease_id
                INNER JOIN nawy.MANAGEMENT_CONTRACT mc ON l.contract_id = mc.contract_id
                WHERE mc.property_id = p.property_id AND rp.status = 'paid'), 0) AS management_revenue
    FROM nawy.PROPERTY p
    LEFT JOIN nawy.DEVELOPER d ON p.developer_id = d.developer_id
)
SELECT
    'Compound' AS group_type,
    ISNULL(compound_name, '(No Compound)') AS group_name,
    NULL AS partnership_tier,
    COUNT(*) AS property_count,
    CAST(SUM(commission_revenue + mortgage_revenue + shares_revenue
             + management_revenue) AS DECIMAL(18,2)) AS total_revenue_egp,
    CAST(AVG(commission_revenue + mortgage_revenue + shares_revenue
             + management_revenue) AS DECIMAL(18,2)) AS avg_revenue_per_property
FROM property_revenue
WHERE compound_name IS NOT NULL
GROUP BY compound_name
HAVING COUNT(*) >= 3

UNION ALL

SELECT
    'Developer' AS group_type,
    ISNULL(developer_name, '(Unknown)') AS group_name,
    MAX(partnership_tier) AS partnership_tier,
    COUNT(*) AS property_count,
    CAST(SUM(commission_revenue + mortgage_revenue + shares_revenue
             + management_revenue) AS DECIMAL(18,2)) AS total_revenue_egp,
    CAST(AVG(commission_revenue + mortgage_revenue + shares_revenue
             + management_revenue) AS DECIMAL(18,2)) AS avg_revenue_per_property
FROM property_revenue
WHERE developer_name IS NOT NULL
GROUP BY developer_name
HAVING COUNT(*) >= 3

ORDER BY group_type, total_revenue_egp DESC;
GO
```

---

## 🔬 Code Walkthrough

### Section 1 — CTE: `property_revenue`

**Purpose**: Compute five revenue streams per property.

**Key techniques**:

| Technique | Purpose |
|-----------|---------|
| `LEFT JOIN` to `DEVELOPER` | Some properties have no developer (resale) |
| `ISNULL((subquery), 0)` | Zero-revenue properties still appear |
| Correlated subqueries | Isolate each revenue stream cleanly |
| `d.partnership_tier` | Enrich with developer tier for analysis |

**Why five separate subqueries?**

Each revenue stream has a different **grain**:

- Commission: one row per completed deal
- Mortgage: one row per disbursed mortgage
- Shares: one row per completed exit
- Management: one row per paid rent payment
- Finishing: one row per completed finishing project

Using subqueries avoids **Cartesian explosion** when a property has, say, 3 deals AND 5 rent payments AND 2 exits.

---

### Section 2 — Revenue Streams Explained

#### Stream 1: Broker Commission

```sql
SELECT SUM(c.commission_amount)
FROM nawy.COMMISSION c
INNER JOIN nawy.DEAL dl ON c.deal_id = dl.deal_id
WHERE dl.property_id = p.property_id
  AND c.status = 'paid'
```

**What it means**: If Nawy brokers closed the deal, the platform earned a 2.5% commission. We sum all commissions across all deals on this property (resale properties may be sold multiple times).

---

#### Stream 2: Mortgage Interest

```sql
SELECT SUM(ma.loan_amount * ISNULL(ma.interest_rate, 0))
FROM nawy.MORTGAGE_APPLICATION ma
WHERE ma.property_id = p.property_id
  AND ma.status = 'disbursed'
```

**What it means**: Nawy Now earns interest on mortgages. We approximate **first-year interest** to make properties comparable.

---

#### Stream 3: Shares Exit Fees

```sql
SELECT SUM(se.total_sale_value * se.exit_fee_percent)
FROM nawy.SHARE_EXIT se
INNER JOIN nawy.SHARE_INVESTMENT si ON se.investment_id = si.investment_id
INNER JOIN nawy.SHARE_OFFERING so ON si.offering_id = so.offering_id
WHERE so.property_id = p.property_id
  AND se.status = 'completed'
```

**What it means**: When fractional investors exit, Nawy takes 2.5–5% of the resale value. This is pure platform revenue.

**Why this is high-value**: If a property generates 5% from a single sale AND 5% from fractional exits, that's 10% total — 4× the commission-only revenue.

---

#### Stream 4: Management Fees

```sql
SELECT SUM(rp.amount * mc.management_fee_percent)
FROM nawy.RENT_PAYMENT rp
INNER JOIN nawy.LEASE l ON rp.lease_id = l.lease_id
INNER JOIN nawy.MANAGEMENT_CONTRACT mc ON l.contract_id = mc.contract_id
WHERE mc.property_id = p.property_id
  AND rp.status = 'paid'
```

**What it means**: Nawy Unlocked keeps ~10% of monthly rent. Over a 2-year lease at 20K EGP/month, that's **48K EGP** in Nawy revenue from a single tenant.

---

#### Stream 5: Finishing Financing

```sql
SELECT SUM(fp.actual_cost * mc.financing_percent)
FROM nawy.FINISHING_PROJECT fp
INNER JOIN nawy.MANAGEMENT_CONTRACT mc ON fp.contract_id = mc.contract_id
WHERE mc.property_id = p.property_id
  AND fp.status = 'completed'
```

**What it means**: Nawy covers up to 50% of finishing costs, repaid via rental income. This is a **one-time revenue** event per property.

---

### Section 3 — Revenue as % of Price

```sql
CAST(
    CASE WHEN listing_price = 0 THEN 0
         ELSE 100.0 * (commission_revenue + mortgage_revenue + shares_revenue
                      + management_revenue + finishing_revenue)
                    / listing_price
    END AS DECIMAL(10,2)
) AS revenue_pct_of_price
```

**Why normalize by price?**

A 50M EGP villa generating 500K EGP revenue (1%) is less impressive than a 3M EGP apartment generating 500K EGP revenue (16.7%).

This metric lets us compare properties of vastly different price points.

---

### Section 4 — Performance Tiers

```sql
CASE
    WHEN total_revenue = 0 THEN 'No Revenue'
    WHEN revenue_pct >= 15 THEN 'Premium Asset'
    WHEN revenue_pct >= 5  THEN 'Strong Performer'
    WHEN revenue_pct >= 2  THEN 'Standard'
    ELSE 'Underperformer'
END
```

**Tier rationale**:

| Tier | Revenue % | Action |
|------|-----------|--------|
| **Premium** | ≥ 15% | Showcase in investor decks |
| **Strong** | 5–15% | Standard promotion |
| **Standard** | 2–5% | Monitor |
| **Underperformer** | < 2% | Investigate bottleneck |

---

### Section 5 — Part 3: Compound & Developer Analysis

**Purpose**: Identify which compounds and developers generate the most revenue.

**Key technique — UNION ALL**:

Two independent aggregations are combined:

- First block: aggregate by compound
- Second block: aggregate by developer

`UNION ALL` (not `UNION`) preserves duplicates and is faster.

**Why compound analysis?**

Compounds are Nawy's unit of market focus. If Badya consistently outperforms, Nawy should:

- Acquire more inventory there
- Negotiate exclusive deals with the developer
- Feature it in marketing

---

## 📊 Expected Output

### Part 1 — Sample Result Set (Per-Property)

| rank | property_id | title | property_type | city | compound_name | developer_name | developer_tier | listing_price_egp | total_revenue_egp | revenue_pct_of_price | revenue_sources_count | performance_tier |
|------|-------------|-------|---------------|------|---------------|----------------|----------------|-------------------|-------------------|----------------------|-----------------------|------------------|
| 1 | 42 | 3BR Apartment in Villette | apartment | Cairo | Villette | SODIC | exclusive | 5,800,000.00 | 1,245,000.00 | 21.47 | 4 | Premium Asset |
| 2 | 15 | 2BR Apartment in Badya | apartment | Giza | Badya | Palm Hills | exclusive | 3,200,000.00 | 685,000.00 | 21.41 | 4 | Premium Asset |
| 3 | 78 | 4BR Villa in Marassi | villa | North Coast | Marassi | Emaar Misr | exclusive | 12,500,000.00 | 2,180,000.00 | 17.44 | 5 | Premium Asset |
| 4 | 89 | 3BR Townhouse in Swan Lake | townhouse | Cairo | Swan Lake | Hassan Allam | premium | 6,800,000.00 | 980,000.00 | 14.41 | 3 | Strong Performer |
| 5 | 33 | 2BR Apartment in Hyde Park | apartment | Cairo | Hyde Park | HYDE Park | premium | 3,400,000.00 | 478,000.00 | 14.06 | 4 | Strong Performer |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Part 2 — Sample Result Set (Summary)

| city | property_type | property_count | avg_listing_price | total_revenue_egp | avg_revenue_per_property | avg_revenue_pct_of_price |
|------|---------------|----------------|-------------------|-------------------|--------------------------|--------------------------|
| North Coast | chalet | 28 | 8,250,000.00 | 12,850,000.00 | 458,928.57 | 5.56 |
| Cairo | villa | 45 | 14,500,000.00 | 18,240,000.00 | 405,333.33 | 2.80 |
| Cairo | apartment | 145 | 4,200,000.00 | 42,300,000.00 | 291,724.14 | 6.95 |
| Giza | apartment | 78 | 2,850,000.00 | 18,600,000.00 | 238,461.54 | 8.36 |
| Cairo | townhouse | 38 | 6,200,000.00 | 8,240,000.00 | 216,842.11 | 3.50 |

### Part 3 — Sample Result Set (Compounds & Developers)

| group_type | group_name | partnership_tier | property_count | total_revenue_egp | avg_revenue_per_property |
|------------|-----------|------------------|----------------|-------------------|--------------------------|
| Compound | Villette | NULL | 22 | 8,900,000.00 | 404,545.45 |
| Compound | Badya | NULL | 18 | 6,850,000.00 | 380,555.56 |
| Compound | Marassi | NULL | 15 | 6,200,000.00 | 413,333.33 |
| Compound | Hyde Park | NULL | 26 | 5,890,000.00 | 226,538.46 |
| Compound | Swan Lake | NULL | 12 | 4,560,000.00 | 380,000.00 |
| Developer | SODIC | exclusive | 68 | 24,800,000.00 | 364,705.88 |
| Developer | Palm Hills | exclusive | 78 | 28,500,000.00 | 365,384.62 |
| Developer | Emaar Misr | exclusive | 55 | 18,900,000.00 | 343,636.36 |
| Developer | HYDE Park | premium | 42 | 10,200,000.00 | 242,857.14 |
| Developer | Hassan Allam | premium | 38 | 8,750,000.00 | 230,263.16 |

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `rank` | INT | Property ranking by revenue |
| `property_id` | BIGINT | Unique property identifier |
| `title` | NVARCHAR | Property name |
| `property_type` | NVARCHAR | apartment, villa, etc. |
| `city` | NVARCHAR | Location |
| `district` | NVARCHAR | Neighborhood |
| `compound_name` | NVARCHAR | Compound |
| `developer_name` | NVARCHAR | Developer company |
| `developer_tier` | NVARCHAR | standard, premium, exclusive |
| `listing_price_egp` | DECIMAL | Listing price |
| `commission_revenue_egp` | DECIMAL | Broker commission revenue |
| `mortgage_revenue_egp` | DECIMAL | Mortgage interest revenue |
| `shares_revenue_egp` | DECIMAL | Shares exit fee revenue |
| `management_revenue_egp` | DECIMAL | Management fee revenue |
| `finishing_revenue_egp` | DECIMAL | Finishing financing revenue |
| `total_revenue_egp` | DECIMAL | Sum of all revenue |
| `revenue_pct_of_price` | DECIMAL | Revenue as % of listing price |
| `revenue_sources_count` | INT | Number of active revenue streams |
| `performance_tier` | NVARCHAR | Premium / Strong / Standard / Underperformer |

---

## 📈 Interpretation Guide

### Reading the Per-Property Output

**Sample observation**: Property #42 (Villette apartment):

- **Listing price**: 5.8M EGP
- **Total revenue**: 1.245M EGP → **21.47% of price**
- **Revenue sources**: 4 streams
- **Tier: Premium Asset**

**What this tells us**:

- This property is a **revenue machine** for Nawy
- It sold, financed, was offered fractionally, AND is managed
- **Action**: Feature in investor decks; replicate profile

**Sample observation**: Property #78 (Marassi villa):

- **Listing price**: 12.5M EGP
- **Total revenue**: 2.18M EGP → **17.44% of price**
- **Revenue sources**: **5 streams** — all five revenue lines engaged
- **Tier: Premium Asset**

**What this tells us**:

- The **holy grail property** — full vertical integration
- Generates commission + mortgage + shares + management + finishing
- **Action**: Study what made this possible; replicate

### Reading the Summary

**Key insights from sample data**:

| Segment | Revenue % | Volume | Strategic Value |
|---------|-----------|--------|-----------------|
| **Giza apartments** | 8.36% | 78 | High margin — focus here |
| **Cairo apartments** | 6.95% | 145 | Volume driver |
| **North Coast chalets** | 5.56% | 28 | Premium price point |
| **Cairo townhouses** | 3.50% | 38 | Standard |
| **Cairo villas** | 2.80% | 45 | Low margin, high price |

**Strategic implication**: **Giza apartments** generate 8.36% revenue per property — nearly **3× the villa segment**. Even though villas have higher prices, apartments deliver better unit economics.

### Reading the Compound/Developer Analysis

**Sample observation**:

- **Palm Hills** generates 28.5M EGP total revenue across 78 properties
- **SODIC** generates 24.8M EGP across 68 properties
- **Emaar Misr** generates 18.9M EGP across 55 properties

**Average revenue per property**:

- SODIC: 364K EGP
- Palm Hills: 365K EGP
- Emaar Misr: 343K EGP

**Interpretation**: All three developers show similar unit economics — the **exclusive tier** correlates with consistent performance. This validates Nawy's partnership strategy.

**Red flag**: If any tier-1 developer showed **< 200K EGP per property**, it would signal partnership misalignment.

### Red Flags

| Signal | Interpretation | Action |
|--------|----------------|--------|
| Revenue % < 2% for premium developer | Underperformance | Investigate partnership terms |
| Revenue sources = 1 across many properties | Cross-sell failure | Launch cross-sell campaign by property |
| Compound average declining over time | Market shift | Reduce exposure |
| High-price properties with low revenue % | Inefficient monetization | Focus on high-yield segments |

### The "Holy Grail" Property Profile

Based on top performers, the ideal Nawy property has:

- **Price range**: 3–8M EGP (sweet spot)
- **Type**: 2-3BR apartment or small townhouse
- **Location**: Cairo or Giza, tier-1 compound
- **Developer**: Exclusive or premium tier
- **Characteristics**: Semi-finished (allows Nawy Unlocked finishing revenue), off-plan (allows Shares + mortgage)

**If Nawy acquires 100 properties matching this profile**, expected revenue:

- Commission: 100 × 5.5M × 2.5% = 13.75M EGP
- Mortgage: 100 × 4.7M × 15% = 70.5M EGP
- Shares: 100 × 5.5M × 3% = 16.5M EGP
- Management: 100 × 55K × 2 years = 11M EGP
- Finishing: 100 × 300K × 50% = 15M EGP
- **Total: ~127M EGP across 5 years**

Compare to traditional commission-only model: **13.75M EGP**. That's a **9× revenue multiplier**.

---

## 💡 Analytical Extensions

### Extension 1 — Revenue Sources Distribution

How many properties engage each revenue source?

```sql
SELECT
    SUM(CASE WHEN commission_revenue > 0 THEN 1 ELSE 0 END) AS with_commission,
    SUM(CASE WHEN mortgage_revenue > 0 THEN 1 ELSE 0 END) AS with_mortgage,
    SUM(CASE WHEN shares_revenue > 0 THEN 1 ELSE 0 END) AS with_shares,
    SUM(CASE WHEN management_revenue > 0 THEN 1 ELSE 0 END) AS with_management,
    SUM(CASE WHEN finishing_revenue > 0 THEN 1 ELSE 0 END) AS with_finishing
FROM property_revenue;
```

**Expected insight**: Only ~5% of properties engage all 5 revenue sources. Huge opportunity to increase.

### Extension 2 — Time to Full Monetization

Measure how long it takes a property to activate each revenue source:

```sql
-- Compare property.created_at with first deal, first mortgage, etc.
```

**Expected insight**: Properties that activate 3+ sources within 12 months deliver **2× lifetime revenue**.

### Extension 3 — Developer Revenue Rank

Rank developers by revenue per property (not total):

```sql
AVG(total_revenue) AS avg_revenue_per_property
```

**Expected insight**: Boutique developers sometimes outperform larger ones on unit economics.

### Extension 4 — Compound Deep-Dive

Filter to top 5 compounds and drill into property types:

```sql
WHERE compound_name IN ('Villette', 'Badya', 'Marassi', 'Hyde Park', 'Swan Lake')
```

**Expected insight**: Some compounds are specialized (villas only, chalets only).

### Extension 5 — Correlation with Developer Tier

```sql
SELECT
    developer_tier,
    AVG(total_revenue) AS avg_revenue,
    AVG(revenue_pct_of_price) AS avg_pct
GROUP BY developer_tier
```

**Expected insight**: Exclusive-tier developers show **1.5× higher revenue per property** than standard tier. Validates tier system.

### Extension 6 — Visualize in Tableau

1. Connect Tableau to `NawyProptechDB`
2. Use the query as a **Custom SQL** data source
3. Build asset management dashboard:
   - **Pareto chart**: Top 20% of properties → % of revenue
   - **Treemap**: Revenue by compound
   - **Scatter plot**: `listing_price` (x) vs `revenue_pct_of_price` (y)
   - **Bar chart**: Revenue by source, stacked
   - **Map**: Properties colored by performance tier

---

## ⚡ Performance Notes

### Query Runtime

- **Expected**: 1,000–1,800 ms on 520 properties
- **Scales to**: 8–15 seconds at 10K properties

### Why This Query Is Slower

Five correlated subqueries per property means **520 × 5 = 2,600 subquery executions**. Each scans its target table.

### Optimization Tips

**1. Materialize property revenue**

```sql
CREATE TABLE nawy.mv_property_revenue AS
SELECT ... -- CTE logic
```

Refresh nightly. All three parts query this materialized view.

**2. Add covering indexes**

```sql
CREATE INDEX IX_DEAL_property_status ON nawy.DEAL(property_id, status);
CREATE INDEX IX_MORTGAGE_property_status ON nawy.MORTGAGE_APPLICATION(property_id, status);
CREATE INDEX IX_SHARE_OFFERING_property ON nawy.SHARE_OFFERING(property_id);
CREATE INDEX IX_MGMT_CONTRACT_property ON nawy.MANAGEMENT_CONTRACT(property_id);
```

**3. Pre-compute top properties**

For real-time dashboards, cache the top 100 properties.
