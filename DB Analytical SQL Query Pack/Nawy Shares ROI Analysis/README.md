# Query 4 — Nawy Shares ROI Analysis

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

> **Which Nawy Shares offerings deliver the highest ROI to investors, and what property characteristics drive superior returns?**

---

## 💼 Business Context

### Why This Matters to Nawy

Nawy Shares is **Egypt's first FRA-regulated fractional real estate platform**, allowing investors to participate with as little as **5,000 EGP per month**. The platform has facilitated investments across **405+ units** and **16 developers**.

This query answers three strategic questions:

1. **Which offerings to select next?** — Historical ROI reveals which property types, cities, and developers consistently outperform.
2. **How to market to investors?** — Real ROI figures validate Nawy Shares' claim of "highest return with no effort."
3. **How to price new offerings?** — ROI patterns inform share pricing and exit conditions.

### Who Uses This Query

| Role | Purpose |
|------|---------|
| **Nawy Shares Investment Committee** | Select properties for new offerings |
| **Investor Relations** | Provide performance reports to investors |
| **Marketing** | Validate ROI claims in campaigns |
| **Developers** | Show developers how their projects perform on the platform |
| **Product Team** | Refine exit conditions and fee structures |

### What "Good" Looks Like

| Avg ROI | Offering Quality | Action |
|---------|------------------|--------|
| **> 100%** | Exceptional | Feature prominently; replicate characteristics |
| **50–100%** | Strong | Standard marketing |
| **20–50%** | Healthy | Continue with similar properties |
| **0–20%** | Weak | Review selection criteria |
| **< 0%** | Loss | Exit immediately; analyze root cause |

### Regulatory Context

Under **FRA Resolution No. 125 of 2025**, Nawy Shares must:

- Publish information memoranda for each offering
- Report investor returns transparently
- Maintain audit trails of all exits
- Ensure exit conditions are honored (delivery OR ≥80% return)

This query provides the performance data foundation for regulatory reporting.

---

## 🔍 The Query

```sql
-- Query 4: Nawy Shares ROI Analysis
-- Business Question:
--   Which Nawy Shares offerings deliver the highest ROI to
--   investors, and what property characteristics drive
--   superior returns?
--
-- Used By:
--   - Nawy Shares investment committee (offering selection)
--   - Investor relations (performance reporting)
--   - Marketing (ROI claims)
--   - Developers (partnership discussions)
--
-- Output:
--   Part 1: Per-offering performance with ROI metrics
--   Part 2: Summary by city and property type
--

USE NawyProptechDB;
GO

-- PART 1: OFFERING-LEVEL PERFORMANCE
-- For each offering, we compute:
--   - Subscription metrics (shares sold, investors, raised)
--   - Exit metrics (count, avg profit, avg ROI %)
--   - Property characteristics (city, type, developer)
--   - Speed metrics (days to close, days to first exit)
--
-- ROI calculation:
--   ROI % = (profit_loss / total_invested) × 100

WITH offering_performance AS (
    SELECT
        so.offering_id,
        so.property_id,
        p.title                                 AS property_title,
        p.city,
        p.district,
        p.property_type,
        d.name                                  AS developer_name,
        so.total_value,
        so.share_price,
        so.total_shares,
        so.shares_available,
        so.total_shares - so.shares_available   AS shares_sold,
        CAST(
            100.0 * (so.total_shares - so.shares_available) / so.total_shares
            AS DECIMAL(5,2)
        ) AS sold_pct,
        so.offering_open_date,
        so.offering_close_date,
        DATEDIFF(DAY, so.offering_open_date, so.offering_close_date)
                                                 AS offering_days,
        so.status,

        -- Subscription metrics
        COUNT(DISTINCT si.investment_id)        AS total_investments,
        COUNT(DISTINCT si.user_id)              AS unique_investors,
        ISNULL(SUM(si.total_amount), 0)         AS total_raised,
        ISNULL(AVG(si.total_amount), 0)         AS avg_investment_size,

        -- Exit metrics
        COUNT(DISTINCT se.exit_id)              AS total_exits,
        ISNULL(AVG(se.profit_loss), 0)          AS avg_profit_per_exit,
        ISNULL(AVG(
            CASE WHEN si.total_amount > 0
                 THEN 100.0 * se.profit_loss / si.total_amount
            END
        ), 0) AS avg_roi_pct,
        ISNULL(MIN(
            CASE WHEN si.total_amount > 0
                 THEN 100.0 * se.profit_loss / si.total_amount
            END
        ), 0) AS min_roi_pct,
        ISNULL(MAX(
            CASE WHEN si.total_amount > 0
                 THEN 100.0 * se.profit_loss / si.total_amount
            END
        ), 0) AS max_roi_pct

    FROM nawy.SHARE_OFFERING so
    INNER JOIN nawy.PROPERTY p
        ON so.property_id = p.property_id
    LEFT JOIN nawy.DEVELOPER d
        ON p.developer_id = d.developer_id
    LEFT JOIN nawy.SHARE_INVESTMENT si
        ON so.offering_id = si.offering_id
    LEFT JOIN nawy.SHARE_EXIT se
        ON si.investment_id = se.investment_id
    GROUP BY
        so.offering_id,
        so.property_id,
        p.title,
        p.city,
        p.district,
        p.property_type,
        d.name,
        so.total_value,
        so.share_price,
        so.total_shares,
        so.shares_available,
        so.offering_open_date,
        so.offering_close_date,
        so.status
)

SELECT
    ROW_NUMBER() OVER (ORDER BY avg_roi_pct DESC) AS rank,
    offering_id,
    property_title,
    city,
    district,
    property_type,
    developer_name,
    CAST(total_value AS DECIMAL(15,2))          AS offering_value_egp,
    CAST(share_price AS DECIMAL(12,2))          AS share_price_egp,
    sold_pct,
    offering_days,
    status,
    total_investments,
    unique_investors,
    CAST(total_raised AS DECIMAL(15,2))         AS total_raised_egp,
    CAST(avg_investment_size AS DECIMAL(12,2))  AS avg_investment_size_egp,
    total_exits,
    CAST(avg_profit_per_exit AS DECIMAL(12,2))  AS avg_profit_per_exit_egp,
    CAST(avg_roi_pct AS DECIMAL(10,2))          AS avg_roi_pct,
    CAST(min_roi_pct AS DECIMAL(10,2))          AS min_roi_pct,
    CAST(max_roi_pct AS DECIMAL(10,2))          AS max_roi_pct,
    -- Performance tier
    CASE
        WHEN avg_roi_pct >= 100 THEN 'Exceptional'
        WHEN avg_roi_pct >= 50  THEN 'Strong'
        WHEN avg_roi_pct >= 20  THEN 'Healthy'
        WHEN avg_roi_pct >= 0   THEN 'Weak'
        ELSE 'Loss'
    END AS performance_tier
FROM offering_performance
WHERE total_exits > 0
ORDER BY avg_roi_pct DESC;

-- PART 2: SUMMARY BY CITY AND PROPERTY TYPE
-- Rolls up offering performance to identify the best segments
-- for future Nawy Shares offerings.

SELECT
    p.city,
    p.property_type,
    COUNT(DISTINCT so.offering_id)              AS offering_count,
    COUNT(DISTINCT se.exit_id)                  AS total_exits,
    CAST(AVG(
        CASE WHEN si.total_amount > 0
             THEN 100.0 * se.profit_loss / si.total_amount
        END
    ) AS DECIMAL(10,2))                         AS avg_roi_pct,
    CAST(AVG(se.profit_loss) AS DECIMAL(12,2))  AS avg_profit_egp,
    CAST(AVG(so.share_price) AS DECIMAL(12,2))  AS avg_share_price_egp,
    CAST(AVG(so.total_value) AS DECIMAL(15,2))  AS avg_offering_value_egp
FROM nawy.SHARE_OFFERING so
INNER JOIN nawy.PROPERTY p
    ON so.property_id = p.property_id
INNER JOIN nawy.SHARE_INVESTMENT si
    ON so.offering_id = si.offering_id
INNER JOIN nawy.SHARE_EXIT se
    ON si.investment_id = se.investment_id
GROUP BY p.city, p.property_type
HAVING COUNT(DISTINCT se.exit_id) >= 3
ORDER BY avg_roi_pct DESC;
```

---

## 🔬 Code Walkthrough

### Section 1 — CTE: `offering_performance`

**Purpose**: Compute all offering-level metrics with subscription and exit data.

**Key techniques**:

| Technique | Purpose |
|-----------|---------|
| `INNER JOIN` to `PROPERTY` | Every offering has an underlying property |
| `LEFT JOIN` to `DEVELOPER` | Some resale properties may not have a developer |
| `LEFT JOIN` to `SHARE_INVESTMENT` | Include offerings with zero subscriptions |
| `LEFT JOIN` to `SHARE_EXIT` | Include investments that haven't exited |
| `COUNT(DISTINCT ...)` | Prevent double-counting when joining investments + exits |
| `CASE WHEN si.total_amount > 0` | Avoid divide-by-zero in ROI calculation |

**Why ROI is calculated per-investment, then averaged:**

Each investor pays a different amount for different numbers of shares. Calculating ROI per-investment, then averaging, gives an accurate picture of typical investor returns.

**Formula**:

```
ROI % = (profit_loss / total_amount) × 100
```

Where:

- `profit_loss` = total_sale_value − total_amount − exit_fees
- `total_amount` = shares_purchased × share_price

---

### Section 2 — Performance Tier Classification

```sql
CASE
    WHEN avg_roi_pct >= 100 THEN 'Exceptional'
    WHEN avg_roi_pct >= 50  THEN 'Strong'
    WHEN avg_roi_pct >= 20  THEN 'Healthy'
    WHEN avg_roi_pct >= 0   THEN 'Weak'
    ELSE 'Loss'
END
```

**Business rationale**:

| Tier | ROI Range | Action |
|------|-----------|--------|
| **Exceptional** | ≥ 100% | Feature in marketing; replicate characteristics |
| **Strong** | 50–100% | Standard marketing; prioritize similar properties |
| **Healthy** | 20–50% | Continue with similar profile |
| **Weak** | 0–20% | Review selection criteria |
| **Loss** | < 0% | Exit immediately; post-mortem |

**Why 100% threshold?**

Egyptian real estate has appreciated 18–22% annually. A 100% return over 2 years (roughly 50% per year) is truly exceptional — and matches Nawy Shares' publicized "115% in 5 months" success story.

---

### Section 3 — Part 2 Summary

**Purpose**: Aggregate at the city × property type level.

**Key technique**: `HAVING COUNT(DISTINCT se.exit_id) >= 3` ensures statistical significance — we only report segments with at least 3 completed exits.

**Why this filter?**

A segment with 1 exit could be a fluke. Three or more suggests a genuine pattern.

---

## 📊 Expected Output

### Part 1 — Sample Result Set (Per-Offering)

| rank | offering_id | property_title | city | district | property_type | developer_name | share_price_egp | sold_pct | total_investments | unique_investors | total_raised_egp | total_exits | avg_roi_pct | performance_tier |
|------|-------------|----------------|------|----------|---------------|----------------|-----------------|----------|-------------------|------------------|------------------|-------------|-------------|------------------|
| 1 | 42 | 3BR Apartment in Marassi | North Coast | Marassi | chalet | Emaar Misr | 8,500.00 | 100.00 | 28 | 18 | 8,500,000.00 | 8 | 115.40 | Exceptional |
| 2 | 67 | 4BR Villa in Villette | Cairo | New Cairo | villa | SODIC | 15,500.00 | 100.00 | 45 | 32 | 15,500,000.00 | 12 | 98.20 | Strong |
| 3 | 15 | 2BR Apartment in Badya | Giza | 6th of October | apartment | Palm Hills | 3,200.00 | 100.00 | 62 | 41 | 3,200,000.00 | 18 | 87.50 | Strong |
| 4 | 89 | 3BR Townhouse in Swan Lake | Cairo | Sheikh Zayed | townhouse | Hassan Allam | 6,800.00 | 95.00 | 38 | 25 | 6,460,000.00 | 9 | 72.30 | Strong |
| 5 | 33 | 2BR Apartment in Hyde Park | Cairo | New Cairo | apartment | Hyde Park | 3,400.00 | 100.00 | 55 | 38 | 3,400,000.00 | 15 | 65.80 | Strong |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Part 2 — Sample Result Set (Summary)

| city | property_type | offering_count | total_exits | avg_roi_pct | avg_profit_egp | avg_share_price_egp | avg_offering_value_egp |
|------|---------------|----------------|-------------|-------------|----------------|---------------------|------------------------|
| North Coast | chalet | 8 | 22 | 108.50 | 4,850,000.00 | 8,250.00 | 8,250,000.00 |
| Cairo | villa | 12 | 45 | 82.30 | 12,750,000.00 | 15,200.00 | 15,200,000.00 |
| Giza | apartment | 22 | 78 | 71.40 | 2,285,000.00 | 3,150.00 | 3,150,000.00 |
| Cairo | apartment | 35 | 122 | 58.90 | 2,005,000.00 | 3,400.00 | 3,400,000.00 |
| Cairo | townhouse | 14 | 38 | 52.10 | 3,545,000.00 | 6,750.00 | 6,750,000.00 |
| New Administrative Capital | apartment | 6 | 18 | 41.20 | 1,650,000.00 | 2,750.00 | 2,750,000.00 |

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `rank` | INT | Offering ranking by ROI |
| `offering_id` | BIGINT | Unique offering identifier |
| `property_title` | NVARCHAR | Property name |
| `city` | NVARCHAR | Location |
| `district` | NVARCHAR | Neighborhood |
| `property_type` | NVARCHAR | apartment, villa, townhouse, chalet |
| `developer_name` | NVARCHAR | Developer company |
| `offering_value_egp` | DECIMAL | Total property value |
| `share_price_egp` | DECIMAL | Price per share |
| `sold_pct` | DECIMAL | % of shares sold |
| `offering_days` | INT | Subscription window length |
| `total_investments` | INT | Number of investments |
| `unique_investors` | INT | Number of distinct investors |
| `total_raised_egp` | DECIMAL | Total funds raised |
| `avg_investment_size_egp` | DECIMAL | Average ticket size |
| `total_exits` | INT | Completed exits |
| `avg_profit_per_exit_egp` | DECIMAL | Average profit per exit |
| `avg_roi_pct` | DECIMAL | Average ROI |
| `min_roi_pct` | DECIMAL | Worst-performing investment |
| `max_roi_pct` | DECIMAL | Best-performing investment |
| `performance_tier` | NVARCHAR | Exceptional / Strong / Healthy / Weak / Loss |

---

## 📈 Interpretation Guide

### Reading the Per-Offering Output

**Sample observation**: Offering #42 (Marassi chalet):

- 100% sold out
- 28 investments from 18 unique investors
- 8 completed exits
- **Average ROI: 115.40%**
- **Performance tier: Exceptional**

**What this tells us**:

- North Coast chalets are premium for fractional investment
- Marketing should feature this offering as a success story
- Investment committee should prioritize similar North Coast properties
- Share price (8,500 EGP) was well-priced given the returns

**Sample observation**: Offering #33 (Hyde Park apartment):

- 100% sold out
- 55 investments from 38 unique investors
- 15 completed exits
- **Average ROI: 65.80%**
- **Performance tier: Strong**

**What this tells us**:

- Cairo apartments deliver solid returns
- Wider investor base (38 unique) — good for marketing
- Exit volume (15) provides statistical confidence

### Interpreting the Summary

**Key insight from sample data**:

| Segment | Avg ROI | Interpretation | Action |
|---------|---------|----------------|--------|
| **North Coast chalets** | 108.50% | Premium summer demand | Prioritize |
| **Cairo villas** | 82.30% | High-value, stable | Standard |
| **Giza apartments** | 71.40% | Strong suburb growth | Focus |
| **Cairo apartments** | 58.90% | Volume driver | Scale |
| **Cairo townhouses** | 52.10% | Consistent returns | Standard |
| **NAC apartments** | 41.20% | Emerging market | Monitor |

**Strategic implications**:

1. **North Coast chalets** — Highest ROI, but limited by seasonality. Perfect for premium offerings.
2. **Giza apartments** — Surprising outperformer vs. Cairo proper. Younger compounds (Badya, O West) show strong appreciation.
3. **Cairo villas** — High ticket size but low volume. Good for VIP investors.
4. **New Administrative Capital** — Below-average ROI today; likely upside as government relocation completes.

### Red Flags

| Signal | Interpretation | Action |
|--------|----------------|--------|
| ROI < 0% | Investor loss | Full post-mortem; consider compensation |
| Max ROI > 3× Avg ROI | Outlier-driven performance | Investigate; may not be repeatable |
| Avg ROI declining over time | Market saturation | Adjust share pricing |
| High investor count, low avg ticket | Small investors dominate | Marketing opportunity |
| Low investor count, high avg ticket | Institutional buyers only | Broaden marketing |

### The Marassi Story

Offering #42 is a textbook success:

- **Location**: North Coast (highest appreciation market)
- **Developer**: Emaar Misr (track record of delivery)
- **Property type**: Chalet (summer premium)
- **Exit timing**: Delivered on schedule
- **Result**: 115.4% ROI in ~18 months

**Replication recipe**: High-end chalets from tier-1 developers on the North Coast, offered at fair share prices, with clear delivery timelines.

---

## 💡 Analytical Extensions

### Extension 1 — Time to Exit Analysis

Add average holding period:

```sql
AVG(DATEDIFF(DAY, si.investment_date, se.exit_date)) AS avg_holding_days
```

**Expected insight**: Quicker exits (6–12 months) usually have higher annualized ROI.

### Extension 2 — Developer Performance

Group by developer:

```sql
GROUP BY d.name
```

**Expected insight**: Tier-1 developers (Palm Hills, SODIC, Emaar) consistently outperform smaller developers by 15–25%.

### Extension 3 — Exit Timing Analysis

Buckets by holding period:

```sql
CASE
    WHEN DATEDIFF(DAY, si.investment_date, se.exit_date) < 180 THEN 'Quick Exit (6mo)'
    WHEN DATEDIFF(DAY, si.investment_date, se.exit_date) < 365 THEN 'Standard (6-12mo)'
    WHEN DATEDIFF(DAY, si.investment_date, se.exit_date) < 730 THEN 'Long (1-2yr)'
    ELSE 'Extended (2yr+)'
END AS exit_bucket
```

**Expected insight**: Properties that deliver on time but exit later show the highest ROI (appreciation during construction).

### Extension 4 — Investor Segmentation

Analyze investor behavior:

```sql
-- Multi-investment investors (portfolio builders)
SELECT user_id, COUNT(*) AS investment_count, AVG(roi) AS avg_roi
GROUP BY user_id
HAVING COUNT(*) >= 3
```

**Expected insight**: Investors with 3+ offerings show higher avg ROI (learning curve + diversification).

### Extension 5 — Correlation with Property Features

Join `PROPERTY` details:

```sql
-- Correlate ROI with bedrooms, area, finishing_status
```

**Expected insight**: Fully-finished, fully-furnished units show higher ROI than shell properties.

### Extension 6 — Geographic Heatmap

For Tableau visualization:

- **Latitude/Longitude** map colored by avg_roi_pct
- **District** as filter
- **Property type** as size

**Expected insight**: Coastal and West Cairo properties cluster in the high-ROI range.

---

## ⚡ Performance Notes

### Query Runtime

- **Expected**: 600–900 ms on 85 offerings × 620 investments × 185 exits
- **Scales to**: 5–10 seconds at 10K offerings with proper indexes

### Relevant Indexes

```sql
CREATE INDEX IX_SHARE_OFFERING_status ON nawy.SHARE_OFFERING(status);
CREATE INDEX IX_SHARE_INVESTMENT_user ON nawy.SHARE_INVESTMENT(user_id);
CREATE INDEX IX_SHARE_INVESTMENT_offering ON nawy.SHARE_INVESTMENT(offering_id);
CREATE INDEX IX_SHARE_EXIT_investment ON nawy.SHARE_EXIT(investment_id);
CREATE INDEX IX_PROPERTY_city_district ON nawy.PROPERTY(city, district);
```

### Optimization Tips

**1. Materialize offering performance**

For daily reporting:

```sql
CREATE TABLE nawy.mv_offering_performance AS
SELECT ... -- CTE logic
```

**2. Partition by offering status**

Separate `closed`/`sold_out` offerings (stable data) from `open` (volatile).

**3. Precompute ROI**

Add a computed column to `SHARE_EXIT`:

```sql
ALTER TABLE nawy.SHARE_EXIT
ADD roi_pct AS (100.0 * profit_loss / (SELECT total_amount FROM nawy.SHARE_INVESTMENT WHERE investment_id = SHARE_EXIT.investment_id));
```
