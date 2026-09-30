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