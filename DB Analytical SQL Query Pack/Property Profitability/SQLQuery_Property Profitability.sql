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