# Query 10 — Executive KPIs Dashboard

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

> **What is the single-screen, board-ready summary of Nawy's performance across users, properties, transactions, and all five business lines?**

---

## 💼 Business Context

### Why This Matters to Nawy

Every quarter, Nawy's executive team and board need a **single, trusted view** of platform performance. This query produces a **KPI dashboard** that consolidates:

1. **User Growth** — Registration, activation, verification
2. **Property Inventory** — Active listings, sold, rented
3. **Sales Pipeline** — Leads, deals, GMV
4. **Nawy Now** — Mortgage applications, portfolio health
5. **Nawy Shares** — Offerings, investments, exits
6. **Nawy Unlocked** — Contracts, occupancy, rent collected
7. **Compliance** — Escrow held, active accounts
8. **Revenue** — Total revenue by business line

### Who Uses This Query

| Role | Purpose |
|------|---------|
| **CEO / CFO** | Board reporting |
| **Executive Team** | Weekly leadership review |
| **Investor Relations** | Investor update decks |
| **Strategy** | Business unit comparison |
| **Finance** | Monthly close reporting |

### What "Good" Looks Like

| KPI | Benchmark | Elite |
|-----|-----------|-------|
| **GMV (annual)** | > 1B EGP | > 2B EGP |
| **Active listings** | > 400 | > 700 |
| **Multi-line users** | > 25% | > 40% |
| **Portfolio default rate** | < 5% | < 3% |
| **Avg Shares ROI** | > 30% | > 60% |
| **Occupancy rate** | > 80% | > 90% |

### Design Philosophy

This query is the **opposite of Query 1–9**. Those queries are deep-dives into specific business problems. This query is a **wide snapshot** — one row per metric, ready for a BI dashboard.

**Structure**: A `UNION ALL` of ~50 KPIs organized into **8 categories**:

- Users, Properties, Sales, Nawy Now, Nawy Shares, Nawy Unlocked, Compliance, Revenue

Each metric has:

- `category` — grouping
- `kpi_name` — human-readable label
- `kpi_value` — the number
- `formatted_value` — with units (EGP, %, count)
- `as_of_date` — timestamp

---

## 🔍 The Query

```sql
-- Query 10: Executive KPIs Dashboard
-- Business Question:
--   What is the single-screen, board-ready summary of Nawy's
--   performance across users, properties, transactions, and
--   all five business lines?
--
-- Used By:
--   - CEO / CFO (board reporting)
--   - Executive team (weekly leadership review)
--   - Investor relations (investor updates)
--   - Strategy (business unit comparison)
--   - Finance (monthly close)
--
-- Output:
--   Single result set with ~50 KPIs, grouped by category,
--   each with value, formatted display, and timestamp.
--

USE NawyProptechDB;
GO

-- EXECUTIVE KPI DASHBOARD
-- Produces one row per KPI, organized by category.
-- Designed to feed a Tableau/Power BI "scorecard" visual.

DECLARE @as_of_date DATETIMEOFFSET(7) = SYSDATETIMEOFFSET();

SELECT
    category,
    kpi_name,
    kpi_value,
    formatted_value,
    @as_of_date AS as_of_date
FROM (
    -- 1. USER METRICS
    SELECT
        1 AS sort_order,
        '1. Users' AS category,
        'Total Users' AS kpi_name,
        CAST(COUNT(*) AS DECIMAL(18,2)) AS kpi_value,
        CAST(COUNT(*) AS NVARCHAR(50)) + ' users' AS formatted_value
    FROM nawy.[USER]

    UNION ALL
    SELECT 1, '1. Users', 'Verified Users',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' (' +
        CAST(CAST(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM nawy.[USER]), 0) AS DECIMAL(5,2)) AS NVARCHAR(10)) + '% verified)'
    FROM nawy.[USER] WHERE is_verified = 1

    UNION ALL
    SELECT 1, '1. Users', 'Active Brokers',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' brokers'
    FROM nawy.BROKER WHERE status = 'active'

    UNION ALL
    SELECT 1, '1. Users', 'Verified Tenants',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' tenants'
    FROM nawy.TENANT WHERE verification_status = 'verified'

    -- 2. PROPERTY METRICS
    UNION ALL
    SELECT 2, '2. Properties', 'Total Listings',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' listings'
    FROM nawy.PROPERTY

    UNION ALL
    SELECT 2, '2. Properties', 'Active Listings',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' active'
    FROM nawy.PROPERTY WHERE status = 'active'

    UNION ALL
    SELECT 2, '2. Properties', 'Properties Sold',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' sold'
    FROM nawy.PROPERTY WHERE status = 'sold'

    UNION ALL
    SELECT 2, '2. Properties', 'Properties Rented',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' rented'
    FROM nawy.PROPERTY WHERE status = 'rented'

    UNION ALL
    SELECT 2, '2. Properties', 'Total Inventory Value',
        CAST(ISNULL(SUM(price), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(price), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.PROPERTY WHERE status = 'active'

    UNION ALL
    SELECT 2, '2. Properties', 'Total Developers',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' developers'
    FROM nawy.DEVELOPER

    -- 3. SALES PIPELINE
    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Total Leads',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' leads'
    FROM nawy.LEAD

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Won Leads',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' won'
    FROM nawy.LEAD WHERE status = 'closed_won'

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Lead Conversion Rate',
        CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.LEAD) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.LEAD)
            END AS DECIMAL(10,2)
        ),
        CAST(CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.LEAD) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.LEAD)
            END AS DECIMAL(5,2)) AS NVARCHAR(10)) + '%'
    FROM nawy.LEAD WHERE status = 'closed_won'

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Completed Deals',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' deals'
    FROM nawy.DEAL WHERE status = 'completed'

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Total GMV',
        CAST(ISNULL(SUM(sale_price), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(sale_price), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.DEAL WHERE status = 'completed'

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Avg Deal Size',
        CAST(ISNULL(AVG(sale_price), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(AVG(sale_price), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.DEAL WHERE status = 'completed'

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Commissions Paid',
        CAST(ISNULL(SUM(commission_amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(commission_amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.COMMISSION WHERE status = 'paid'

    -- 4. NAWY NOW (MORTGAGE)
    UNION ALL
    SELECT 4, '4. Nawy Now', 'Mortgage Applications',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' applications'
    FROM nawy.MORTGAGE_APPLICATION

    UNION ALL
    SELECT 4, '4. Nawy Now', 'Disbursed Mortgages',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' disbursed'
    FROM nawy.MORTGAGE_APPLICATION WHERE status = 'disbursed'

    UNION ALL
    SELECT 4, '4. Nawy Now', 'Mortgage Portfolio Value',
        CAST(ISNULL(SUM(loan_amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(loan_amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.MORTGAGE_APPLICATION WHERE status = 'disbursed'

    UNION ALL
    SELECT 4, '4. Nawy Now', 'Total Installments',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' payments'
    FROM nawy.MORTGAGE_PAYMENT

    UNION ALL
    SELECT 4, '4. Nawy Now', 'Overdue Installments',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' overdue'
    FROM nawy.MORTGAGE_PAYMENT WHERE status = 'overdue'

    UNION ALL
    SELECT 4, '4. Nawy Now', 'Portfolio Default Rate',
        CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.MORTGAGE_PAYMENT) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.MORTGAGE_PAYMENT)
            END AS DECIMAL(10,2)
        ),
        CAST(CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.MORTGAGE_PAYMENT) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.MORTGAGE_PAYMENT)
            END AS DECIMAL(5,2)) AS NVARCHAR(10)) + '%'
    FROM nawy.MORTGAGE_PAYMENT WHERE status = 'overdue'

    -- 5. NAWY SHARES (FRACTIONAL INVESTMENT)
    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Total Offerings',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' offerings'
    FROM nawy.SHARE_OFFERING

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Active Offerings',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' open'
    FROM nawy.SHARE_OFFERING WHERE status = 'open'

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Total Investments',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' investments'
    FROM nawy.SHARE_INVESTMENT

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Total Capital Raised',
        CAST(ISNULL(SUM(total_amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(total_amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.SHARE_INVESTMENT

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Unique Investors',
        CAST(COUNT(DISTINCT user_id) AS DECIMAL(18,2)),
        CAST(COUNT(DISTINCT user_id) AS NVARCHAR(50)) + ' investors'
    FROM nawy.SHARE_INVESTMENT

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Completed Exits',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' exits'
    FROM nawy.SHARE_EXIT WHERE status = 'completed'

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Average ROI %',
        CAST(ISNULL(AVG(
            CASE WHEN si.total_amount > 0
                 THEN 100.0 * se.profit_loss / si.total_amount
                 ELSE NULL END
        ), 0) AS DECIMAL(10,2)),
        CAST(CAST(ISNULL(AVG(
            CASE WHEN si.total_amount > 0
                 THEN 100.0 * se.profit_loss / si.total_amount
                 ELSE NULL END
        ), 0) AS DECIMAL(5,2)) AS NVARCHAR(10)) + '%'
    FROM nawy.SHARE_EXIT se
    INNER JOIN nawy.SHARE_INVESTMENT si ON se.investment_id = si.investment_id
    WHERE se.status = 'completed'

    -- 6. NAWY UNLOCKED (PROPERTY MANAGEMENT)
    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Management Contracts',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' contracts'
    FROM nawy.MANAGEMENT_CONTRACT

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Active Contracts',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' active'
    FROM nawy.MANAGEMENT_CONTRACT WHERE status = 'active'

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Total Leases',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' leases'
    FROM nawy.LEASE

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Active Leases',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' active'
    FROM nawy.LEASE WHERE status = 'active'

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Occupancy Rate',
        CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.LEASE) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.LEASE)
            END AS DECIMAL(10,2)
        ),
        CAST(CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.LEASE) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.LEASE)
            END AS DECIMAL(5,2)) AS NVARCHAR(10)) + '%'
    FROM nawy.LEASE WHERE status = 'active'

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Total Rent Collected',
        CAST(ISNULL(SUM(amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.RENT_PAYMENT WHERE status = 'paid'

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Finishing Projects',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' projects'
    FROM nawy.FINISHING_PROJECT

    -- 7. COMPLIANCE
    UNION ALL
    SELECT 7, '7. Compliance', 'Total Escrow Accounts',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' accounts'
    FROM nawy.ESCROW_ACCOUNT

    UNION ALL
    SELECT 7, '7. Compliance', 'Active Escrows',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' active'
    FROM nawy.ESCROW_ACCOUNT WHERE status = 'active'

    UNION ALL
    SELECT 7, '7. Compliance', 'Total Escrow Held',
        CAST(ISNULL(SUM(deposit_amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(deposit_amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.ESCROW_ACCOUNT WHERE status = 'active'

    -- 8. REVENUE BY BUSINESS LINE
    UNION ALL
    SELECT 8, '8. Revenue', 'Nawy Partners Revenue',
        CAST(ISNULL(SUM(commission_amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(commission_amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.COMMISSION WHERE status = 'paid'

    UNION ALL
    SELECT 8, '8. Revenue', 'Nawy Now Revenue (Est.)',
        CAST(ISNULL(SUM(loan_amount * ISNULL(interest_rate, 0)), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(loan_amount * ISNULL(interest_rate, 0)), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.MORTGAGE_APPLICATION WHERE status = 'disbursed'

    UNION ALL
    SELECT 8, '8. Revenue', 'Nawy Shares Revenue',
        CAST(ISNULL(SUM(total_sale_value * exit_fee_percent), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(total_sale_value * exit_fee_percent), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.SHARE_EXIT WHERE status = 'completed'

    UNION ALL
    SELECT 8, '8. Revenue', 'Nawy Unlocked Revenue',
        CAST(ISNULL(SUM(rp.amount * mc.management_fee_percent), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(rp.amount * mc.management_fee_percent), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.RENT_PAYMENT rp
    INNER JOIN nawy.LEASE l ON rp.lease_id = l.lease_id
    INNER JOIN nawy.MANAGEMENT_CONTRACT mc ON l.contract_id = mc.contract_id
    WHERE rp.status = 'paid'
) AS kpis
ORDER BY sort_order, kpi_name;
GO
```

---

## 🔬 Code Walkthrough

### Structure

The query is a large `UNION ALL` of individual `SELECT` statements, each producing one KPI row with:

| Column | Purpose |
|--------|---------|
| `sort_order` | Integer to preserve category order |
| `category` | Business category label |
| `kpi_name` | Human-readable KPI name |
| `kpi_value` | Numeric value for charts |
| `formatted_value` | Pre-formatted display string |
| `as_of_date` | Timestamp for cache-busting |

### Why `UNION ALL` instead of `UNION`?

`UNION ALL` is **faster** (no duplicate elimination) and we have no duplicates (each row is a unique KPI).

### Why both `kpi_value` and `formatted_value`?

- **kpi_value**: Used by Tableau/Power BI for charts (sortable, aggregatable)
- **formatted_value**: Used for card visuals ("2,235,000.00 EGP", "13.50%")

This dual-column pattern is common in BI dashboards — the display string makes card formatting trivial.

### The `sort_order` column

Because `UNION ALL` doesn't preserve row order, we add an integer to explicitly sort. Categories 1–8 remain in their intended order.

### Subqueries for percentage calculations

```sql
CAST(
    CASE WHEN (SELECT COUNT(*) FROM nawy.LEAD) = 0 THEN 0
         ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.LEAD)
    END AS DECIMAL(10,2)
)
```

We can't reference aggregates from other `UNION ALL` blocks, so we use correlated subqueries to fetch denominators. The `= 0` guard prevents divide-by-zero.

### Aggregating revenue streams

Each revenue KPI uses a different table with different join logic:

- **Nawy Partners**: Simple sum of `COMMISSION` where `status = 'paid'`
- **Nawy Now**: `loan_amount × interest_rate` for disbursed mortgages (approximation of first-year interest)
- **Nawy Shares**: `total_sale_value × exit_fee_percent` for completed exits
- **Nawy Unlocked**: `rent_paid × management_fee_percent` for paid rent

**Note**: These are **approximations** to keep the query fast. For accurate P&L, use the detailed queries (3–8) with proper accounting.

---

## 📊 Expected Output

### Sample Result Set

| category | kpi_name | kpi_value | formatted_value |
|----------|----------|-----------|-----------------|
| 1. Users | Total Users | 320.00 | 320 users |
| 1. Users | Verified Users | 320.00 | 320 (100% verified) |
| 1. Users | Active Brokers | 43.00 | 43 brokers |
| 1. Users | Verified Tenants | 144.00 | 144 tenants |
| 2. Properties | Total Listings | 520.00 | 520 listings |
| 2. Properties | Active Listings | 285.00 | 285 active |
| 2. Properties | Properties Sold | 145.00 | 145 sold |
| 2. Properties | Properties Rented | 78.00 | 78 rented |
| 2. Properties | Total Inventory Value | 2,485,000,000.00 | 2485M EGP |
| 2. Properties | Total Developers | 25.00 | 25 developers |
| 3. Sales Pipeline | Total Leads | 1,400.00 | 1400 leads |
| 3. Sales Pipeline | Won Leads | 189.00 | 189 won |
| 3. Sales Pipeline | Lead Conversion Rate | 13.50 | 13.50% |
| 3. Sales Pipeline | Completed Deals | 285.00 | 285 deals |
| 3. Sales Pipeline | Total GMV | 1,425,000,000.00 | 1425M EGP |
| 3. Sales Pipeline | Avg Deal Size | 5,000,000.00 | 5M EGP |
| 3. Sales Pipeline | Commissions Paid | 35,625,000.00 | 35.63M EGP |
| 4. Nawy Now | Mortgage Applications | 280.00 | 280 applications |
| 4. Nawy Now | Disbursed Mortgages | 195.00 | 195 disbursed |
| 4. Nawy Now | Mortgage Portfolio Value | 1,245,000,000.00 | 1245M EGP |
| 4. Nawy Now | Total Installments | 4,200.00 | 4200 payments |
| 4. Nawy Now | Overdue Installments | 185.00 | 185 overdue |
| 4. Nawy Now | Portfolio Default Rate | 4.40 | 4.40% |
| 5. Nawy Shares | Total Offerings | 85.00 | 85 offerings |
| 5. Nawy Shares | Active Offerings | 22.00 | 22 open |
| 5. Nawy Shares | Total Investments | 620.00 | 620 investments |
| 5. Nawy Shares | Total Capital Raised | 2,850,000,000.00 | 2850M EGP |
| 5. Nawy Shares | Unique Investors | 245.00 | 245 investors |
| 5. Nawy Shares | Completed Exits | 185.00 | 185 exits |
| 5. Nawy Shares | Average ROI % | 68.50 | 68.50% |
| 6. Nawy Unlocked | Management Contracts | 210.00 | 210 contracts |
| 6. Nawy Unlocked | Active Contracts | 158.00 | 158 active |
| 6. Nawy Unlocked | Total Leases | 340.00 | 340 leases |
| 6. Nawy Unlocked | Active Leases | 285.00 | 285 active |
| 6. Nawy Unlocked | Occupancy Rate | 83.82 | 83.82% |
| 6. Nawy Unlocked | Total Rent Collected | 48,500,000.00 | 48.5M EGP |
| 6. Nawy Unlocked | Finishing Projects | 145.00 | 145 projects |
| 7. Compliance | Total Escrow Accounts | 155.00 | 155 accounts |
| 7. Compliance | Active Escrows | 42.00 | 42 active |
| 7. Compliance | Total Escrow Held | 385,000,000.00 | 385M EGP |
| 8. Revenue | Nawy Partners Revenue | 35,625,000.00 | 35.63M EGP |
| 8. Revenue | Nawy Now Revenue (Est.) | 174,300,000.00 | 174.3M EGP |
| 8. Revenue | Nawy Shares Revenue | 71,250,000.00 | 71.25M EGP |
| 8. Revenue | Nawy Unlocked Revenue | 4,850,000.00 | 4.85M EGP |

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `category` | NVARCHAR | Business category (Users, Properties, etc.) |
| `kpi_name` | NVARCHAR | KPI name (human-readable) |
| `kpi_value` | DECIMAL | Numeric value (for charts) |
| `formatted_value` | NVARCHAR | Display string (for card visuals) |
| `as_of_date` | DATETIMEOFFSET | Query timestamp |

---

## 📈 Interpretation Guide

### Reading the KPIs

**Sample observations**:

| KPI | Value | Interpretation |
|-----|-------|----------------|
| Total Users | 320 | Small but engaged platform |
| Active Brokers | 43 | Healthy broker network |
| Active Listings | 285 | Moderate inventory |
| Lead Conversion | 13.5% | Industry-typical |
| Total GMV | 1.425B EGP | Solid platform activity |
| Portfolio Default | 4.40% | Healthy (below 5% threshold) |
| Avg Shares ROI | 68.50% | Strong performance |
| Occupancy Rate | 83.82% | Healthy operations |
| Total Escrow Held | 385M EGP | Regulatory compliance in action |

### Key Ratios for Board

**1. Revenue per User**

- Total revenue: ~286M EGP
- Total users: 320
- **Revenue per user: ~895K EGP** (exceptionally high — driven by high-value investors)

**2. GMV per Broker**

- Total GMV: 1.425B EGP
- Active brokers: 43
- **GMV per broker: ~33M EGP** (strong productivity)

**3. Cross-Business Engagement**

- Multi-line users: ~21% (from Query 7)
- **Target: 35%+** for mature platform

**4. Escrow-to-GMV Ratio**

- Escrow held: 385M EGP
- Total GMV: 1.425B EGP
- **27% of GMV is in escrow** — normal for off-plan heavy markets

### Board Talking Points

1. **GMV growth** — 1.425B EGP is solid for a young platform
2. **Diversified revenue** — Four revenue streams reduce dependency on any single line
3. **Portfolio quality** — Default rate of 4.40% is well below Egypt's mortgage market average (~7%)
4. **Investment returns** — Avg Shares ROI of 68.5% is genuinely exceptional; drives brand
5. **Compliance posture** — Escrow usage demonstrates FRA readiness
6. **Broker productivity** — 33M EGP GMV per broker is strong; retain top performers

### Red Flags to Watch

| Signal | Interpretation | Action |
|--------|----------------|--------|
| Active listings < 200 | Inventory shortage | Developer partnership push |
| Lead conversion < 10% | Sales ops problem | Broker assignment program |
| Default rate > 6% | Underwriting risk | Tighten criteria |
| Avg ROI < 30% | Shares losing appeal | Offering selection review |
| Occupancy < 75% | Unlocked problems | Pricing + marketing review |
| Escrow > 30% of GMV | Capital tied up | Fund release optimization |

---

## 💡 Analytical Extensions

### Extension 1 — Month-over-Month Trends

Add a `MTD vs. Prior Month` comparison by using date filters:

```sql
-- Wrap each KPI in a CASE comparing this month vs. last month
```

**Expected insight**: Growth rate trending up or down.

### Extension 2 — Year-over-Year Comparison

For each KPI, compute YoY growth:

```sql
-- Current year vs. same period last year
```

**Expected insight**: Annual growth rate by metric.

### Extension 3 — Geographic Breakdown

Add state-level filters:

```sql
-- Same KPIs filtered by city
```

**Expected insight**: Cairo vs. Giza vs. North Coast platform performance.

### Extension 4 — Unit Economics

Add per-unit metrics:

```sql
-- Revenue per property
-- Revenue per broker
-- CLV / CAC ratio
```

**Expected insight**: Efficiency improvements over time.

### Extension 5 — Target vs. Actual

Add goals for each KPI:

```sql
-- Combine with a targets table
-- Show actual vs. target as a percentage
```

**Expected insight**: Performance vs. quarterly OKRs.

### Extension 6 — Visualize in Tableau

1. Connect Tableau to `NawyProptechDB`
2. Use the query as a **Custom SQL** data source
3. Build the executive dashboard:
   - **KPI cards**: One per category (8 cards)
   - **Scorecard**: All KPIs in a table with color coding
   - **Bar chart**: Revenue by business line
   - **Funnel**: Users → Properties → Deals → Revenue
   - **Big numbers**: GMV, Total Revenue, Default Rate

### Example Tableau KPI Card Layout

```
┌─────────────────────────────────────────────────────────────┐
│  NAWY EXECUTIVE DASHBOARD                    As of 2026-09  │
├──────────────┬──────────────┬──────────────┬────────────────┤
│  320         │ 285          │ 1.425B EGP   │ 13.5%          │
│  Total Users │ Active Listing │ GMV        │ Lead Conv.     │
├──────────────┼──────────────┼──────────────┼────────────────┤
│ 1.245B EGP   │ 68.5%        │ 83.8%        │ 4.4%           │
│  Mortgage    │  Shares ROI  │ Occupancy    │ Default Rate   │
├──────────────┴──────────────┴──────────────┴────────────────┤
│  Revenue: Partners 35.6M | Now 174.3M | Shares 71.3M | Unlocked 4.9M │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚡ Performance Notes

### Query Runtime

- **Expected**: 1,200–2,000 ms on ~13K rows across all tables
- **Scales to**: 10–20 seconds at 1M total rows

### Why This Query Is Slow

50+ `UNION ALL` blocks, each scanning one or more tables. The `SELECT COUNT(*) FROM table` subqueries for percentage calculations are particularly expensive.

### Optimization Tips

**1. Materialize to a KPI table**

```sql
CREATE TABLE nawy.mv_executive_kpis (
    snapshot_date DATE,
    category NVARCHAR(100),
    kpi_name NVARCHAR(200),
    kpi_value DECIMAL(18,2),
    formatted_value NVARCHAR(200)
);
```

Refresh hourly via SQL Agent.

**2. Add covering indexes for counts**

```sql
CREATE INDEX IX_LEAD_status ON nawy.LEAD(status);
CREATE INDEX IX_DEAL_status ON nawy.DEAL(status);
CREATE INDEX IX_PROPERTY_status ON nawy.PROPERTY(status);
CREATE INDEX IX_MORTGAGE_status ON nawy.MORTGAGE_APPLICATION(status);
CREATE INDEX IX_LEASE_status ON nawy.LEASE(status);
CREATE INDEX IX_ESCROW_status ON nawy.ESCROW_ACCOUNT(status);
```

**3. Cache subquery counts**

Replace `(SELECT COUNT(*) FROM nawy.LEAD)` with a precomputed variable when the query runs frequently.

**4. Snapshot historical data**

Store daily snapshots to enable YoY/MoM comparisons without re-running the base query.
