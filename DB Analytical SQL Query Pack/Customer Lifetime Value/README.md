# Query 6 — Customer Lifetime Value

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

> **What is the total revenue each user generates across all Nawy business lines, and who are the highest-value customers?**

---

## 💼 Business Context

### Why This Matters to Nawy

Nawy operates **five complementary business lines** (Properties, Partners, Now, Shares, Unlocked). A user can engage with any combination of them over their lifetime. Understanding **Customer Lifetime Value (CLV)** enables:

1. **VIP Identification** — Top 5% of users often generate 40–60% of revenue
2. **Marketing ROI** — Compare acquisition cost vs. lifetime value per segment
3. **Cross-Sell Strategy** — Target single-line users with high CLV potential
4. **Retention Investment** — Justify account managers for high-CLV segments
5. **Investor Story** — CLV growth demonstrates platform stickiness

### Revenue Streams Modeled

| Business Line | Revenue Component | Formula |
|---------------|-------------------|---------|
| **Nawy Partners** | Broker commission (as buyer) | `commission_amount` where buyer pays |
| **Nawy Now** | Mortgage interest | `loan_amount × interest_rate` |
| **Nawy Shares** | Exit fee revenue | `total_sale_value × exit_fee_percent` |
| **Nawy Unlocked** | Management fees | `rent_paid × management_fee_percent` |
| **Properties** | Listing fees (implicit) | Not modeled — free to list |

### Who Uses This Query

| Role | Purpose |
|------|---------|
| **Growth Team** | Segment users by CLV for targeted campaigns |
| **VIP Relations** | Identify top-tier users for white-glove service |
| **Investor Relations** | Demonstrate revenue per user to investors |
| **Marketing** | Allocate acquisition budget by expected CLV |
| **Product** | Prioritize features for high-CLV segments |

### What "Good" Looks Like

| CLV Tier | Total Revenue | Population Share | Revenue Share |
|----------|---------------|------------------|---------------|
| **VIP** | > 1,000,000 EGP | ~2% | ~40% |
| **High Value** | 100K–1M EGP | ~8% | ~35% |
| **Standard** | 10K–100K EGP | ~25% | ~20% |
| **Low Value** | < 10K EGP | ~65% | ~5% |

**Pareto principle check**: If top 10% of users generate less than 70% of revenue, cross-sell programs need improvement.

---

## 🔍 The Query

```sql
-- ============================================================
-- Query 6: Customer Lifetime Value (CLV)
-- ============================================================
-- Business Question:
--   What is the total revenue each user generates across all
--   Nawy business lines, and who are the highest-value
--   customers?
--
-- Used By:
--   - Growth team (segment users by CLV)
--   - VIP relations (identify top-tier users)
--   - Investor relations (revenue per user)
--   - Marketing (acquisition budget allocation)
--
-- Output:
--   Part 1: Per-user revenue across all business lines
--   Part 2: Summary by CLV tier
--
-- Author: <Your Name>
-- Date:   <Date>
-- ============================================================

USE NawyProptechDB;
GO

-- ============================================================
-- PART 1: PER-USER REVENUE BREAKDOWN
-- ============================================================
-- For each user, we compute revenue from four business lines:
--
-- 1. Nawy Partners:
--    Commission earned by the platform when the user buys
--    through a broker. Approximated by commission_amount
--    on completed deals where the user was the buyer.
--
-- 2. Nawy Now:
--    Interest revenue over the loan term. Approximation:
--    loan_amount × interest_rate (single year).
--
-- 3. Nawy Shares:
--    Exit fee revenue when the user exits an investment.
--    Formula: total_sale_value × exit_fee_percent.
--
-- 4. Nawy Unlocked:
--    Management fee revenue from rentals. Formula:
--    rent_paid × management_fee_percent, where user is the
--    property owner.
-- ============================================================

WITH user_revenue AS (
    SELECT
        u.user_id,
        u.full_name,
        u.email,
        u.user_type,
        u.created_at,
        DATEDIFF(DAY, u.created_at, SYSDATETIMEOFFSET()) AS lifetime_days,

        -- Revenue stream 1: Nawy Partners (commission from deals as buyer)
        ISNULL((
            SELECT SUM(c.commission_amount)
            FROM nawy.COMMISSION c
            INNER JOIN nawy.DEAL d
                ON c.deal_id = d.deal_id
            WHERE d.buyer_user_id = u.user_id
              AND c.status = 'paid'
        ), 0) AS partner_revenue,

        -- Revenue stream 2: Nawy Now (mortgage interest)
        ISNULL((
            SELECT SUM(ma.loan_amount * ISNULL(ma.interest_rate, 0))
            FROM nawy.MORTGAGE_APPLICATION ma
            WHERE ma.user_id = u.user_id
              AND ma.status = 'disbursed'
        ), 0) AS now_revenue,

        -- Revenue stream 3: Nawy Shares (exit fee)
        ISNULL((
            SELECT SUM(se.total_sale_value * se.exit_fee_percent)
            FROM nawy.SHARE_EXIT se
            INNER JOIN nawy.SHARE_INVESTMENT si
                ON se.investment_id = si.investment_id
            WHERE si.user_id = u.user_id
              AND se.status = 'completed'
        ), 0) AS shares_revenue,

        -- Revenue stream 4: Nawy Unlocked (management fees)
        ISNULL((
            SELECT SUM(rp.amount * mc.management_fee_percent)
            FROM nawy.RENT_PAYMENT rp
            INNER JOIN nawy.LEASE l
                ON rp.lease_id = l.lease_id
            INNER JOIN nawy.MANAGEMENT_CONTRACT mc
                ON l.contract_id = mc.contract_id
            WHERE mc.owner_user_id = u.user_id
              AND rp.status = 'paid'
        ), 0) AS unlocked_revenue

    FROM nawy.[USER] u
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            (partner_revenue + now_revenue + shares_revenue + unlocked_revenue) DESC
    ) AS rank,
    user_id,
    full_name,
    email,
    user_type,
    lifetime_days,
    CAST(partner_revenue AS DECIMAL(18,2))      AS partner_revenue_egp,
    CAST(now_revenue AS DECIMAL(18,2))          AS now_revenue_egp,
    CAST(shares_revenue AS DECIMAL(18,2))       AS shares_revenue_egp,
    CAST(unlocked_revenue AS DECIMAL(18,2))     AS unlocked_revenue_egp,
    CAST(
        (partner_revenue + now_revenue + shares_revenue + unlocked_revenue)
        AS DECIMAL(18,2)
    ) AS total_clv_egp,

    -- Number of business lines engaged
    (
        CASE WHEN partner_revenue > 0 THEN 1 ELSE 0 END +
        CASE WHEN now_revenue > 0 THEN 1 ELSE 0 END +
        CASE WHEN shares_revenue > 0 THEN 1 ELSE 0 END +
        CASE WHEN unlocked_revenue > 0 THEN 1 ELSE 0 END
    ) AS business_lines_engaged,

    -- CLV tier
    CASE
        WHEN (partner_revenue + now_revenue + shares_revenue + unlocked_revenue) >= 1000000
            THEN 'VIP'
        WHEN (partner_revenue + now_revenue + shares_revenue + unlocked_revenue) >= 100000
            THEN 'High Value'
        WHEN (partner_revenue + now_revenue + shares_revenue + unlocked_revenue) >= 10000
            THEN 'Standard'
        ELSE 'Low Value'
    END AS clv_tier

FROM user_revenue
WHERE (partner_revenue + now_revenue + shares_revenue + unlocked_revenue) > 0
ORDER BY total_clv_egp DESC;

-- ============================================================
-- PART 2: SUMMARY BY CLV TIER
-- ============================================================
-- Rolls up per-user CLV into segment-level statistics to
-- support strategic decisions on retention and acquisition.
-- ============================================================

WITH user_clv AS (
    SELECT
        u.user_id,
        ISNULL((
            SELECT SUM(c.commission_amount)
            FROM nawy.COMMISSION c
            INNER JOIN nawy.DEAL d ON c.deal_id = d.deal_id
            WHERE d.buyer_user_id = u.user_id AND c.status = 'paid'
        ), 0)
        + ISNULL((
            SELECT SUM(ma.loan_amount * ISNULL(ma.interest_rate, 0))
            FROM nawy.MORTGAGE_APPLICATION ma
            WHERE ma.user_id = u.user_id AND ma.status = 'disbursed'
        ), 0)
        + ISNULL((
            SELECT SUM(se.total_sale_value * se.exit_fee_percent)
            FROM nawy.SHARE_EXIT se
            INNER JOIN nawy.SHARE_INVESTMENT si ON se.investment_id = si.investment_id
            WHERE si.user_id = u.user_id AND se.status = 'completed'
        ), 0)
        + ISNULL((
            SELECT SUM(rp.amount * mc.management_fee_percent)
            FROM nawy.RENT_PAYMENT rp
            INNER JOIN nawy.LEASE l ON rp.lease_id = l.lease_id
            INNER JOIN nawy.MANAGEMENT_CONTRACT mc ON l.contract_id = mc.contract_id
            WHERE mc.owner_user_id = u.user_id AND rp.status = 'paid'
        ), 0) AS total_clv
    FROM nawy.[USER] u
)
SELECT
    CASE
        WHEN total_clv >= 1000000 THEN 'VIP'
        WHEN total_clv >= 100000  THEN 'High Value'
        WHEN total_clv >= 10000   THEN 'Standard'
        WHEN total_clv > 0        THEN 'Low Value'
        ELSE 'No Revenue'
    END AS clv_tier,
    COUNT(*)                                    AS user_count,
    CAST(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)
    ) AS population_pct,
    CAST(SUM(total_clv) AS DECIMAL(18,2))       AS total_revenue_egp,
    CAST(
        100.0 * SUM(total_clv) / NULLIF(SUM(SUM(total_clv)) OVER (), 0) AS DECIMAL(10,2)
    ) AS revenue_share_pct,
    CAST(AVG(total_clv) AS DECIMAL(18,2))       AS avg_clv_egp,
    CAST(MIN(total_clv) AS DECIMAL(18,2))       AS min_clv_egp,
    CAST(MAX(total_clv) AS DECIMAL(18,2))       AS max_clv_egp
FROM user_clv
GROUP BY
    CASE
        WHEN total_clv >= 1000000 THEN 'VIP'
        WHEN total_clv >= 100000  THEN 'High Value'
        WHEN total_clv >= 10000   THEN 'Standard'
        WHEN total_clv > 0        THEN 'Low Value'
        ELSE 'No Revenue'
    END
ORDER BY
    CASE
        WHEN total_clv >= 1000000 THEN 1
        WHEN total_clv >= 100000  THEN 2
        WHEN total_clv >= 10000   THEN 3
        WHEN total_clv > 0        THEN 4
        ELSE 5
    END;
GO
```

---

## 🔬 Code Walkthrough

### Section 1 — CTE: `user_revenue`

**Purpose**: Compute revenue from four different business lines per user.

**Key technique — Correlated subqueries**:

Instead of `LEFT JOIN` + `GROUP BY` (which can double-count), we use **scalar subqueries** in the SELECT list. Each subquery:

- Filters by `user_id = u.user_id`
- Aggregates revenue for that single user
- Returns one scalar value per row

**Why correlated subqueries instead of JOINs?**

Because each business line has a different grain:

- Nawy Partners: one row per commission (many per user)
- Nawy Now: one row per mortgage (many per user)
- Nawy Shares: one row per exit (many per user)
- Nawy Unlocked: one row per rent payment (many per user)

Joining all four would create a **Cartesian explosion**. Subqueries isolate the aggregation cleanly.

**Why `ISNULL(..., 0)`?**

A user with no mortgages should contribute 0, not NULL — otherwise the sum becomes NULL.

---

### Section 2 — Revenue Formulas Explained

#### Nawy Partners revenue

```sql
SELECT SUM(c.commission_amount)
FROM nawy.COMMISSION c
INNER JOIN nawy.DEAL d ON c.deal_id = d.deal_id
WHERE d.buyer_user_id = u.user_id
  AND c.status = 'paid'
```

**What this means**: When the user buys a property through a Nawy broker, the platform earns a commission (typically 2.5%). We sum those commissions.

**Business caveat**: The commission is paid by the buyer (or seller, depending on the deal). This query treats it as revenue attributable to the buyer.

---

#### Nawy Now revenue

```sql
SELECT SUM(ma.loan_amount * ISNULL(ma.interest_rate, 0))
FROM nawy.MORTGAGE_APPLICATION ma
WHERE ma.user_id = u.user_id
  AND ma.status = 'disbursed'
```

**What this means**: Nawy Now earns interest on the loan. Because payments are spread over 3–10 years, we approximate **first-year interest** as `loan_amount × rate`.

**Business caveat**: This is a simplification. In reality, revenue accrues over the loan term. For CLV purposes, this approximation is sufficient.

---

#### Nawy Shares revenue

```sql
SELECT SUM(se.total_sale_value * se.exit_fee_percent)
FROM nawy.SHARE_EXIT se
INNER JOIN nawy.SHARE_INVESTMENT si ON se.investment_id = si.investment_id
WHERE si.user_id = u.user_id
  AND se.status = 'completed'
```

**What this means**: When an investor exits their fractional shares, Nawy takes a fee (2.5–5% of resale value). This is Nawy's revenue for facilitating the exit.

---

#### Nawy Unlocked revenue

```sql
SELECT SUM(rp.amount * mc.management_fee_percent)
FROM nawy.RENT_PAYMENT rp
INNER JOIN nawy.LEASE l ON rp.lease_id = l.lease_id
INNER JOIN nawy.MANAGEMENT_CONTRACT mc ON l.contract_id = mc.contract_id
WHERE mc.owner_user_id = u.user_id
  AND rp.status = 'paid'
```

**What this means**: When a property owner's tenant pays rent, Nawy keeps a management fee (typically 10%). We sum fees across all rental payments.

---

### Section 3 — CLV Tiers

```sql
CASE
    WHEN total_clv >= 1000000 THEN 'VIP'
    WHEN total_clv >= 100000  THEN 'High Value'
    WHEN total_clv >= 10000   THEN 'Standard'
    ELSE 'Low Value'
END
```

**Thresholds rationale**:

| Tier | Threshold | Revenue Share | Population |
|------|-----------|---------------|------------|
| **VIP** | > 1M EGP | 40%+ | ~2% |
| **High Value** | 100K–1M EGP | 35% | ~8% |
| **Standard** | 10K–100K EGP | 20% | ~25% |
| **Low Value** | < 10K EGP | 5% | ~65% |

If the actual distribution deviates significantly, adjust thresholds or investigate the segments.

---

### Section 4 — Part 2: Summary by Tier

**Purpose**: Report segment-level statistics to support board-level decisions.

**Key technique**: We repeat the CLV calculation in a CTE, then aggregate by tier in the outer query.

**Why duplicate the calculation?**

Because SQL Server doesn't allow referencing a computed alias in a `GROUP BY` clause. The CTE isolates the computation from the aggregation.

**Window function**: `SUM(COUNT(*)) OVER ()` computes the total user count while keeping the aggregation by tier.

---

## 📊 Expected Output

### Part 1 — Sample Result Set (Per-User)

| rank | user_id | full_name | user_type | lifetime_days | partner_revenue_egp | now_revenue_egp | shares_revenue_egp | unlocked_revenue_egp | total_clv_egp | business_lines_engaged | clv_tier |
|------|---------|-----------|-----------|---------------|---------------------|-----------------|---------------------|----------------------|----------------|------------------------|----------|
| 1 | 12 | Khaled Mansour | investor | 1,432 | 485,000.00 | 1,320,000.00 | 285,000.00 | 145,000.00 | 2,235,000.00 | 4 | VIP |
| 2 | 17 | Amr Ashraf | investor | 1,205 | 220,000.00 | 980,000.00 | 420,000.00 | 0.00 | 1,620,000.00 | 3 | VIP |
| 3 | 8 | Laila Mahmoud | investor | 1,876 | 350,000.00 | 720,000.00 | 310,000.00 | 82,000.00 | 1,462,000.00 | 4 | VIP |
| 4 | 22 | Nada Hossam | investor | 1,320 | 180,000.00 | 1,100,000.00 | 95,000.00 | 0.00 | 1,375,000.00 | 3 | VIP |
| 5 | 27 | Sameh Fathi | investor | 1,145 | 240,000.00 | 850,000.00 | 180,000.00 | 65,000.00 | 1,335,000.00 | 4 | VIP |
| 6 | 36 | Passant Nabil | investor | 968 | 320,000.00 | 0.00 | 465,000.00 | 108,000.00 | 893,000.00 | 3 | High Value |
| 7 | 40 | Jana Mohamed | investor | 855 | 180,000.00 | 620,000.00 | 45,000.00 | 0.00 | 845,000.00 | 3 | High Value |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Part 2 — Sample Result Set (Summary)

| clv_tier | user_count | population_pct | total_revenue_egp | revenue_share_pct | avg_clv_egp | min_clv_egp | max_clv_egp |
|----------|------------|----------------|--------------------|--------------------|-------------|-------------|-------------|
| VIP | 5 | 1.56 | 8,027,000.00 | 24.82 | 1,605,400.00 | 1,335,000.00 | 2,235,000.00 |
| High Value | 32 | 10.00 | 12,850,000.00 | 39.72 | 401,562.50 | 105,000.00 | 980,000.00 |
| Standard | 78 | 24.38 | 8,240,000.00 | 25.47 | 105,641.03 | 12,500.00 | 98,500.00 |
| Low Value | 145 | 45.31 | 3,230,000.00 | 9.99 | 22,275.86 | 500.00 | 9,800.00 |
| No Revenue | 60 | 18.75 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `rank` | INT | User ranking by CLV |
| `user_id` | BIGINT | Unique user identifier |
| `full_name` | NVARCHAR | User's full name |
| `email` | NVARCHAR | User's email |
| `user_type` | NVARCHAR | buyer, seller, investor, broker, admin |
| `lifetime_days` | INT | Days since registration |
| `partner_revenue_egp` | DECIMAL | Commission revenue from deals |
| `now_revenue_egp` | DECIMAL | Mortgage interest revenue |
| `shares_revenue_egp` | DECIMAL | Nawy Shares exit fee revenue |
| `unlocked_revenue_egp` | DECIMAL | Management fee revenue |
| `total_clv_egp` | DECIMAL | Sum of all revenue |
| `business_lines_engaged` | INT | Count of active business lines |
| `clv_tier` | NVARCHAR | VIP / High Value / Standard / Low Value |
| `population_pct` | DECIMAL | % of total users in tier |
| `revenue_share_pct` | DECIMAL | % of total revenue from tier |

---

## 📈 Interpretation Guide

### Reading Part 1 — Top Users

**Sample observation**: User #12 (Khaled Mansour, investor):

- Engages with **4 business lines**
- Total CLV: **2.235M EGP**
- Tier: **VIP**

**What this tells us**:

- He's invested in mortgages, fractional shares, and owns managed property
- He's the platform's ideal customer profile
- **Action**: Assign dedicated account manager; invite to investor round-tables

**Sample observation**: User #36 (Passant Nabil):

- Has bought through broker (320K commission)
- NO mortgages
- Big fractional investor (465K in exit fees)
- Owns managed property (108K in mgmt fees)
- **Total CLV: 893K EGP**
- Tier: **High Value (borderline VIP)**

**What this tells us**:

- She's avoided mortgages but is heavily invested in fractional shares
- **Cross-sell opportunity**: Nawy Now mortgage for her next property purchase
- **Action**: Target her with Nawy Now marketing

### Reading Part 2 — Segment Summary

**Sample observation**:

- **VIP tier**: 5 users (1.56%) → **24.82% of revenue**
- **High Value tier**: 32 users (10%) → **39.72% of revenue**
- Combined: 11.56% of users → **64.54% of revenue**

**Interpretation**: Pareto principle holds — approximately 12% of users generate 65% of revenue. Healthy for a platform of Nawy's maturity.

**Red flag to watch**: If VIP + High Value revenue share drops below 55%, it means high-value users are churning or the platform is diluting CLV.

### Key Ratios

| Metric | Value | Interpretation |
|--------|-------|----------------|
| **VIP avg CLV** | 1.61M EGP | Average high-value relationship |
| **High Value avg CLV** | 401K EGP | 4× the Standard avg |
| **Standard avg CLV** | 106K EGP | Healthy mid-market |
| **Low Value avg CLV** | 22K EGP | Transactional users |
| **VIP / Low Value ratio** | 72× | Huge value gap |
| **Multi-line users** | ~40% | Reasonable cross-sell |

### Strategic Recommendations

1. **Protect VIPs aggressively** — Losing 5 VIPs = losing 25% of revenue
2. **Upsell High Value → VIP** — Focus on users at 500K–1M EGP
3. **Cross-sell Standard tier** — Most have 1 line; convert to 2
4. **Re-engage "No Revenue"** — 60 users with zero revenue need activation
5. **Retain High Value with Nawy Unlocked** — Property management is the highest-retention product

### Red Flags

| Signal | Interpretation | Action |
|--------|----------------|--------|
| VIP population > 5% | Tier thresholds too low | Tighten to 2M EGP |
| Low Value avg CLV < 5K | Acquisition targeting wrong users | Refine ICP |
| Multi-line users < 20% | Cross-sell failing | Review product-market fit |
| No Revenue > 30% | Onboarding problem | Improve activation |
| Top 1 user > 10% of revenue | Concentration risk | Diversify VIP tier |

---

## 💡 Analytical Extensions

### Extension 1 — CLV by User Type

Group by `user_type` to identify which persona generates highest CLV:

```sql
SELECT
    user_type,
    COUNT(*) AS user_count,
    AVG(total_clv) AS avg_clv,
    SUM(total_clv) AS total_revenue
FROM user_revenue
GROUP BY user_type;
```

**Expected insight**: Investors show 3–5× the CLV of buyers.

### Extension 2 — CLV by Acquisition Cohort

Add registration year:

```sql
YEAR(created_at) AS cohort_year
```

**Expected insight**: Older cohorts have higher CLV (more time to compound engagement). Compare CLV curves to detect acquisition quality.

### Extension 3 — CLV vs. Engagement

Correlate CLV with business lines engaged:

```sql
business_lines_engaged,
AVG(total_clv) AS avg_clv
```

**Expected insight**: Each additional business line adds ~80–150K EGP to average CLV. Reinforces cross-sell value.

### Extension 4 — CLV Decay Analysis

For users who haven't engaged in 12+ months:

```sql
-- Add last_activity_date and compute recency
-- Compare historical CLV vs. current engagement
```

**Expected insight**: Dormant VIPs represent a large revenue-recovery opportunity.

### Extension 5 — CLV Payback Period

Calculate months to recover acquisition cost:

```sql
-- If CAC is known, CLV / (CLV / lifetime_months) = months to payback
```

**Expected insight**: VIP-tier users pay back CAC in < 3 months.

### Extension 6 — Visualize in Tableau

1. Connect Tableau to `NawyProptechDB`
2. Use the query as a **Custom SQL** data source
3. Build:
   - **Pareto chart**: Cumulative % of revenue vs. % of users
   - **Stacked bar**: CLV tier × business line
   - **Scatter plot**: `lifetime_days` (x) vs `total_clv_egp` (y)
   - **KPI tiles**: VIP count, total revenue, avg CLV
   - **Treemap**: Revenue by user segment

---

## ⚡ Performance Notes

### Query Runtime

- **Expected**: 800–1,500 ms on 320 users
- **Scales to**: 8–15 seconds at 10K users without optimization

### Why This Query Is Slower

Four correlated subqueries per user means **320 × 4 = 1,280 subquery executions**. Each scans its target table.

### Optimization Tips

**1. Materialize intermediate results**

```sql
CREATE TABLE nawy.mv_user_revenue AS
WITH user_revenue AS (...)
SELECT * FROM user_revenue;
```

Refresh nightly. Query the materialized view instead.

**2. Add covering indexes**

```sql
CREATE INDEX IX_DEAL_buyer_status ON nawy.DEAL(buyer_user_id, status);
CREATE INDEX IX_MORTGAGE_user_status ON nawy.MORTGAGE_APPLICATION(user_id, status);
CREATE INDEX IX_SHARE_INVESTMENT_user ON nawy.SHARE_INVESTMENT(user_id);
CREATE INDEX IX_MGMT_owner ON nawy.MANAGEMENT_CONTRACT(owner_user_id);
CREATE INDEX IX_COMMISSION_status ON nawy.COMMISSION(deal_id, status);
```

**3. Rewrite as JOINs + aggregates**

Instead of four subqueries, use four CTEs and join them:

```sql
WITH partner AS (SELECT buyer_user_id AS user_id, SUM(...) AS rev FROM ... GROUP BY buyer_user_id),
     now AS (...),
     shares AS (...),
     unlocked AS (...)
SELECT u.*, ISNULL(p.rev,0)+ISNULL(n.rev,0)+... AS total
FROM nawy.[USER] u
LEFT JOIN partner p ON u.user_id = p.user_id
LEFT JOIN now n ON u.user_id = n.user_id
...
```

This trades readability for a **3–5× speedup**.

**4. Batch processing for very large datasets**

If user count > 1M, split into chunks of 100K users and process in parallel.
