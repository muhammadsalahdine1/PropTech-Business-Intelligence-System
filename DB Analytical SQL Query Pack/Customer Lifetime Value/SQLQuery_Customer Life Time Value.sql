USE NawyProptechDB;
GO

-- PART 1: PER-USER REVENUE BREAKDOWN
-- For each user, compute revenue from four business lines:
--   1. Nawy Partners  → commission from deals as buyer
--   2. Nawy Now       → mortgage interest revenue
--   3. Nawy Shares    → exit fee revenue
--   4. Nawy Unlocked  → management fee revenue
--
-- Users with zero revenue across all lines are excluded.

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

    -- CLV tier classification
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
GO

-- PART 2: SUMMARY BY CLV TIER
-- Rolls up per-user CLV into segment-level statistics.
-- Uses a CTE to compute tier first, then aggregate cleanly.

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
),
user_with_tier AS (
    SELECT
        user_id,
        total_clv,
        CASE
            WHEN total_clv >= 1000000 THEN 'VIP'
            WHEN total_clv >= 100000  THEN 'High Value'
            WHEN total_clv >= 10000   THEN 'Standard'
            WHEN total_clv > 0        THEN 'Low Value'
            ELSE 'No Revenue'
        END AS clv_tier
    FROM user_clv
)

SELECT
    clv_tier,
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
FROM user_with_tier
GROUP BY clv_tier
ORDER BY
    CASE clv_tier
        WHEN 'VIP'        THEN 1
        WHEN 'High Value' THEN 2
        WHEN 'Standard'   THEN 3
        WHEN 'Low Value'  THEN 4
        ELSE 5
    END;
GO