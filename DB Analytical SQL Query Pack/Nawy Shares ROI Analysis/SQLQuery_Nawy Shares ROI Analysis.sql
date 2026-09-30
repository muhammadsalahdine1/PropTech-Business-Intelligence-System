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