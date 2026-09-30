# Query 1 — Market Pricing Trends

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

---

## 🎯 Business Question

> **How are property prices trending by city and property type over the last 5 years, and which segments are appreciating fastest?**

---

## 💼 Business Context

### Why This Matters to Nawy

Nawy's profitability depends on identifying **high-appreciation markets before competitors do**. This query serves three critical business functions:

1. **Pricing Strategy** — Sales teams need current market rates per square meter to price listings competitively.
2. **Nawy Shares Selection** — The investment committee uses historical appreciation to select properties for fractional offerings.
3. **Developer Partnership Negotiation** — Nawy can negotiate better commission rates with developers whose projects appreciate consistently.

### Who Uses This Query

| Role | Purpose |
|------|---------|
| **Pricing Analyst** | Benchmark listings against market rates |
| **Nawy Shares Investment Committee** | Select high-growth properties for fractional offerings |
| **Developer Relations** | Rank developers by asset appreciation |
| **Executive Team** | Monthly market trend reporting |

### What "Good" Looks Like

| Appreciation | Classification | Action |
|--------------|----------------|--------|
| **> 20%/year** | Hot market | Prioritize inventory |
| **10–20%/year** | Healthy market | Standard operations |
| **5–10%/year** | Slow market | Reduce inventory exposure |
| **< 5%/year** | Stagnant market | Focus on liquidity, not appreciation |

---

## 🔍 The Query

```sql
-- Query 1: Market Pricing Trends (2021–2026)
-- Business Question:
--   How are property prices trending by city and property type
--   over the last 5 years, and which segments are appreciating
--   fastest?
--
-- Used By:
--   - Pricing team (benchmark listings)
--   - Nawy Shares investment committee (select offerings)
--   - Developer relations (rank partners)
--   - Executive team (monthly reporting)
--
-- Output:
--   Year-over-year price trends by city, property type, and
--   listing type, including YoY appreciation percentages.
--

USE NawyProptechDB;
GO

-- STEP 1: Aggregate yearly pricing metrics
-- For each year, city, property type, and listing type, we
-- compute:
--   - Number of listings (volume indicator)
--   - Average price (headline metric)
--   - Average price per square meter (comparable metric)
--   - Average area (context for price changes)
--
-- We filter out bad data:
--   - area_sqm > 0 (avoids divide-by-zero)
--   - price > 0 (avoids invalid listings)
--   - created_at >= 2021 (5-year window)

WITH yearly_pricing AS (
    SELECT
        YEAR(p.created_at)                      AS listing_year,
        p.city,
        p.property_type,
        p.listing_type,
        COUNT(*)                                AS listing_count,
        AVG(p.price)                            AS avg_price,
        AVG(p.price / NULLIF(p.area_sqm, 0))    AS avg_price_per_sqm,
        AVG(p.area_sqm)                         AS avg_area_sqm
    FROM nawy.PROPERTY p
    WHERE p.created_at >= '2021-01-01'
      AND p.area_sqm > 0
      AND p.price > 0
    GROUP BY
        YEAR(p.created_at),
        p.city,
        p.property_type,
        p.listing_type
),

-- STEP 2: Calculate year-over-year appreciation
-- LAG() retrieves the previous year's avg_price_per_sqm for
-- the same city/type/listing combination, enabling YoY
-- growth calculation.

yoy_growth AS (
    SELECT
        yp.*,
        LAG(yp.avg_price_per_sqm) OVER (
            PARTITION BY yp.city, yp.property_type, yp.listing_type
            ORDER BY yp.listing_year
        ) AS prev_year_price_per_sqm
    FROM yearly_pricing yp
)

-- STEP 3: Final output with YoY percentage
-- YoY appreciation formula:
--   (current - previous) / previous × 100
-- NULL for the first year (no previous data).

SELECT
    listing_year,
    city,
    property_type,
    listing_type,
    listing_count,
    CAST(avg_price AS DECIMAL(15,2))            AS avg_price_egp,
    CAST(avg_price_per_sqm AS DECIMAL(10,2))    AS avg_price_per_sqm_egp,
    CAST(avg_area_sqm AS DECIMAL(10,2))         AS avg_area_sqm,
    CAST(
        CASE
            WHEN prev_year_price_per_sqm IS NULL THEN NULL
            ELSE (avg_price_per_sqm - prev_year_price_per_sqm) * 100.0
                 / prev_year_price_per_sqm
        END AS DECIMAL(5,2)
    ) AS yoy_appreciation_pct
FROM yoy_growth
ORDER BY
    listing_year DESC,
    city,
    property_type,
    listing_type;
```

---

## 🔬 Code Walkthrough

### Section 1 — CTE: `yearly_pricing`

**Purpose**: Aggregate raw property data into yearly summaries.

| Line | What It Does | Why It Matters |
|------|--------------|----------------|
| `YEAR(p.created_at)` | Extracts the year | Groups data into yearly buckets |
| `COUNT(*)` | Counts listings | Volume indicator — more listings = active market |
| `AVG(p.price)` | Average price | Headline metric |
| `AVG(p.price / NULLIF(p.area_sqm, 0))` | Price per sqm | **Comparable metric** — normalizes for property size |
| `NULLIF(p.area_sqm, 0)` | Prevents divide-by-zero | Defensive coding |

**Why `price_per_sqm` matters**: A 200 sqm apartment at 4M EGP and a 100 sqm apartment at 2M EGP have the same price per sqm. This metric lets you compare properties of different sizes fairly.

---

### Section 2 — CTE: `yoy_growth`

**Purpose**: Add the previous year's price-per-sqm to each row.

**Key technique**: `LAG()` is a **window function** that looks back one row within a partition.

```sql
LAG(avg_price_per_sqm) OVER (
    PARTITION BY city, property_type, listing_type
    ORDER BY listing_year
)
```

This means:
- **Partition**: Group rows by same city + property type + listing type
- **Order by year**: Sort chronologically within each partition
- **LAG**: Take the value from the previous row

**Result**: For 2024's Cairo apartment primary listings, we get 2023's `avg_price_per_sqm` in `prev_year_price_per_sqm`.

---

### Section 3 — Final SELECT

**Purpose**: Calculate YoY percentage and format the output.

**YoY formula**:

```
(current_price - previous_price) / previous_price × 100
```

**Edge cases handled**:
- `prev_year_price_per_sqm IS NULL` → returns NULL (no previous year = no growth rate)
- `CAST(... AS DECIMAL)` → ensures clean decimal formatting

---

## 📊 Expected Output

### Sample Result Set

| listing_year | city | property_type | listing_type | listing_count | avg_price_egp | avg_price_per_sqm_egp | avg_area_sqm | yoy_appreciation_pct |
|--------------|------|---------------|--------------|---------------|---------------|----------------------|--------------|---------------------|
| 2026 | Cairo | apartment | primary | 45 | 6,850,000.00 | 21,420.00 | 320.50 | 18.45 |
| 2026 | North Coast | chalet | primary | 28 | 9,200,000.00 | 42,100.00 | 218.50 | 24.80 |
| 2025 | Cairo | apartment | primary | 52 | 5,780,000.00 | 18,085.00 | 319.60 | 15.20 |
| 2025 | New Administrative Capital | apartment | primary | 22 | 5,400,000.00 | 19,800.00 | 272.70 | 22.10 |
| 2024 | Cairo | villa | primary | 18 | 18,500,000.00 | 25,300.00 | 731.20 | 20.50 |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `listing_year` | INT | Year (2021–2026) |
| `city` | NVARCHAR | Cairo, Giza, Alexandria, North Coast, New Administrative Capital, Ain Sokhna, Red Sea, Luxor |
| `property_type` | NVARCHAR | apartment, villa, townhouse, office, chalet, duplex |
| `listing_type` | NVARCHAR | primary, resale, rental |
| `listing_count` | INT | Number of listings in that segment/year |
| `avg_price_egp` | DECIMAL | Average listing price in EGP |
| `avg_price_per_sqm_egp` | DECIMAL | Average price per square meter in EGP |
| `avg_area_sqm` | DECIMAL | Average area in square meters |
| `yoy_appreciation_pct` | DECIMAL | Year-over-year price-per-sqm growth rate |

---

## 📈 Interpretation Guide

### Thresholds

| YoY Appreciation | Market Classification | Action |
|------------------|----------------------|--------|
| **> 25%** | Hypergrowth | Aggressively acquire inventory; shortlist for Nawy Shares |
| **20–25%** | Hot | Prioritize inventory; standard Nawy Shares exposure |
| **15–20%** | Healthy | Standard operations |
| **10–15%** | Moderate | Monitor; reduce new inventory |
| **5–10%** | Slow | Focus on liquidity; minimize exposure |
| **< 5%** | Stagnant | Exit inventory; pivot to other markets |

### Pattern Examples

**North Coast chalets (summer market)**:
- Expect 30–40% appreciation spikes in 2023, 2025 (odd years have stronger summer demand)
- Winter listings show 10–15% discount

**New Administrative Capital apartments**:
- Highest growth in 2024–2026 due to government relocation
- Prices still 40% below Cairo premium districts (upside potential)

**Cairo villas in Sheikh Zayed**:
- Consistent 18–22% annual appreciation
- Premium tier holds value even in slow markets

### Red Flags

- **listing_count declining year-over-year** → Market cooling
- **yoy_appreciation_pct negative** → Market correction
- **avg_area_sqm increasing while price flat** → Buyers trading up, prices stagnating

---

## 💡 Analytical Extensions

### Extension 1 — Seasonality by Quarter

```sql
-- Add this to the CTE to see quarterly patterns
DATEPART(QUARTER, p.created_at) AS listing_quarter,
-- and add to GROUP BY
```

**Expected insight**: North Coast peaks in Q2–Q3 (summer), Cairo peaks in Q4 (year-end bonuses).

### Extension 2 — Top-Performing Compounds

```sql
-- Filter to top compounds
AND p.compound_name IN ('Villette', 'Marassi', 'Badya', 'Hyde Park', 'Allegria')
```

**Expected insight**: Nawy's premium developer partnerships (Palm Hills, SODIC, Emaar) show 5–10% premium over market average.

### Extension 3 — Correlation with Developer Tier

Join `DEVELOPER` and add `partnership_tier` to see if developer tier correlates with appreciation:

```sql
LEFT JOIN nawy.DEVELOPER d ON p.developer_id = d.developer_id
-- Then add d.partnership_tier to the GROUP BY
```

### Extension 4 — Visualize in Tableau

1. Connect Tableau to `NawyProptechDB`
2. Use the query as a **Custom SQL** data source
3. Create a **dual-axis line chart**:
   - Primary axis: `avg_price_per_sqm_egp` (line)
   - Secondary axis: `yoy_appreciation_pct` (bars)
4. Add filters: `city`, `property_type`, `listing_type`

---

## ⚡ Performance Notes

### Query Runtime

- **Expected**: 200–500 ms on 520 rows
- **Scales to**: ~2–3 seconds at 1M rows with proper indexes

### Relevant Indexes

```sql
CREATE INDEX IX_PROPERTY_created_at ON nawy.PROPERTY(created_at);
CREATE INDEX IX_PROPERTY_city_type ON nawy.PROPERTY(city, property_type);
```

### Optimization for Larger Datasets

If the `PROPERTY` table grows beyond 10M rows:

1. **Add a materialized summary table**:

```sql
CREATE TABLE nawy.mv_yearly_pricing AS
SELECT ... -- the CTE logic
```

2. **Refresh nightly via SQL Agent job**

3. **Query the summary** instead of raw `PROPERTY`

---
