# 🏢 Developer Consistency Scorecard — Nawy Shares

> **A data-driven SQL analysis to rank real estate developers by the consistency of returns on fractional investment offerings.**

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Business Question](#-business-question)
- [Data Sources](#-data-sources)
- [Methodology](#-methodology)
- [SQL Query](#-sql-query)
- [Output Columns & Meaning](#-output-columns--meaning)
- [How to Read the Results](#-how-to-read-the-results)
- [Investor Decision Framework](#-investor-decision-framework)
- [Worked Example](#-worked-example)

---

## 🎯 Overview

This analysis answers a single, critical investor question:

> **Which real estate developers have consistently delivered strong returns on Nawy Shares fractional offerings?**

A single successful offering does not tell you much — it could be luck. What matters is **repeatable performance**. This query ranks every developer by their average return, penalises those with erratic results, and grades them from **A+ (Elite)** to **D (Underperformer)**.

**Output grain**: One row per developer.

---

## ❓ Business Question

| Aspect | Detail |
|--------|--------|
| **Question** | Which developers deliver consistent, strong ROI? |
| **Audience** | Nawy Shares investment committee, individual investors |
| **Decision** | Where to allocate capital in fractional offerings |
| **Metric** | Average ROI, ROI volatility, win rate, market alpha |

---

## 📊 Data Sources

| Table | Purpose |
|-------|---------|
| `nawy.SHARE_OFFERING` | Fractional offerings (one per property) |
| `nawy.PROPERTY` | Property details (title, city, type, developer) |
| `nawy.DEVELOPER` | Developer names and IDs |
| `nawy.SHARE_INVESTMENT` | Investor purchases of shares |
| `nawy.SHARE_EXIT` | Completed exits with profit/loss data |



---

## 🔬 Methodology

The query works in **three stages**:

### Stage 1 — Offering-Level ROI (`offering_roi` CTE)
For each offering, calculate:
- Number of exits (`exit_count`)
- Average ROI (`avg_roi_pct`)
- Average holding period (`avg_holding_days`)
- Total profit generated (`total_profit_egp`)

**Why**: Isolate property/offering behaviour before rolling up.

### Stage 2 — Developer Aggregation (`developer_stats` CTE)
Roll up all offerings by developer:
- Number of offerings with exits (sample size)
- Average ROI across offerings
- **Standard deviation** (volatility) — how consistent they are
- Best and worst case
- Count of offerings above 20% ROI
- Win rate

**Why**: This is the heart of the analysis. A developer with high average but huge swings is not the same as a consistent one.

### Stage 3 — Market Benchmark (`market_benchmark` CTE)
Calculate the market average ROI across all offerings.

**Why**: Enables **alpha** calculation — how much each developer beats or lags the overall market.

### Final SELECT
Combine all stages and assign a reliability grade.

---

## 🧾 SQL Query

```sql
-- Query: Developer Consistency Scorecard
-- Purpose : Rank developers by ROI consistency
-- Grain   : One row per developer
-- Filters : Only developers with 2+ exited offerings


USE NawyProptechDB;
GO

WITH offering_roi AS (
    SELECT
        so.offering_id,
        p.developer_id,
        p.title                                     AS property_title,
        p.city,
        p.property_type,
        COUNT(se.exit_id)                           AS exit_count,
        AVG(se.profit_loss * 100.0
            / NULLIF(si.total_amount, 0))           AS avg_roi_pct,
        AVG(CAST(DATEDIFF(DAY, si.investment_date, se.exit_date) AS FLOAT))
                                                    AS avg_holding_days,
        SUM(se.profit_loss)                         AS total_profit_egp
    FROM nawy.SHARE_OFFERING so
    INNER JOIN nawy.PROPERTY p
        ON so.property_id = p.property_id
    INNER JOIN nawy.SHARE_INVESTMENT si
        ON so.offering_id = si.offering_id
    INNER JOIN nawy.SHARE_EXIT se
        ON si.investment_id = se.investment_id
    WHERE se.exit_date IS NOT NULL
    GROUP BY so.offering_id, p.developer_id, p.title, p.city, p.property_type
),
developer_stats AS (
    SELECT
        d.developer_id,
        d.name                                      AS developer_name,
        COUNT(*)                                    AS offerings_with_exits,
        AVG(oroi.avg_roi_pct)                       AS dev_avg_roi,
        STDEV(oroi.avg_roi_pct)                     AS roi_volatility,
        MIN(oroi.avg_roi_pct)                       AS worst_offering_roi,
        MAX(oroi.avg_roi_pct)                       AS best_offering_roi,
        AVG(oroi.avg_holding_days)                  AS avg_holding_days,
        SUM(oroi.total_profit_egp)                  AS total_profit_egp,
        SUM(CASE WHEN oroi.avg_roi_pct >= 20 THEN 1 ELSE 0 END)
                                                    AS winners_count
    FROM offering_roi oroi
    INNER JOIN nawy.DEVELOPER d
        ON oroi.developer_id = d.developer_id
    GROUP BY d.developer_id, d.name
    HAVING COUNT(*) >= 2
),
market_benchmark AS (
    SELECT AVG(avg_roi_pct) AS market_avg_roi
    FROM offering_roi
)
SELECT
    ds.developer_name,
    ds.offerings_with_exits,
    CAST(ds.dev_avg_roi AS DECIMAL(10,2))           AS avg_roi_pct,
    CAST(ds.roi_volatility AS DECIMAL(10,2))        AS roi_volatility_pct,
    CAST(ds.worst_offering_roi AS DECIMAL(10,2))    AS worst_roi_pct,
    CAST(ds.best_offering_roi AS DECIMAL(10,2))     AS best_roi_pct,
    ds.winners_count                                AS offerings_above_20pct,
    CAST(ds.winners_count * 100.0
         / ds.offerings_with_exits AS DECIMAL(5,1)) AS win_rate_pct,
    CAST(ds.avg_holding_days AS DECIMAL(7,1))       AS avg_holding_days,
    CAST(ds.total_profit_egp AS DECIMAL(15,2))      AS total_profit_egp,
    CAST(ds.dev_avg_roi - mb.market_avg_roi AS DECIMAL(10,2))
                                                    AS market_alpha_pct,
    CASE
        WHEN ds.dev_avg_roi >= 30
             AND ds.roi_volatility < 15
             AND ds.winners_count >= 2 THEN 'A+ — Elite Consistent'
        WHEN ds.dev_avg_roi >= 20
             AND ds.winners_count >= 2 THEN 'A — Strong Track Record'
        WHEN ds.dev_avg_roi >= 10 THEN 'B — Decent'
        WHEN ds.dev_avg_roi >= 0 THEN 'C — Below Market'
        ELSE 'D — Underperformer'
    END                                             AS reliability_grade
FROM developer_stats ds
CROSS JOIN market_benchmark mb
ORDER BY ds.dev_avg_roi DESC;
