USE NawyProptechDB;
GO

-- ============================================================
-- PART 1: CONTRACT-LEVEL PERFORMANCE
-- ============================================================
-- For each management contract, compute:
--   - Property and owner details
--   - Contract service type and fee structure
--   - Lease metrics (total, active, expired)
--   - Rent payment metrics (collected, overdue, on-time rate)
--   - Occupancy rate and revenue generated
--
-- Metrics:
--   Occupancy rate = active leases / total leases × 100
--   On-time rate = paid payments / total payments × 100
-- ============================================================

WITH contract_performance AS (
    SELECT
        mc.contract_id,
        mc.property_id,
        p.title                                 AS property_title,
        p.city,
        p.district,
        p.compound_name,
        p.property_type,
        mc.owner_user_id,
        u.full_name                             AS owner_name,
        u.email                                 AS owner_email,
        mc.service_type,
        mc.management_fee_percent,
        mc.financing_percent,
        mc.contract_start,
        mc.contract_end,
        DATEDIFF(DAY, mc.contract_start,
                 ISNULL(mc.contract_end, SYSDATETIMEOFFSET())) AS contract_days,
        mc.status                               AS contract_status,

        -- Lease metrics
        COUNT(DISTINCT l.lease_id)              AS total_leases,
        SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END)     AS active_leases,
        SUM(CASE WHEN l.status = 'expired' THEN 1 ELSE 0 END)    AS expired_leases,
        SUM(CASE WHEN l.status = 'terminated' THEN 1 ELSE 0 END) AS terminated_leases,
        ISNULL(AVG(l.monthly_rent), 0)          AS avg_monthly_rent,

        -- Rent payment metrics
        COUNT(rp.rent_payment_id)               AS total_rent_payments,
        SUM(CASE WHEN rp.status = 'paid' THEN 1 ELSE 0 END)     AS paid_payments,
        SUM(CASE WHEN rp.status = 'overdue' THEN 1 ELSE 0 END)  AS overdue_payments,
        SUM(CASE WHEN rp.status = 'pending' THEN 1 ELSE 0 END)  AS pending_payments,
        ISNULL(SUM(CASE WHEN rp.status = 'paid'
                        THEN rp.amount ELSE 0 END), 0) AS total_rent_collected,

        -- Late payment severity
        ISNULL(AVG(CASE
            WHEN rp.paid_date IS NOT NULL AND rp.due_date IS NOT NULL
            THEN DATEDIFF(DAY, rp.due_date, rp.paid_date)
            ELSE NULL
        END), 0) AS avg_days_late

    FROM nawy.MANAGEMENT_CONTRACT mc
    INNER JOIN nawy.PROPERTY p
        ON mc.property_id = p.property_id
    INNER JOIN nawy.[USER] u
        ON mc.owner_user_id = u.user_id
    LEFT JOIN nawy.LEASE l
        ON mc.contract_id = l.contract_id
    LEFT JOIN nawy.RENT_PAYMENT rp
        ON l.lease_id = rp.lease_id
    GROUP BY
        mc.contract_id,
        mc.property_id,
        p.title,
        p.city,
        p.district,
        p.compound_name,
        p.property_type,
        mc.owner_user_id,
        u.full_name,
        u.email,
        mc.service_type,
        mc.management_fee_percent,
        mc.financing_percent,
        mc.contract_start,
        mc.contract_end,
        mc.status
)

SELECT
    contract_id,
    property_title,
    city,
    district,
    compound_name,
    property_type,
    owner_name,
    service_type,
    CAST(management_fee_percent * 100 AS DECIMAL(10,2)) AS management_fee_pct,
    CAST(financing_percent * 100 AS DECIMAL(10,2))      AS financing_pct,
    contract_days,
    contract_status,

    -- Lease metrics
    total_leases,
    active_leases,
    expired_leases,
    CAST(avg_monthly_rent AS DECIMAL(15,2))     AS avg_monthly_rent_egp,

    -- Rent payment metrics
    total_rent_payments,
    paid_payments,
    overdue_payments,
    CAST(total_rent_collected AS DECIMAL(18,2)) AS total_rent_collected_egp,

    -- Occupancy rate (0-100%)
    CAST(
        CASE WHEN total_leases = 0 THEN 0
             ELSE 100.0 * active_leases / total_leases
        END AS DECIMAL(10,2)
    ) AS occupancy_rate_pct,

    -- On-time payment rate (0-100%)
    CAST(
        CASE WHEN total_rent_payments = 0 THEN 0
             ELSE 100.0 * paid_payments / total_rent_payments
        END AS DECIMAL(10,2)
    ) AS on_time_payment_pct,

    -- Average days late (for late payers only)
    CAST(avg_days_late AS DECIMAL(10,2))        AS avg_days_late,

    -- Performance tier
    CASE
        WHEN total_leases = 0 THEN 'No Leases Yet'
        WHEN 100.0 * active_leases / total_leases >= 90
             AND 100.0 * paid_payments / NULLIF(total_rent_payments, 0) >= 95
            THEN 'Elite'
        WHEN 100.0 * active_leases / total_leases >= 75
            THEN 'Healthy'
        WHEN 100.0 * active_leases / total_leases >= 50
            THEN 'Underperforming'
        ELSE 'Vacant'
    END AS performance_tier

FROM contract_performance
ORDER BY
    CASE WHEN total_leases = 0 THEN 1 ELSE 0 END,
    occupancy_rate_pct DESC,
    total_rent_collected_egp DESC;
GO

-- ============================================================
-- PART 2: SUMMARY BY CITY AND SERVICE TYPE
-- ============================================================
-- Aggregate contract performance at the city × service level.
-- Weighted by lease and payment counts to avoid small-sample bias.
-- ============================================================

SELECT
    p.city,
    mc.service_type,
    COUNT(DISTINCT mc.contract_id)              AS total_contracts,
    SUM(CASE WHEN mc.status = 'active' THEN 1 ELSE 0 END) AS active_contracts,
    COUNT(DISTINCT l.lease_id)                  AS total_leases,
    SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END) AS active_leases,

    -- Weighted occupancy rate
    CAST(
        CASE WHEN COUNT(DISTINCT l.lease_id) = 0 THEN 0
             ELSE 100.0 * SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END)
                        / COUNT(DISTINCT l.lease_id)
        END AS DECIMAL(10,2)
    ) AS occupancy_rate_pct,

    -- Weighted on-time payment rate
    CAST(
        CASE WHEN COUNT(rp.rent_payment_id) = 0 THEN 0
             ELSE 100.0 * SUM(CASE WHEN rp.status = 'paid' THEN 1 ELSE 0 END)
                        / COUNT(rp.rent_payment_id)
        END AS DECIMAL(10,2)
    ) AS on_time_payment_pct,

    -- Financial metrics
    CAST(ISNULL(AVG(l.monthly_rent), 0) AS DECIMAL(15,2))  AS avg_monthly_rent_egp,
    CAST(ISNULL(SUM(CASE WHEN rp.status = 'paid'
                        THEN rp.amount ELSE 0 END), 0) AS DECIMAL(18,2)) AS total_rent_collected_egp,

    -- Estimated Nawy revenue (management fee portion)
    CAST(ISNULL(SUM(CASE WHEN rp.status = 'paid'
                        THEN rp.amount * mc.management_fee_percent
                        ELSE 0 END), 0) AS DECIMAL(18,2)) AS estimated_nawy_revenue_egp

FROM nawy.MANAGEMENT_CONTRACT mc
INNER JOIN nawy.PROPERTY p
    ON mc.property_id = p.property_id
LEFT JOIN nawy.LEASE l
    ON mc.contract_id = l.contract_id
LEFT JOIN nawy.RENT_PAYMENT rp
    ON l.lease_id = rp.lease_id
WHERE mc.status IN ('active', 'expired', 'terminated')
GROUP BY p.city, mc.service_type
HAVING COUNT(DISTINCT mc.contract_id) >= 3
ORDER BY occupancy_rate_pct DESC, total_rent_collected_egp DESC;
GO