USE NawyProptechDB;
GO

-- ============================================================
-- STEP 1: Aggregate yearly pricing metrics
-- ============================================================
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
-- ============================================================

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

-- ============================================================
-- STEP 2: Calculate year-over-year appreciation
-- ============================================================
-- LAG() retrieves the previous year's avg_price_per_sqm for
-- the same city/type/listing combination, enabling YoY
-- growth calculation.
-- ============================================================

yoy_growth AS (
    SELECT
        yp.*,
        LAG(yp.avg_price_per_sqm) OVER (
            PARTITION BY yp.city, yp.property_type, yp.listing_type
            ORDER BY yp.listing_year
        ) AS prev_year_price_per_sqm
    FROM yearly_pricing yp
)

-- ============================================================
-- STEP 3: Final output with YoY percentage
-- ============================================================
-- YoY appreciation formula:
--   (current - previous) / previous × 100
-- NULL for the first year (no previous data).
-- ============================================================

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