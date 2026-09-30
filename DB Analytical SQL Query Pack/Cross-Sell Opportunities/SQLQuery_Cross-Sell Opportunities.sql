USE NawyProptechDB;
GO

-- PART 1: USER ENGAGEMENT SEGMENTATION
-- Classify all users into engagement tiers based on how many
-- business lines they've used. This provides the population
-- distribution for cross-sell analysis.

WITH user_engagement AS (
    SELECT
        u.user_id,
        u.full_name,
        u.email,
        u.user_type,

        -- Engagement flags (1 = engaged, 0 = not)
        CASE WHEN EXISTS (SELECT 1 FROM nawy.LEAD l
                          WHERE l.buyer_user_id = u.user_id) THEN 1 ELSE 0 END
            AS engaged_properties,

        CASE WHEN EXISTS (SELECT 1 FROM nawy.DEAL d
                          WHERE d.buyer_user_id = u.user_id
                            AND d.status = 'completed') THEN 1 ELSE 0 END
            AS engaged_deals,

        CASE WHEN EXISTS (SELECT 1 FROM nawy.MORTGAGE_APPLICATION ma
                          WHERE ma.user_id = u.user_id
                            AND ma.status IN ('approved','disbursed')) THEN 1 ELSE 0 END
            AS engaged_nawy_now,

        CASE WHEN EXISTS (SELECT 1 FROM nawy.SHARE_INVESTMENT si
                          WHERE si.user_id = u.user_id) THEN 1 ELSE 0 END
            AS engaged_nawy_shares,

        CASE WHEN EXISTS (SELECT 1 FROM nawy.MANAGEMENT_CONTRACT mc
                          WHERE mc.owner_user_id = u.user_id
                            AND mc.status = 'active') THEN 1 ELSE 0 END
            AS engaged_nawy_unlocked,

        CASE WHEN EXISTS (SELECT 1 FROM nawy.TENANT t
                          WHERE t.user_id = u.user_id) THEN 1 ELSE 0 END
            AS is_tenant
    FROM nawy.[USER] u
),
engagement_summary AS (
    SELECT
        *,
        (engaged_properties + engaged_deals + engaged_nawy_now +
         engaged_nawy_shares + engaged_nawy_unlocked) AS lines_count
    FROM user_engagement
)
SELECT
    CASE
        WHEN lines_count >= 4 THEN 'Highly Engaged (4+ lines)'
        WHEN lines_count = 3  THEN 'Multi-Line (3 lines)'
        WHEN lines_count = 2  THEN 'Cross-Sell Success (2 lines)'
        WHEN lines_count = 1  THEN 'Single-Line'
        ELSE 'Unengaged'
    END AS engagement_segment,
    COUNT(*)                                    AS user_count,
    CAST(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)
    ) AS population_pct,
    SUM(engaged_properties)                     AS total_property_engagement,
    SUM(engaged_deals)                          AS total_deal_engagement,
    SUM(engaged_nawy_now)                       AS total_mortgage_engagement,
    SUM(engaged_nawy_shares)                    AS total_shares_engagement,
    SUM(engaged_nawy_unlocked)                  AS total_unlocked_engagement
FROM engagement_summary
GROUP BY
    CASE
        WHEN lines_count >= 4 THEN 'Highly Engaged (4+ lines)'
        WHEN lines_count = 3  THEN 'Multi-Line (3 lines)'
        WHEN lines_count = 2  THEN 'Cross-Sell Success (2 lines)'
        WHEN lines_count = 1  THEN 'Single-Line'
        ELSE 'Unengaged'
    END
ORDER BY
    CASE
        WHEN COUNT(*) = 0 THEN 0
        ELSE 1
    END DESC,
    CASE MIN(lines_count)
        WHEN 0 THEN 5
        WHEN 1 THEN 4
        WHEN 2 THEN 3
        WHEN 3 THEN 2
        ELSE 1
    END;
GO

-- PART 2: PRIORITIZED CROSS-SELL TARGETS
-- For each single-line user, identify the best next service
-- based on their existing engagement and typical cross-sell
-- patterns.
--
-- Targeting logic:
--   - Property buyers without investment → Nawy Shares
--   - Property sellers without management → Nawy Unlocked
--   - Cash buyers → Nawy Now (mortgage for next purchase)
--   - High-value buyers → Nawy Shares (fractional portfolio)

SELECT TOP 100
    u.user_id,
    u.full_name,
    u.email,
    u.user_type,
    u.created_at,
    DATEDIFF(DAY, u.created_at, SYSDATETIMEOFFSET()) AS days_on_platform,

    -- Current engagement
    (SELECT COUNT(*) FROM nawy.LEAD l WHERE l.buyer_user_id = u.user_id) AS lead_count,
    (SELECT COUNT(*) FROM nawy.DEAL d WHERE d.buyer_user_id = u.user_id
        AND d.status = 'completed') AS completed_deals,

    -- Recommended next service
    CASE
        WHEN EXISTS (SELECT 1 FROM nawy.DEAL d
                     WHERE d.buyer_user_id = u.user_id
                       AND d.status = 'completed')
             AND NOT EXISTS (SELECT 1 FROM nawy.SHARE_INVESTMENT si
                             WHERE si.user_id = u.user_id)
            THEN 'Nawy Shares'
        WHEN EXISTS (SELECT 1 FROM nawy.LEAD l
                     WHERE l.buyer_user_id = u.user_id)
             AND NOT EXISTS (SELECT 1 FROM nawy.MORTGAGE_APPLICATION ma
                             WHERE ma.user_id = u.user_id)
            THEN 'Nawy Now'
        WHEN u.user_type = 'seller'
             AND NOT EXISTS (SELECT 1 FROM nawy.MANAGEMENT_CONTRACT mc
                             WHERE mc.owner_user_id = u.user_id)
            THEN 'Nawy Unlocked'
        ELSE 'Nawy Shares'
    END AS recommended_next_service,

    -- Reason for the recommendation
    CASE
        WHEN EXISTS (SELECT 1 FROM nawy.DEAL d
                     WHERE d.buyer_user_id = u.user_id
                       AND d.status = 'completed')
             AND NOT EXISTS (SELECT 1 FROM nawy.SHARE_INVESTMENT si
                             WHERE si.user_id = u.user_id)
            THEN 'Has property buying history but no investment portfolio'
        WHEN EXISTS (SELECT 1 FROM nawy.LEAD l
                     WHERE l.buyer_user_id = u.user_id)
             AND NOT EXISTS (SELECT 1 FROM nawy.MORTGAGE_APPLICATION ma
                             WHERE ma.user_id = u.user_id)
            THEN 'Active property interest but no financing application'
        WHEN u.user_type = 'seller'
             AND NOT EXISTS (SELECT 1 FROM nawy.MANAGEMENT_CONTRACT mc
                             WHERE mc.owner_user_id = u.user_id)
            THEN 'Seller with no property management engagement'
        ELSE 'Low engagement — priority for activation campaign'
    END AS recommendation_reason

FROM nawy.[USER] u
WHERE
    -- Single-line users only
    (CASE WHEN EXISTS (SELECT 1 FROM nawy.LEAD l WHERE l.buyer_user_id = u.user_id) THEN 1 ELSE 0 END +
     CASE WHEN EXISTS (SELECT 1 FROM nawy.DEAL d WHERE d.buyer_user_id = u.user_id AND d.status = 'completed') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS (SELECT 1 FROM nawy.MORTGAGE_APPLICATION ma WHERE ma.user_id = u.user_id AND ma.status IN ('approved','disbursed')) THEN 1 ELSE 0 END +
     CASE WHEN EXISTS (SELECT 1 FROM nawy.SHARE_INVESTMENT si WHERE si.user_id = u.user_id) THEN 1 ELSE 0 END +
     CASE WHEN EXISTS (SELECT 1 FROM nawy.MANAGEMENT_CONTRACT mc WHERE mc.owner_user_id = u.user_id AND mc.status = 'active') THEN 1 ELSE 0 END) = 1
    -- Must have some activity (not just registered)
    AND u.user_type IN ('buyer', 'seller', 'investor')
ORDER BY
    -- Prioritize by existing engagement depth
    (SELECT COUNT(*) FROM nawy.LEAD l WHERE l.buyer_user_id = u.user_id) DESC,
    (SELECT COUNT(*) FROM nawy.DEAL d WHERE d.buyer_user_id = u.user_id
        AND d.status = 'completed') DESC,
    u.created_at ASC;
GO

-- PART 3: CROSS-SELL PAIR ANALYSIS
-- Which business line combinations occur most frequently?
-- This reveals natural product affinities.

WITH user_pairs AS (
    SELECT
        u.user_id,
        CASE WHEN EXISTS (SELECT 1 FROM nawy.LEAD l
                          WHERE l.buyer_user_id = u.user_id)
             OR EXISTS (SELECT 1 FROM nawy.DEAL d
                        WHERE d.buyer_user_id = u.user_id)
             THEN 1 ELSE 0 END AS has_property,
        CASE WHEN EXISTS (SELECT 1 FROM nawy.MORTGAGE_APPLICATION ma
                          WHERE ma.user_id = u.user_id
                            AND ma.status IN ('approved','disbursed'))
             THEN 1 ELSE 0 END AS has_mortgage,
        CASE WHEN EXISTS (SELECT 1 FROM nawy.SHARE_INVESTMENT si
                          WHERE si.user_id = u.user_id)
             THEN 1 ELSE 0 END AS has_shares,
        CASE WHEN EXISTS (SELECT 1 FROM nawy.MANAGEMENT_CONTRACT mc
                          WHERE mc.owner_user_id = u.user_id
                            AND mc.status = 'active')
             THEN 1 ELSE 0 END AS has_unlocked
    FROM nawy.[USER] u
),
pair_combinations AS (
    SELECT
        has_property,
        has_mortgage,
        has_shares,
        has_unlocked,
        COUNT(*) AS user_count
    FROM user_pairs
    WHERE (has_property + has_mortgage + has_shares + has_unlocked) >= 2
    GROUP BY has_property, has_mortgage, has_shares, has_unlocked
)
SELECT
    -- Human-readable combination label
    STUFF(
        CASE WHEN has_property = 1 THEN ', Properties' ELSE '' END +
        CASE WHEN has_mortgage = 1 THEN ', Now' ELSE '' END +
        CASE WHEN has_shares = 1 THEN ', Shares' ELSE '' END +
        CASE WHEN has_unlocked = 1 THEN ', Unlocked' ELSE '' END,
        1, 2, ''
    ) AS service_combination,
    user_count,
    CAST(
        100.0 * user_count / SUM(user_count) OVER () AS DECIMAL(10,2)
    ) AS pair_share_pct
FROM pair_combinations
ORDER BY user_count DESC;
GO