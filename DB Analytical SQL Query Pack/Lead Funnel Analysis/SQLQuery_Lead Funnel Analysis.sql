USE NawyProptechDB;
GO

-- PART 1: FUNNEL STAGE METRICS
-- Compute total leads reaching each stage, plus end-to-end
-- and stage-to-stage conversion rates.
--
-- Since a lead's `status` reflects its current stage, we
-- count leads that reached each stage as those currently IN
-- that stage OR any stage AFTER it (funnel progression
-- assumes leads move forward).

WITH funnel_stages AS (
    SELECT
        COUNT(*)                                                AS total_leads,

        SUM(CASE WHEN status IN ('new','contacted','viewing','negotiation','closed_won','closed_lost')
                 THEN 1 ELSE 0 END)                             AS reached_new,
        SUM(CASE WHEN status IN ('contacted','viewing','negotiation','closed_won','closed_lost')
                 THEN 1 ELSE 0 END)                             AS reached_contacted,
        SUM(CASE WHEN status IN ('viewing','negotiation','closed_won','closed_lost')
                 THEN 1 ELSE 0 END)                             AS reached_viewing,
        SUM(CASE WHEN status IN ('negotiation','closed_won','closed_lost')
                 THEN 1 ELSE 0 END)                             AS reached_negotiation,
        SUM(CASE WHEN status = 'closed_won'
                 THEN 1 ELSE 0 END)                             AS reached_closed_won,
        SUM(CASE WHEN status = 'closed_lost'
                 THEN 1 ELSE 0 END)                             AS reached_closed_lost,

        -- Currently in each stage
        SUM(CASE WHEN status = 'new' THEN 1 ELSE 0 END)         AS currently_new,
        SUM(CASE WHEN status = 'contacted' THEN 1 ELSE 0 END)   AS currently_contacted,
        SUM(CASE WHEN status = 'viewing' THEN 1 ELSE 0 END)     AS currently_viewing,
        SUM(CASE WHEN status = 'negotiation' THEN 1 ELSE 0 END) AS currently_negotiation,
        SUM(CASE WHEN status = 'closed_won' THEN 1 ELSE 0 END)  AS currently_closed_won,
        SUM(CASE WHEN status = 'closed_lost' THEN 1 ELSE 0 END) AS currently_closed_lost
    FROM nawy.LEAD
)
SELECT
    '1. New'            AS funnel_stage,
    reached_new         AS leads_reached,
    CAST(100.0 AS DECIMAL(10,2)) AS conversion_from_previous_pct,
    CAST(100.0 * reached_new / NULLIF(total_leads, 0) AS DECIMAL(10,2)) AS conversion_from_start_pct,
    currently_new       AS currently_in_stage,
    total_leads         AS total_leads
FROM funnel_stages
UNION ALL
SELECT
    '2. Contacted',
    reached_contacted,
    CAST(100.0 * reached_contacted / NULLIF(reached_new, 0) AS DECIMAL(10,2)),
    CAST(100.0 * reached_contacted / NULLIF(total_leads, 0) AS DECIMAL(10,2)),
    currently_contacted,
    total_leads
FROM funnel_stages
UNION ALL
SELECT
    '3. Viewing',
    reached_viewing,
    CAST(100.0 * reached_viewing / NULLIF(reached_contacted, 0) AS DECIMAL(10,2)),
    CAST(100.0 * reached_viewing / NULLIF(total_leads, 0) AS DECIMAL(10,2)),
    currently_viewing,
    total_leads
FROM funnel_stages
UNION ALL
SELECT
    '4. Negotiation',
    reached_negotiation,
    CAST(100.0 * reached_negotiation / NULLIF(reached_viewing, 0) AS DECIMAL(10,2)),
    CAST(100.0 * reached_negotiation / NULLIF(total_leads, 0) AS DECIMAL(10,2)),
    currently_negotiation,
    total_leads
FROM funnel_stages
UNION ALL
SELECT
    '5. Closed Won',
    reached_closed_won,
    CAST(100.0 * reached_closed_won / NULLIF(reached_negotiation, 0) AS DECIMAL(10,2)),
    CAST(100.0 * reached_closed_won / NULLIF(total_leads, 0) AS DECIMAL(10,2)),
    currently_closed_won,
    total_leads
FROM funnel_stages
UNION ALL
SELECT
    '6. Closed Lost (attrition)',
    reached_closed_lost,
    CAST(100.0 * reached_closed_lost / NULLIF(reached_negotiation, 0) AS DECIMAL(10,2)),
    CAST(100.0 * reached_closed_lost / NULLIF(total_leads, 0) AS DECIMAL(10,2)),
    currently_closed_lost,
    total_leads
FROM funnel_stages;
GO

-- PART 2: LEAD SOURCE PERFORMANCE
-- Which acquisition channels convert best and fastest?
-- This directly informs marketing budget allocation.

SELECT
    ISNULL(source, 'unknown')                       AS lead_source,
    COUNT(*)                                        AS total_leads,
    SUM(CASE WHEN status = 'closed_won' THEN 1 ELSE 0 END)  AS won_leads,
    SUM(CASE WHEN status = 'closed_lost' THEN 1 ELSE 0 END) AS lost_leads,
    SUM(CASE WHEN status NOT IN ('closed_won','closed_lost')
             THEN 1 ELSE 0 END)                     AS still_open,

    -- Conversion rate
    CAST(
        100.0 * SUM(CASE WHEN status = 'closed_won' THEN 1 ELSE 0 END)
              / NULLIF(COUNT(*), 0) AS DECIMAL(10,2)
    ) AS conversion_pct,

    -- Average days to close (for won leads)
    CAST(
        AVG(CASE WHEN status = 'closed_won'
                 AND last_activity_at IS NOT NULL
                 THEN DATEDIFF(DAY, created_at, last_activity_at)
                 ELSE NULL END) AS DECIMAL(10,2)
    ) AS avg_days_to_close,

    -- Deal value proxy (via linked deals)
    ISNULL((
        SELECT SUM(d.sale_price)
        FROM nawy.DEAL d
        INNER JOIN nawy.LEAD l2 ON d.lead_id = l2.lead_id
        WHERE l2.source = l.source
          AND d.status = 'completed'
    ), 0) AS total_won_value_egp

FROM nawy.LEAD l
GROUP BY source
ORDER BY conversion_pct DESC, total_leads DESC;
GO

-- PART 3: BROKER PERFORMANCE IN FUNNEL
-- Does having an assigned broker improve conversion?
-- This is the single most actionable metric for sales ops.

WITH broker_attribution AS (
    SELECT
        CASE
            WHEN broker_id IS NULL THEN 'Unassigned'
            ELSE 'Broker-Assigned'
        END AS assignment_type,
        COUNT(*)                                        AS total_leads,
        SUM(CASE WHEN status = 'closed_won' THEN 1 ELSE 0 END)  AS won_leads,
        SUM(CASE WHEN status = 'closed_lost' THEN 1 ELSE 0 END) AS lost_leads,
        SUM(CASE WHEN status NOT IN ('closed_won','closed_lost')
                 THEN 1 ELSE 0 END)                     AS still_open
    FROM nawy.LEAD
    GROUP BY
        CASE
            WHEN broker_id IS NULL THEN 'Unassigned'
            ELSE 'Broker-Assigned'
        END
)
SELECT
    assignment_type,
    total_leads,
    won_leads,
    lost_leads,
    still_open,
    CAST(
        100.0 * won_leads / NULLIF(total_leads, 0) AS DECIMAL(10,2)
    ) AS conversion_pct,
    CAST(
        100.0 * lost_leads / NULLIF(total_leads, 0) AS DECIMAL(10,2)
    ) AS attrition_pct
FROM broker_attribution
ORDER BY conversion_pct DESC;
GO

-- PART 4: TOP BROKERS IN THE FUNNEL
-- Which specific brokers convert best? Ranked by conversion
-- rate (with min volume threshold to avoid small-sample bias).

SELECT TOP 20
    b.broker_id,
    u.full_name                                     AS broker_name,
    b.broker_type,
    b.agency_name,
    COUNT(l.lead_id)                                AS total_leads,
    SUM(CASE WHEN l.status = 'closed_won' THEN 1 ELSE 0 END)  AS won_leads,
    SUM(CASE WHEN l.status = 'closed_lost' THEN 1 ELSE 0 END) AS lost_leads,

    CAST(
        100.0 * SUM(CASE WHEN l.status = 'closed_won' THEN 1 ELSE 0 END)
              / NULLIF(COUNT(l.lead_id), 0) AS DECIMAL(10,2)
    ) AS conversion_pct,

    -- Value delivered
    ISNULL(SUM(d.sale_price), 0)                    AS total_gmv_egp,

    -- Ranking tier
    CASE
        WHEN 100.0 * SUM(CASE WHEN l.status = 'closed_won' THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(l.lead_id), 0) >= 30 THEN 'Elite Closer'
        WHEN 100.0 * SUM(CASE WHEN l.status = 'closed_won' THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(l.lead_id), 0) >= 20 THEN 'Strong'
        WHEN 100.0 * SUM(CASE WHEN l.status = 'closed_won' THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(l.lead_id), 0) >= 10 THEN 'Healthy'
        ELSE 'Needs Coaching'
    END AS performance_tier

FROM nawy.BROKER b
INNER JOIN nawy.[USER] u ON b.user_id = u.user_id
INNER JOIN nawy.LEAD l ON b.broker_id = l.broker_id
LEFT JOIN nawy.DEAL d ON l.lead_id = d.lead_id AND d.status = 'completed'
WHERE b.status = 'active'
GROUP BY
    b.broker_id,
    u.full_name,
    b.broker_type,
    b.agency_name
HAVING COUNT(l.lead_id) >= 5
ORDER BY conversion_pct DESC, total_leads DESC;
GO

-- PART 5: FUNNEL VELOCITY (TIME ANALYSIS)
-- How long does it take to move through each stage? This
-- reveals bottlenecks in the sales process.

SELECT
    'Days to close (won leads)' AS metric,
    CAST(
        AVG(DATEDIFF(DAY, created_at, last_activity_at)) AS DECIMAL(10,2)
    ) AS avg_days,
    CAST(
        MIN(DATEDIFF(DAY, created_at, last_activity_at)) AS DECIMAL(10,2)
    ) AS min_days,
    CAST(
        MAX(DATEDIFF(DAY, created_at, last_activity_at)) AS DECIMAL(10,2)
    ) AS max_days,
    COUNT(*) AS sample_size
FROM nawy.LEAD
WHERE status = 'closed_won'
  AND last_activity_at IS NOT NULL
UNION ALL
SELECT
    'Days to close (lost leads)',
    CAST(AVG(DATEDIFF(DAY, created_at, last_activity_at)) AS DECIMAL(10,2)),
    CAST(MIN(DATEDIFF(DAY, created_at, last_activity_at)) AS DECIMAL(10,2)),
    CAST(MAX(DATEDIFF(DAY, created_at, last_activity_at)) AS DECIMAL(10,2)),
    COUNT(*)
FROM nawy.LEAD
WHERE status = 'closed_lost'
  AND last_activity_at IS NOT NULL
UNION ALL
SELECT
    'Days since creation (open leads)',
    CAST(AVG(DATEDIFF(DAY, created_at, SYSDATETIMEOFFSET())) AS DECIMAL(10,2)),
    CAST(MIN(DATEDIFF(DAY, created_at, SYSDATETIMEOFFSET())) AS DECIMAL(10,2)),
    CAST(MAX(DATEDIFF(DAY, created_at, SYSDATETIMEOFFSET())) AS DECIMAL(10,2)),
    COUNT(*)
FROM nawy.LEAD
WHERE status NOT IN ('closed_won','closed_lost');
GO