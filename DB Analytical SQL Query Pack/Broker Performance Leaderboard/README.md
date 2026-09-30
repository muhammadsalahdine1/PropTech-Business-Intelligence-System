# Query 2 — Broker Performance Leaderboard

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

> **Which brokers are the top performers on Nawy Partners, and what distinguishes them from the rest?**

---

## 💼 Business Context

### Why This Matters to Nawy

Nawy Partners pays approximately **2.5% commission** to the 45 active MSME brokers on its platform. With over **3,000 brokerages** registered and only a fraction actively closing deals, identifying and retaining top performers is critical for:

1. **Revenue Growth** — Top 20% of brokers often generate 80% of GMV (Pareto principle).
2. **Inventory Allocation** — High-performing brokers deserve access to exclusive developer inventory.
3. **Training & Enablement** — Understanding what top performers do differently lets Nawy replicate winning behaviors.
4. **Compensation Strategy** — Commission tiers, bonuses, and incentives should reward the right behaviors.

### Who Uses This Query

| Role | Purpose |
|------|---------|
| **Nawy Partners Team** | Rank brokers, allocate inventory, and set quotas |
| **Executive Team** | Track platform-wide sales productivity |
| **Broker Enablement** | Identify training opportunities |
| **Finance** | Forecast commission payouts and cash flow |

### What "Good" Looks Like

| Metric | Benchmark | Elite |
|--------|-----------|-------|
| **Lead Conversion Rate** | 10–15% | > 20% |
| **Average Deal Size** | 3–5M EGP | > 8M EGP |
| **Deals per Month** | 1–2 | 4+ |
| **Commission per Broker** | 500K EGP/year | > 1M EGP/year |

### The Broker Economy on Nawy

Nawy Partners operates as a **B2B marketplace for brokers**, offering:

- Access to exclusive inventory from **150+ developers**
- Fast commission payouts (typically 15–30 days vs. industry 90+ days)
- Team management tools for agency brokers
- Lead flow from Nawy's 1M+ monthly users

Understanding broker performance directly impacts Nawy's ability to grow this side of the business.

---

## 🔍 The Query

```sql
-- Query 2: Broker Performance Leaderboard
-- Business Question:
--   Which brokers are the top performers on Nawy Partners,
--   and what distinguishes them from the rest?
--
-- Used By:
--   - Nawy Partners team (inventory allocation, quotas)
--   - Executive team (platform sales productivity)
--   - Broker enablement (training opportunities)
--   - Finance (commission forecasting)
--
-- Output:
--   Ranked broker list with KPIs, conversion rates, and
--   performance tier classification.
--

USE NawyProptechDB;
GO

-- STEP 1: Aggregate broker KPIs
-- For each active broker, we compute:
--   - Lead metrics (total, won, lost)
--   - Deal metrics (count, GMV, average size)
--   - Commission metrics (earned, paid, pending)
--   - Tenure on platform
--
-- We use LEFT JOINs because not all brokers have leads/deals
-- (new brokers may have zero activity yet).

WITH broker_kpis AS (
    SELECT
        b.broker_id,
        u.full_name                             AS broker_name,
        u.email,
        b.broker_type,
        b.agency_name,
        b.team_size,
        b.joined_at,
        DATEDIFF(DAY, b.joined_at, SYSDATETIMEOFFSET()) AS days_on_platform,

        -- Lead metrics
        COUNT(DISTINCT l.lead_id)               AS total_leads,
        COUNT(DISTINCT CASE WHEN l.status = 'closed_won'
                            THEN l.lead_id END) AS won_leads,
        COUNT(DISTINCT CASE WHEN l.status = 'closed_lost'
                            THEN l.lead_id END) AS lost_leads,

        -- Deal metrics
        COUNT(DISTINCT d.deal_id)               AS total_deals,
        ISNULL(SUM(d.sale_price), 0)            AS total_gmv,
        ISNULL(AVG(d.sale_price), 0)            AS avg_deal_size,

        -- Commission metrics
        ISNULL(SUM(c.commission_amount), 0)     AS total_commission_earned,
        ISNULL(SUM(CASE WHEN c.status = 'paid'
                        THEN c.commission_amount ELSE 0 END), 0) AS commission_paid,
        ISNULL(SUM(CASE WHEN c.status = 'pending'
                        THEN c.commission_amount ELSE 0 END), 0) AS commission_pending

    FROM nawy.BROKER b
    INNER JOIN nawy.[USER] u
        ON b.user_id = u.user_id
    LEFT JOIN nawy.LEAD l
        ON b.broker_id = l.broker_id
    LEFT JOIN nawy.DEAL d
        ON b.broker_id = d.broker_id
       AND d.status = 'completed'
    LEFT JOIN nawy.COMMISSION c
        ON b.broker_id = c.broker_id
    WHERE b.status = 'active'
    GROUP BY
        b.broker_id,
        u.full_name,
        u.email,
        b.broker_type,
        b.agency_name,
        b.team_size,
        b.joined_at
)

-- STEP 2: Rank brokers and classify performance tier
-- ROW_NUMBER() assigns a rank based on total commission.
-- CASE statement classifies each broker into a tier:
--   Platinum: > 1,000,000 EGP commission
--   Gold:     > 500,000 EGP
--   Silver:   > 100,000 EGP
--   Bronze:   > 10,000 EGP
--   Rising:   < 10,000 EGP

SELECT
    ROW_NUMBER() OVER (ORDER BY total_commission_earned DESC) AS rank,
    broker_id,
    broker_name,
    broker_type,
    agency_name,
    team_size,
    days_on_platform,
    total_leads,
    won_leads,
    lost_leads,
    total_deals,
    CAST(total_gmv AS DECIMAL(15,2))            AS total_gmv_egp,
    CAST(avg_deal_size AS DECIMAL(15,2))        AS avg_deal_size_egp,
    CAST(total_commission_earned AS DECIMAL(12,2)) AS total_commission_egp,
    CAST(commission_paid AS DECIMAL(12,2))      AS commission_paid_egp,
    CAST(commission_pending AS DECIMAL(12,2))   AS commission_pending_egp,

    -- Lead conversion rate
    CAST(
        CASE WHEN total_leads = 0 THEN 0
             ELSE 100.0 * won_leads / total_leads
        END AS DECIMAL(5,2)
    ) AS lead_conversion_pct,

    -- Performance tier
    CASE
        WHEN total_commission_earned >= 1000000 THEN 'Platinum'
        WHEN total_commission_earned >= 500000  THEN 'Gold'
        WHEN total_commission_earned >= 100000  THEN 'Silver'
        WHEN total_commission_earned >= 10000   THEN 'Bronze'
        ELSE 'Rising'
    END AS performance_tier

FROM broker_kpis
ORDER BY total_commission_earned DESC;
```

---

## 🔬 Code Walkthrough

### Section 1 — CTE: `broker_kpis`

**Purpose**: Compute all broker performance metrics in a single aggregation.

**Key techniques**:

| Technique | Purpose |
|-----------|---------|
| `INNER JOIN` to `USER` | Filter out orphan brokers (data integrity) |
| `LEFT JOIN` to `LEAD/DEAL/COMMISSION` | Include brokers with no activity yet |
| `COUNT(DISTINCT ...)` | Prevents double-counting when multiple joins fan out |
| `CASE WHEN ... THEN 1 ELSE 0 END` inside `SUM` | Conditional aggregation |
| `ISNULL(..., 0)` | Replaces NULL with 0 for numeric outputs |
| `d.status = 'completed'` in JOIN clause | Only completed deals count toward GMV |

**Why `DISTINCT` in `COUNT`?**

When we join a broker to both leads and deals, a single lead may appear multiple times if it has multiple deals. `COUNT(DISTINCT l.lead_id)` ensures each unique lead is counted once.

**Why LEFT JOIN?**

A brand-new broker with zero leads still deserves a row in the output. LEFT JOIN keeps them with NULL→0 metrics.

---

### Section 2 — Ranking & Classification

**Purpose**: Add rank and performance tier to each broker.

**Key techniques**:

| Technique | Purpose |
|-----------|---------|
| `ROW_NUMBER() OVER (ORDER BY ...)` | Assigns a unique rank |
| `CASE` with threshold values | Classifies each broker into a tier |
| `CAST(... AS DECIMAL)` | Ensures clean numeric formatting |

**Why `ROW_NUMBER()` instead of `RANK()`?**

`ROW_NUMBER()` always produces unique sequential integers (1, 2, 3, 4...), even when two brokers tie. `RANK()` would skip numbers after a tie (1, 2, 2, 4...). For a leaderboard, unique ranks are usually preferred.

---

## 📊 Expected Output

### Sample Result Set

| rank | broker_name | broker_type | agency_name | team_size | total_leads | won_leads | total_deals | total_gmv_egp | avg_deal_size_egp | total_commission_egp | lead_conversion_pct | performance_tier |
|------|-------------|-------------|-------------|-----------|-------------|-----------|-------------|---------------|-------------------|----------------------|---------------------|------------------|
| 1 | Tarek Hussein | agency | Elite Real Estate | 5 | 87 | 22 | 22 | 148,500,000.00 | 6,750,000.00 | 3,712,500.00 | 25.29 | Platinum |
| 2 | Mahmoud Sherif | agency | Sherif Properties | 8 | 112 | 24 | 24 | 132,000,000.00 | 5,500,000.00 | 3,300,000.00 | 21.43 | Platinum |
| 3 | Mohamed Reda | agency | Reda Realty Group | 12 | 145 | 28 | 28 | 126,000,000.00 | 4,500,000.00 | 3,150,000.00 | 19.31 | Platinum |
| 4 | Tamer Salah | agency | Salah & Partners | 6 | 92 | 16 | 16 | 88,000,000.00 | 5,500,000.00 | 2,420,000.00 | 17.39 | Platinum |
| 5 | Ahmed Zaki | agency | Zaki Estates | 4 | 55 | 11 | 11 | 60,500,000.00 | 5,500,000.00 | 1,512,500.00 | 20.00 | Platinum |
| 6 | Waleed Samir | freelancer | — | 0 | 68 | 9 | 9 | 40,500,000.00 | 4,500,000.00 | 810,000.00 | 13.24 | Gold |
| 7 | Maged Farid | freelancer | — | 0 | 45 | 7 | 7 | 28,000,000.00 | 4,000,000.00 | 560,000.00 | 15.56 | Gold |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `rank` | INT | Position in leaderboard (1 = best) |
| `broker_id` | BIGINT | Unique broker identifier |
| `broker_name` | NVARCHAR | Broker's full name |
| `broker_type` | NVARCHAR | freelancer or agency |
| `agency_name` | NVARCHAR | Agency name (NULL for freelancers) |
| `team_size` | INT | Number of sub-agents |
| `days_on_platform` | INT | Tenure since joining |
| `total_leads` | INT | Total leads handled |
| `won_leads` | INT | Leads with status = closed_won |
| `lost_leads` | INT | Leads with status = closed_lost |
| `total_deals` | INT | Completed deals |
| `total_gmv_egp` | DECIMAL | Total sales value in EGP |
| `avg_deal_size_egp` | DECIMAL | Average deal size in EGP |
| `total_commission_egp` | DECIMAL | Total commission earned |
| `commission_paid_egp` | DECIMAL | Already paid to broker |
| `commission_pending_egp` | DECIMAL | Awaiting payment |
| `lead_conversion_pct` | DECIMAL | won_leads / total_leads × 100 |
| `performance_tier` | NVARCHAR | Platinum / Gold / Silver / Bronze / Rising |

---

## 📈 Interpretation Guide

### Performance Tiers — Actions

| Tier | Commission Threshold | Action |
|------|---------------------|--------|
| **Platinum** | ≥ 1,000,000 EGP | Award exclusive inventory; invite to leadership council; feature in case studies |
| **Gold** | ≥ 500,000 EGP | Priority inventory access; quarterly bonuses |
| **Silver** | ≥ 100,000 EGP | Standard inventory; training on advanced techniques |
| **Bronze** | ≥ 10,000 EGP | Coaching sessions; shadow top performers |
| **Rising** | < 10,000 EGP | Onboarding support; monitor retention |

### Conversion Rate — What It Tells You

| Conversion Rate | Interpretation | Action |
|-----------------|----------------|--------|
| **> 25%** | Elite closer | Study their approach; replicate |
| **20–25%** | Excellent | Standard inventory + recognition |
| **15–20%** | Healthy | Steady performer |
| **10–15%** | Below average | Consider training on lead qualification |
| **< 10%** | Underperforming | Investigate: poor lead quality, low effort, or bad fit |

### Freelancers vs. Agencies

**Observation from sample data**:
- **Agencies** typically have **higher volume** (more leads, more deals) due to team size
- **Freelancers** often have **higher conversion rates** because they personally handle every lead
- **Agencies** earn more total commission; **freelancers** earn more per deal

**Strategic implication**: Nawy should support both models — agencies for scale, freelancers for high-touch sales.

### Red Flags

- **High leads + low conversion** → Broker needs lead qualification training
- **High deals + low commission** → Deals are too small; push for larger transactions
- **High commission pending** → Investigate payout delays (could harm broker satisfaction)
- **Zero activity + long tenure** → Inactive broker; consider deactivation

---

## 💡 Analytical Extensions

### Extension 1 — Broker Cohort Analysis

Group brokers by `joined_year` to see if newer cohorts perform better:

```sql
YEAR(b.joined_at) AS joining_cohort
-- Then GROUP BY to compare cohorts
```

**Expected insight**: Brokers who joined in 2023–2024 (during platform expansion) have steeper learning curves.

### Extension 2 — Geographic Specialization

Add a subquery to identify each broker's top city:

```sql
(SELECT TOP 1 p.city
 FROM nawy.LEAD l
 INNER JOIN nawy.PROPERTY p ON l.property_id = p.property_id
 WHERE l.broker_id = b.broker_id
 GROUP BY p.city
 ORDER BY COUNT(*) DESC) AS top_city
```

**Expected insight**: Top performers often specialize in 1–2 districts (e.g., New Cairo specialist, North Coast specialist).

### Extension 3 — Team Performance (Agencies)

For agency brokers, roll up team member performance:

```sql
-- Join BROKER_TEAM → USER → LEAD → DEAL
-- Aggregate by broker_id (agency owner)
```

**Expected insight**: Some agency teams are top-heavy (owner closes most deals); others have distributed performance.

### Extension 4 — Commission Velocity

Calculate average days from deal closing to commission payment:

```sql
AVG(DATEDIFF(DAY, d.closed_at, c.paid_at)) AS avg_payout_days
```

**Expected insight**: Nawy's "fast payouts" claim — verify it's under 30 days.

### Extension 5 — Visualize in Tableau

1. Connect Tableau to `NawyProptechDB`
2. Use the query as a **Custom SQL** data source
3. Create:
   - **Bar chart**: Top 10 brokers by commission
   - **Scatter plot**: `total_leads` (x) vs `total_commission_egp` (y), colored by `performance_tier`
   - **Treemap**: Commission split by `broker_type`
   - **Highlight table**: Broker × city heatmap (using Extension 2)

---

## ⚡ Performance Notes

### Query Runtime

- **Expected**: 400–800 ms on 45 brokers × ~1,400 leads
- **Scales to**: ~5–8 seconds at 10K brokers with proper indexes

### Relevant Indexes

```sql
CREATE INDEX IX_BROKER_status ON nawy.BROKER(status);
CREATE INDEX IX_LEAD_broker_status ON nawy.LEAD(broker_id, status);
CREATE INDEX IX_DEAL_broker ON nawy.DEAL(broker_id) WHERE broker_id IS NOT NULL;
CREATE INDEX IX_COMMISSION_broker_status ON nawy.COMMISSION(broker_id, status);
```

### Optimization for Larger Datasets

If the `BROKER` table grows beyond 10K rows:

1. **Materialize the summary**:

```sql
CREATE TABLE nawy.mv_broker_performance AS
SELECT ... -- the CTE logic
```

2. **Refresh every 15 minutes via SQL Agent job**

3. **Query the view** instead of raw tables

### Common Bottleneck

The `COUNT(DISTINCT CASE WHEN ...)` pattern is expensive when aggregating millions of rows. If runtime exceeds 10 seconds:

- Split into separate CTEs for leads, deals, and commissions
- Join them at the end via `broker_id`

This trades readability for performance.
