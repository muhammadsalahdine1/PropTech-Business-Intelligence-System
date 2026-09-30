USE NawyProptechDB;
GO

-- PART 1: PER-APPLICATION RISK SCORING
-- For each active mortgage (approved or disbursed), we compute:
--   - Borrower and property details
--   - Payment history (paid, overdue, pending)
--   - Risk category based on overdue count
--
-- Risk categories:
--   High Risk:     3+ overdue payments (potential default)
--   Medium Risk:   1-2 overdue payments (watch list)
--   Fully Current: all installments paid on time
--   Low Risk:      has pending future payments only

WITH mortgage_risk_scored AS (
    SELECT
        ma.application_id,
        ma.user_id,
        u.full_name                             AS borrower_name,
        ma.property_id,
        p.title                                 AS property_title,
        p.city,
        p.property_type,
        ma.property_price,
        ma.loan_amount,
        ma.down_payment,
        CAST(100.0 * ma.down_payment / ma.property_price AS DECIMAL(5,2)) AS down_payment_pct,
        ma.installment_months,
        ma.interest_rate,
        ma.monthly_payment,
        ma.status                                AS application_status,
        ma.submitted_at,
        ma.approved_at,

        -- Payment performance
        COUNT(mp.payment_id)                     AS total_installments,
        SUM(CASE WHEN mp.status = 'paid' THEN 1 ELSE 0 END)    AS paid_count,
        SUM(CASE WHEN mp.status = 'overdue' THEN 1 ELSE 0 END) AS overdue_count,
        SUM(CASE WHEN mp.status = 'pending' THEN 1 ELSE 0 END) AS pending_count,
        ISNULL(SUM(mp.amount_paid), 0)          AS total_collected

    FROM nawy.MORTGAGE_APPLICATION ma
    INNER JOIN nawy.[USER] u
        ON ma.user_id = u.user_id
    INNER JOIN nawy.PROPERTY p
        ON ma.property_id = p.property_id
    LEFT JOIN nawy.MORTGAGE_PAYMENT mp
        ON ma.application_id = mp.application_id
    WHERE ma.status IN ('approved','disbursed')
    GROUP BY
        ma.application_id,
        ma.user_id,
        u.full_name,
        ma.property_id,
        p.title,
        p.city,
        p.property_type,
        ma.property_price,
        ma.loan_amount,
        ma.down_payment,
        ma.installment_months,
        ma.interest_rate,
        ma.monthly_payment,
        ma.status,
        ma.submitted_at,
        ma.approved_at
)

SELECT
    application_id,
    borrower_name,
    property_title,
    city,
    property_type,
    CAST(property_price AS DECIMAL(15,2))       AS property_price,
    CAST(loan_amount AS DECIMAL(15,2))          AS loan_amount,
    down_payment_pct,
    installment_months,
    CAST(interest_rate * 100 AS DECIMAL(5,2))   AS interest_rate_pct,
    CAST(monthly_payment AS DECIMAL(12,2))      AS monthly_payment,
    total_installments,
    paid_count,
    overdue_count,
    pending_count,

    -- Payment completion rate
    CAST(
        CASE WHEN total_installments = 0 THEN 0
             ELSE 100.0 * paid_count / total_installments
        END AS DECIMAL(5,2)
    ) AS payment_completion_pct,

    -- Overdue rate
    CAST(
        CASE WHEN total_installments = 0 THEN 0
             ELSE 100.0 * overdue_count / total_installments
        END AS DECIMAL(5,2)
    ) AS overdue_rate_pct,

    -- Risk category
    CASE
        WHEN overdue_count >= 3 THEN 'High Risk'
        WHEN overdue_count >= 1 THEN 'Medium Risk'
        WHEN paid_count = total_installments THEN 'Fully Current'
        ELSE 'Low Risk'
    END AS risk_category

FROM mortgage_risk_scored
ORDER BY overdue_count DESC, payment_completion_pct ASC;

-- PART 2: DEFAULT RATE BY PROPERTY TYPE
-- Aggregated view of risk distribution across property types.
-- This drives underwriting policy decisions.

SELECT
    property_type,
    COUNT(*)                                    AS total_mortgages,
    SUM(CASE WHEN risk_category = 'High Risk' THEN 1 ELSE 0 END)   AS high_risk_count,
    SUM(CASE WHEN risk_category = 'Medium Risk' THEN 1 ELSE 0 END) AS medium_risk_count,
    CAST(
        100.0 * SUM(CASE WHEN risk_category = 'High Risk' THEN 1 ELSE 0 END)
             / COUNT(*) AS DECIMAL(5,2)
    ) AS high_risk_pct,
    CAST(AVG(loan_amount) AS DECIMAL(15,2))     AS avg_loan_amount,
    CAST(AVG(down_payment_pct) AS DECIMAL(5,2)) AS avg_down_payment_pct,
    CAST(AVG(installment_months) AS DECIMAL(6,2)) AS avg_term_months
FROM (
    SELECT
        ma.application_id,
        p.property_type,
        ma.loan_amount,
        CAST(100.0 * ma.down_payment / ma.property_price AS DECIMAL(5,2)) AS down_payment_pct,
        ma.installment_months,
        CASE
            WHEN SUM(CASE WHEN mp.status = 'overdue' THEN 1 ELSE 0 END) >= 3 THEN 'High Risk'
            WHEN SUM(CASE WHEN mp.status = 'overdue' THEN 1 ELSE 0 END) >= 1 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS risk_category
    FROM nawy.MORTGAGE_APPLICATION ma
    INNER JOIN nawy.PROPERTY p
        ON ma.property_id = p.property_id
    LEFT JOIN nawy.MORTGAGE_PAYMENT mp
        ON ma.application_id = mp.application_id
    WHERE ma.status IN ('approved','disbursed')
    GROUP BY
        ma.application_id,
        p.property_type,
        ma.loan_amount,
        ma.down_payment,
        ma.property_price,
        ma.installment_months
) sub
GROUP BY property_type
ORDER BY high_risk_pct DESC;