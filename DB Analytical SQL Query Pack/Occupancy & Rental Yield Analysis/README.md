# Query 5 — Occupancy & Rental Yield Analysis

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

> **What is the average occupancy rate across Nawy Unlocked properties, how does it vary by location and service type, and which segments deliver the highest rental yield?**

---

## 💼 Business Context

### Why This Matters to Nawy

Nawy Unlocked converts idle Egyptian properties — estimated at **10 million units** — into income-generating assets. The service:

1. **Finishes & furnishes** shell/semi-finished properties
2. **Finances up to 50%** of finishing costs
3. **Finds tenants** and manages leases
4. **Collects rent** and handles renewals

Revenue model:
- **Management fee**: typically 10% of monthly rent
- **Financing repayment**: recovered through rental income over time

This query directly impacts three strategic decisions:

1. **Which properties to acquire for management?** — Occupancy and yield patterns identify the best segments.
2. **How to price management fees?** — Yield data informs fee structure.
3. **How to market to owners?** — Real occupancy rates prove Nawy's value proposition.

### Who Uses This Query

| Role | Purpose |
|------|---------|
| **Nawy Unlocked Operations** | Daily performance monitoring |
| **Owner Relations** | Report to property owners |
| **Investment Committee** | Select properties for management |
| **Finance** | Forecast rental income and management fees |
| **Marketing** | Validate "income-generating asset" claims |

### What "Good" Looks Like

| Metric | Benchmark | Elite |
|--------|-----------|-------|
| **Occupancy Rate** | 75–85% | > 90% |
| **On-Time Payment Rate** | 85–92% | > 95% |
| **Avg Monthly Rent** | 15K–25K EGP | > 35K EGP |
| **Contract Retention** | 60% renewal | > 80% renewal |

### The Nawy Unlocked Value Proposition

Owners partner with Nawy Unlocked because they:

- Can't manage a rental property remotely
- Don't have time to find tenants
- Want to convert an idle asset into cash flow
- Need a trusted partner to handle maintenance

Nawy's job is to maximize both **occupancy** (revenue for owners) and **on-time payments** (predictable cash flow for Nawy's fees).

---

## 🔍 The Query

USE NawyProptechDB;
GO

-- PART 1: CONTRACT-LEVEL PERFORMANCE
-- For each management contract, compute:
--   - Property and owner details
--   - Contract service type and fee structure
--   - Lease metrics (total, active, expired)
--   - Rent payment metrics (collected, overdue, on-time rate)
--   - Occupancy rate and revenue generated
--
-- Metrics:
--   Occupancy rate = active leases / total leases × 100
--   On-time rate = paid payments / total payments × 100

WITH contract_performance AS (
    SELECT
        mc.contract_id,
        mc.property_id,
        p.title                                 AS property_title,
        p.city,
        p.district,
        p.compound_name,
        p.property_type,
        mc.owner_user_id,
        u.full_name                             AS owner_name,
        u.email                                 AS owner_email,
        mc.service_type,
        mc.management_fee_percent,
        mc.financing_percent,
        mc.contract_start,
        mc.contract_end,
        DATEDIFF(DAY, mc.contract_start,
                 ISNULL(mc.contract_end, SYSDATETIMEOFFSET())) AS contract_days,
        mc.status                               AS contract_status,

        -- Lease metrics
        COUNT(DISTINCT l.lease_id)              AS total_leases,
        SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END)     AS active_leases,
        SUM(CASE WHEN l.status = 'expired' THEN 1 ELSE 0 END)    AS expired_leases,
        SUM(CASE WHEN l.status = 'terminated' THEN 1 ELSE 0 END) AS terminated_leases,
        ISNULL(AVG(l.monthly_rent), 0)          AS avg_monthly_rent,

        -- Rent payment metrics
        COUNT(rp.rent_payment_id)               AS total_rent_payments,
        SUM(CASE WHEN rp.status = 'paid' THEN 1 ELSE 0 END)     AS paid_payments,
        SUM(CASE WHEN rp.status = 'overdue' THEN 1 ELSE 0 END)  AS overdue_payments,
        SUM(CASE WHEN rp.status = 'pending' THEN 1 ELSE 0 END)  AS pending_payments,
        ISNULL(SUM(CASE WHEN rp.status = 'paid'
                        THEN rp.amount ELSE 0 END), 0) AS total_rent_collected,

        -- Late payment severity
        ISNULL(AVG(CASE
            WHEN rp.paid_date IS NOT NULL AND rp.due_date IS NOT NULL
            THEN DATEDIFF(DAY, rp.due_date, rp.paid_date)
            ELSE NULL
        END), 0) AS avg_days_late

    FROM nawy.MANAGEMENT_CONTRACT mc
    INNER JOIN nawy.PROPERTY p
        ON mc.property_id = p.property_id
    INNER JOIN nawy.[USER] u
        ON mc.owner_user_id = u.user_id
    LEFT JOIN nawy.LEASE l
        ON mc.contract_id = l.contract_id
    LEFT JOIN nawy.RENT_PAYMENT rp
        ON l.lease_id = rp.lease_id
    GROUP BY
        mc.contract_id,
        mc.property_id,
        p.title,
        p.city,
        p.district,
        p.compound_name,
        p.property_type,
        mc.owner_user_id,
        u.full_name,
        u.email,
        mc.service_type,
        mc.management_fee_percent,
        mc.financing_percent,
        mc.contract_start,
        mc.contract_end,
        mc.status
)

SELECT
    contract_id,
    property_title,
    city,
    district,
    compound_name,
    property_type,
    owner_name,
    service_type,
    CAST(management_fee_percent * 100 AS DECIMAL(10,2)) AS management_fee_pct,
    CAST(financing_percent * 100 AS DECIMAL(10,2))      AS financing_pct,
    contract_days,
    contract_status,

    -- Lease metrics
    total_leases,
    active_leases,
    expired_leases,
    CAST(avg_monthly_rent AS DECIMAL(15,2))     AS avg_monthly_rent_egp,

    -- Rent payment metrics
    total_rent_payments,
    paid_payments,
    overdue_payments,
    CAST(total_rent_collected AS DECIMAL(18,2)) AS total_rent_collected_egp,

    -- Occupancy rate (0-100%)
    CAST(
        CASE WHEN total_leases = 0 THEN 0
             ELSE 100.0 * active_leases / total_leases
        END AS DECIMAL(10,2)
    ) AS occupancy_rate_pct,

    -- On-time payment rate (0-100%)
    CAST(
        CASE WHEN total_rent_payments = 0 THEN 0
             ELSE 100.0 * paid_payments / total_rent_payments
        END AS DECIMAL(10,2)
    ) AS on_time_payment_pct,

    -- Average days late (for late payers only)
    CAST(avg_days_late AS DECIMAL(10,2))        AS avg_days_late,

    -- Performance tier
    CASE
        WHEN total_leases = 0 THEN 'No Leases Yet'
        WHEN 100.0 * active_leases / total_leases >= 90
             AND 100.0 * paid_payments / NULLIF(total_rent_payments, 0) >= 95
            THEN 'Elite'
        WHEN 100.0 * active_leases / total_leases >= 75
            THEN 'Healthy'
        WHEN 100.0 * active_leases / total_leases >= 50
            THEN 'Underperforming'
        ELSE 'Vacant'
    END AS performance_tier

FROM contract_performance
ORDER BY
    CASE WHEN total_leases = 0 THEN 1 ELSE 0 END,
    occupancy_rate_pct DESC,
    total_rent_collected_egp DESC;
GO

-- PART 2: SUMMARY BY CITY AND SERVICE TYPE
-- Aggregate contract performance at the city × service level.
-- Weighted by lease and payment counts to avoid small-sample bias.

SELECT
    p.city,
    mc.service_type,
    COUNT(DISTINCT mc.contract_id)              AS total_contracts,
    SUM(CASE WHEN mc.status = 'active' THEN 1 ELSE 0 END) AS active_contracts,
    COUNT(DISTINCT l.lease_id)                  AS total_leases,
    SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END) AS active_leases,

    -- Weighted occupancy rate
    CAST(
        CASE WHEN COUNT(DISTINCT l.lease_id) = 0 THEN 0
             ELSE 100.0 * SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END)
                        / COUNT(DISTINCT l.lease_id)
        END AS DECIMAL(10,2)
    ) AS occupancy_rate_pct,

    -- Weighted on-time payment rate
    CAST(
        CASE WHEN COUNT(rp.rent_payment_id) = 0 THEN 0
             ELSE 100.0 * SUM(CASE WHEN rp.status = 'paid' THEN 1 ELSE 0 END)
                        / COUNT(rp.rent_payment_id)
        END AS DECIMAL(10,2)
    ) AS on_time_payment_pct,

    -- Financial metrics
    CAST(ISNULL(AVG(l.monthly_rent), 0) AS DECIMAL(15,2))  AS avg_monthly_rent_egp,
    CAST(ISNULL(SUM(CASE WHEN rp.status = 'paid'
                        THEN rp.amount ELSE 0 END), 0) AS DECIMAL(18,2)) AS total_rent_collected_egp,

    -- Estimated Nawy revenue (management fee portion)
    CAST(ISNULL(SUM(CASE WHEN rp.status = 'paid'
                        THEN rp.amount * mc.management_fee_percent
                        ELSE 0 END), 0) AS DECIMAL(18,2)) AS estimated_nawy_revenue_egp

FROM nawy.MANAGEMENT_CONTRACT mc
INNER JOIN nawy.PROPERTY p
    ON mc.property_id = p.property_id
LEFT JOIN nawy.LEASE l
    ON mc.contract_id = l.contract_id
LEFT JOIN nawy.RENT_PAYMENT rp
    ON l.lease_id = rp.lease_id
WHERE mc.status IN ('active', 'expired', 'terminated')
GROUP BY p.city, mc.service_type
HAVING COUNT(DISTINCT mc.contract_id) >= 3
ORDER BY occupancy_rate_pct DESC, total_rent_collected_egp DESC;
GO

---

## 🔬 Code Walkthrough

### Section 1 — CTE: `contract_performance`

**Purpose**: Compute per-contract operational metrics with lease and payment data.

**Key techniques**:

| Technique | Purpose |
|-----------|---------|
| `INNER JOIN` to `PROPERTY`, `USER` | Every contract has a property and owner |
| `LEFT JOIN` to `LEASE`, `RENT_PAYMENT` | Include contracts with no leases yet |
| `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` | Conditional counting by lease/payment status |
| `NULLIF(divisor, 0)` | Prevents divide-by-zero |
| `DATEDIFF` for contract tenure | Track how long contracts have been active |

**Why LEFT JOIN to leases and payments?**

A newly signed management contract may not have a tenant yet. LEFT JOIN keeps it visible with 0 metrics, so operations can see vacant inventory.

**Why track `terminated_leases`?**

Leases end for three reasons:
- `expired` — natural end (tenant moved)
- `terminated` — early exit (tenant broke lease, or Nawy ended it)
- `active` — currently occupied

A high `terminated` count signals tenant friction — worth investigating.

---

### Section 2 — Occupancy Rate Calculation

```sql
CASE WHEN total_leases = 0 THEN 0
     ELSE 100.0 * active_leases / total_leases
END
```

**Business interpretation**:

- **High occupancy** (90%+): Property is desirable, priced right, well-marketed
- **Mid occupancy** (50–90%): Normal turnover, acceptable
- **Low occupancy** (< 50%): Problem with pricing, location, or quality

**Edge case**: A contract with 0 leases (new, or never rented) shows occupancy = 0. This is correct — but the tier system separates these from actively underperforming properties.

---

### Section 3 — On-Time Payment Rate

```sql
CASE WHEN total_rent_payments = 0 THEN 0
     ELSE 100.0 * paid_payments / total_rent_payments
END
```

**Business interpretation**:

- **> 95% on-time**: Excellent tenant screening and follow-up
- **85–95%**: Healthy; occasional late payments
- **70–85%**: Concerning; tenant quality issue
- **< 70%**: Critical; escalate to collections policy review

**Why include this metric?**

Because Nawy's revenue depends on **management fees collected from rent**. If rent is late, Nawy's fee is also delayed. On-time rate directly affects Nawy's cash flow.

---

### Section 4 — Performance Tier Logic

```sql
CASE
    WHEN total_leases = 0 THEN 'No Leases Yet'
    WHEN occupancy >= 90 AND on_time >= 95 THEN 'Elite'
    WHEN occupancy >= 75 THEN 'Healthy'
    WHEN occupancy >= 50 THEN 'Underperforming'
    ELSE 'Vacant'
END
```

**Tier definitions**:

| Tier | Criteria | Action |
|------|----------|--------|
| **No Leases Yet** | 0 leases | Onboarding follow-up |
| **Elite** | Occ ≥ 90% AND OTP ≥ 95% | Feature case study; award owner |
| **Healthy** | Occ ≥ 75% | Standard operations |
| **Underperforming** | Occ ≥ 50% | Investigate pricing/marketing |
| **Vacant** | Occ < 50% | Urgent intervention |

**Why combine occupancy AND on-time?**

A property with 100% occupancy but 60% on-time payments isn't really "Elite" — revenue is unreliable. Requiring both conditions produces a meaningful top-tier.

---

### Section 5 — Part 2: Weighted Aggregation

**Why weight by lease/payment count?**

Simple averages distort results when the sample size is uneven. Example:

- Contract A: 1 lease, 100% occupancy
- Contract B: 10 leases, 50% occupancy
- Simple average: 75%
- **Weighted average (correct)**: 11 leases, 6 active → 54.5%

The second method reflects reality. By using `SUM(...) / COUNT(...)` we naturally weight.

---

## 📊 Expected Output

### Part 1 — Sample Result Set (Per-Contract)

| contract_id | property_title | city | district | property_type | service_type | management_fee_pct | total_leases | active_leases | avg_monthly_rent_egp | total_rent_payments | paid_payments | overdue_payments | total_rent_collected_egp | occupancy_rate_pct | on_time_payment_pct | performance_tier |
|-------------|----------------|------|----------|---------------|--------------|--------------------|--------------|---------------|----------------------|---------------------|---------------|------------------|--------------------------|-------------------|---------------------|------------------|
| 12 | 3BR Apartment in Villette | Cairo | New Cairo | apartment | full_management | 10.00 | 3 | 1 | 18,500.00 | 36 | 34 | 2 | 629,000.00 | 33.33 | 94.44 | Underperforming |
| 45 | 2BR Apartment in Badya | Giza | 6th of October | apartment | rental_only | 8.00 | 5 | 1 | 12,300.00 | 60 | 57 | 3 | 738,000.00 | 20.00 | 95.00 | Vacant |
| 78 | 4BR Villa in Swan Lake | Cairo | Sheikh Zayed | villa | full_management | 10.00 | 2 | 1 | 42,000.00 | 24 | 23 | 1 | 1,008,000.00 | 50.00 | 95.83 | Underperforming |
| 112 | 3BR Apartment in Hyde Park | Cairo | New Cairo | apartment | full_management | 10.00 | 4 | 4 | 22,500.00 | 48 | 46 | 2 | 1,080,000.00 | 100.00 | 95.83 | Elite |
| 156 | 2BR Apartment in Marassi | North Coast | Marassi | chalet | furnishing | 12.00 | 2 | 2 | 55,000.00 | 24 | 24 | 0 | 1,320,000.00 | 100.00 | 100.00 | Elite |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Part 2 — Sample Result Set (Summary)

| city | service_type | total_contracts | active_contracts | total_leases | active_leases | occupancy_rate_pct | on_time_payment_pct | avg_monthly_rent_egp | total_rent_collected_egp | estimated_nawy_revenue_egp |
|------|--------------|-----------------|------------------|--------------|---------------|--------------------|---------------------|----------------------|--------------------------|---------------------------|
| North Coast | furnishing | 8 | 6 | 14 | 13 | 92.86 | 96.40 | 48,500.00 | 7,860,000.00 | 943,200.00 |
| Cairo | full_management | 45 | 38 | 98 | 88 | 89.80 | 94.20 | 22,400.00 | 19,520,000.00 | 1,952,000.00 |
| Giza | full_management | 22 | 18 | 48 | 42 | 87.50 | 92.80 | 16,800.00 | 7,560,000.00 | 756,000.00 |
| Cairo | rental_only | 32 | 26 | 68 | 55 | 80.88 | 89.50 | 18,500.00 | 10,200,000.00 | 816,000.00 |
| New Administrative Capital | full_management | 6 | 5 | 12 | 9 | 75.00 | 88.20 | 20,300.00 | 2,190,000.00 | 219,000.00 |
| Alexandria | rental_only | 12 | 10 | 24 | 17 | 70.83 | 85.40 | 13,500.00 | 2,916,000.00 | 233,280.00 |

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `contract_id` | BIGINT | Unique management contract ID |
| `property_title` | NVARCHAR | Property name |
| `city` | NVARCHAR | Location |
| `district` | NVARCHAR | Neighborhood |
| `property_type` | NVARCHAR | apartment, villa, chalet, etc. |
| `service_type` | NVARCHAR | finishing, furnishing, full_management, rental_only |
| `management_fee_pct` | DECIMAL | Nawy's fee percentage |
| `financing_pct` | DECIMAL | % of finishing costs financed |
| `total_leases` | INT | Total leases over contract lifetime |
| `active_leases` | INT | Currently active leases |
| `avg_monthly_rent_egp` | DECIMAL | Average rent per lease |
| `total_rent_payments` | INT | Total rent payments scheduled |
| `paid_payments` | INT | Payments received on time |
| `overdue_payments` | INT | Payments not received |
| `total_rent_collected_egp` | DECIMAL | Total rental income |
| `occupancy_rate_pct` | DECIMAL | Active leases / total leases × 100 |
| `on_time_payment_pct` | DECIMAL | Paid / total × 100 |
| `performance_tier` | NVARCHAR | Elite / Healthy / Underperforming / Vacant |

---

## 📈 Interpretation Guide

### Reading the Per-Contract Output

**Sample observation**: Contract #112 (Hyde Park apartment):

- 4 leases total, all 4 active
- 100% occupancy
- 95.83% on-time payment
- **Tier: Elite**

**What this tells us**:

- Property is highly desirable (long tenant retention)
- Tenant screening is excellent
- Owner is likely very satisfied → renewal probability high
- **Action**: Feature in case study; consider priority for future owner acquisitions

**Sample observation**: Contract #78 (Swan Lake villa):

- 2 leases total, only 1 active
- 50% occupancy
- 95.83% on-time payment
- High rent (42,000 EGP/month)
- **Tier: Underperforming**

**What this tells us**:

- Villa segment has natural turnover (larger properties, longer vacancies)
- Rent is above market — may need adjustment
- Payment quality is fine; the issue is demand
- **Action**: Review pricing; consider furnished upgrade; extended marketing

### Interpreting the Summary

**Key insight from sample data**:

| Segment | Occupancy | On-Time | Revenue | Interpretation |
|---------|-----------|---------|---------|----------------|
| **North Coast furnishing** | 92.86% | 96.40% | 943K EGP | Premium segment, high margin |
| **Cairo full_management** | 89.80% | 94.20% | 1.95M EGP | Core business, healthy |
| **Giza full_management** | 87.50% | 92.80% | 756K EGP | Solid performer |
| **Cairo rental_only** | 80.88% | 89.50% | 816K EGP | Lower fee, lower occupancy |
| **NAC full_management** | 75.00% | 88.20% | 219K EGP | Emerging; watch |
| **Alexandria rental_only** | 70.83% | 85.40% | 233K EGP | Weakest; needs attention |

**Strategic implications**:

1. **North Coast furnishing** — Highest occupancy AND highest rent. Prioritize this segment for new owner acquisition.

2. **Cairo full_management** — Volume driver. Steady performance justifies higher marketing investment.

3. **Rental_only service type** — Underperforms full_management by 8–10 percentage points on occupancy. Owners choosing rental_only may benefit from upgrading.

4. **Alexandria** — Weakest market. Either reduce exposure or investigate operational issues.

5. **Nawy revenue concentration** — Cairo accounts for ~65% of total estimated revenue. Geographic diversification is a strategic priority.

### Red Flags

| Signal | Interpretation | Action |
|--------|----------------|--------|
| Occupancy < 50% for 90+ days | Property unlikely to rent at current price | Recommend rent reduction |
| On-time payment < 80% | Tenant quality issue | Review screening criteria |
| High `terminated_leases` | Tenant friction | Exit interview; process review |
| Average days late > 10 | Systemic collection issue | Tighten follow-up process |
| Same property multiple "Vacant" months | Structural issue (location, quality) | Consider removing from portfolio |

### The Occupancy-Revenue Relationship

Notice that **North Coast furnishing** generates the **highest revenue per contract** despite fewer contracts:

- 8 contracts → 943K EGP Nawy revenue
- 45 Cairo contracts → 1.95M EGP Nawy revenue

Per contract:

- North Coast: ~118K EGP per contract
- Cairo: ~43K EGP per contract

**Strategic implication**: Nawy Unlocked should invest in scaling North Coast furnishing, even if it means fewer contracts. Higher revenue per unit of operational effort.

---

## 💡 Analytical Extensions

### Extension 1 — Rent Yield vs. Property Value

Calculate annual yield:

```sql
-- Rental yield = annual rent / property price × 100
CAST(
    100.0 * (AVG(l.monthly_rent) * 12) / p.price AS DECIMAL(5,2)
) AS rental_yield_pct
```

**Expected insight**: Rental yield in Egypt is typically 4–7%. Nawy Unlocked should target properties with ≥ 6% yield.

### Extension 2 — Tenant Retention Analysis

Measure average lease duration:

```sql
AVG(DATEDIFF(DAY, l.start_date, l.end_date)) AS avg_lease_days
```

**Expected insight**: Longer retention (18+ months) correlates with higher satisfaction and lower turnover cost.

### Extension 3 — Payment Latency Distribution

Bucket payments by days late:

```sql
CASE
    WHEN DATEDIFF(DAY, rp.due_date, rp.paid_date) <= 0 THEN 'On Time'
    WHEN DATEDIFF(DAY, rp.due_date, rp.paid_date) <= 5 THEN '1-5 Days Late'
    WHEN DATEDIFF(DAY, rp.due_date, rp.paid_date) <= 15 THEN '6-15 Days Late'
    WHEN DATEDIFF(DAY, rp.due_date, rp.paid_date) <= 30 THEN '16-30 Days Late'
    ELSE '30+ Days Late'
END AS lateness_bucket
```

**Expected insight**: Most late payments cluster at 1–5 days — suggests admin delay, not financial stress.

### Extension 4 — Finishing Project ROI

For contracts with finishing projects:

```sql
-- Join FINISHING_PROJECT to compare actual_cost vs budget
-- Correlate cost overrun with occupancy after completion
```

**Expected insight**: Properties that finish on budget have 15% higher occupancy — suggests project management quality correlates with market performance.

### Extension 5 — Owner Cohort Analysis

Group owners by contract start year:

```sql
YEAR(mc.contract_start) AS start_year
```

**Expected insight**: Early adopters (2022–2023) show higher retention. Recent cohorts may need extra onboarding support.

### Extension 6 — Visualize in Tableau

1. Connect Tableau to `NawyProptechDB`
2. Use the query as a **Custom SQL** data source
3. Build:
   - **Bar chart**: Occupancy rate by city
   - **Scatter plot**: `avg_monthly_rent_egp` (x) vs `on_time_payment_pct` (y)
   - **Heatmap**: City × Service Type occupancy matrix
   - **KPI tiles**: Total contracts, avg occupancy, Nawy revenue
   - **Trend line**: Occupancy over contract start month

---

## ⚡ Performance Notes

### Query Runtime

- **Expected**: 700–1,000 ms on 210 contracts × 340 leases × 2,800 payments
- **Scales to**: 5–10 seconds at 10K contracts with proper indexes

### Relevant Indexes

```sql
CREATE INDEX IX_MGMT_CONTRACT_status ON nawy.MANAGEMENT_CONTRACT(status);
CREATE INDEX IX_MGMT_CONTRACT_owner ON nawy.MANAGEMENT_CONTRACT(owner_user_id);
CREATE INDEX IX_LEASE_contract ON nawy.LEASE(contract_id);
CREATE INDEX IX_LEASE_status ON nawy.LEASE(status);
CREATE INDEX IX_RENT_PAYMENT_lease ON nawy.RENT_PAYMENT(lease_id);
CREATE INDEX IX_RENT_PAYMENT_status_due ON nawy.RENT_PAYMENT(status, due_date);
```

### Optimization Tips

**1. Materialize contract performance**

For daily operations:

```sql
CREATE TABLE nawy.mv_contract_performance AS
SELECT ... -- CTE logic
```

**2. Partition by contract year**

For contracts spanning multiple years:

```sql
CREATE PARTITION FUNCTION pf_contract_year (DATE) AS RANGE RIGHT FOR VALUES
    ('2023-01-01','2024-01-01','2025-01-01','2026-01-01');
```

**3. Precompute occupancy rate**

Add a computed column to a summary table refreshed nightly.

**4. Index filtered subsets**

For active contracts only:

```sql
CREATE INDEX IX_MGMT_CONTRACT_active
ON nawy.MANAGEMENT_CONTRACT(property_id, owner_user_id)
WHERE status = 'active';
```
