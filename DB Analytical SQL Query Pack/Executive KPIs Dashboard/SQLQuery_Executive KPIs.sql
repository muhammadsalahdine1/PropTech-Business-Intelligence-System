USE NawyProptechDB;
GO

-- EXECUTIVE KPI DASHBOARD
-- Produces one row per KPI, organized by category.
-- Designed to feed a Tableau/Power BI "scorecard" visual.

DECLARE @as_of_date DATETIMEOFFSET(7) = SYSDATETIMEOFFSET();

SELECT
    category,
    kpi_name,
    kpi_value,
    formatted_value,
    @as_of_date AS as_of_date
FROM (
    -- 1. USER METRICS
    SELECT
        1 AS sort_order,
        '1. Users' AS category,
        'Total Users' AS kpi_name,
        CAST(COUNT(*) AS DECIMAL(18,2)) AS kpi_value,
        CAST(COUNT(*) AS NVARCHAR(50)) + ' users' AS formatted_value
    FROM nawy.[USER]

    UNION ALL
    SELECT 1, '1. Users', 'Verified Users',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' (' +
        CAST(CAST(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM nawy.[USER]), 0) AS DECIMAL(5,2)) AS NVARCHAR(10)) + '% verified)'
    FROM nawy.[USER] WHERE is_verified = 1

    UNION ALL
    SELECT 1, '1. Users', 'Active Brokers',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' brokers'
    FROM nawy.BROKER WHERE status = 'active'

    UNION ALL
    SELECT 1, '1. Users', 'Verified Tenants',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' tenants'
    FROM nawy.TENANT WHERE verification_status = 'verified'

    -- 2. PROPERTY METRICS
    UNION ALL
    SELECT 2, '2. Properties', 'Total Listings',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' listings'
    FROM nawy.PROPERTY

    UNION ALL
    SELECT 2, '2. Properties', 'Active Listings',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' active'
    FROM nawy.PROPERTY WHERE status = 'active'

    UNION ALL
    SELECT 2, '2. Properties', 'Properties Sold',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' sold'
    FROM nawy.PROPERTY WHERE status = 'sold'

    UNION ALL
    SELECT 2, '2. Properties', 'Properties Rented',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' rented'
    FROM nawy.PROPERTY WHERE status = 'rented'

    UNION ALL
    SELECT 2, '2. Properties', 'Total Inventory Value',
        CAST(ISNULL(SUM(price), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(price), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.PROPERTY WHERE status = 'active'

    UNION ALL
    SELECT 2, '2. Properties', 'Total Developers',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' developers'
    FROM nawy.DEVELOPER

    -- 3. SALES PIPELINE
    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Total Leads',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' leads'
    FROM nawy.LEAD

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Won Leads',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' won'
    FROM nawy.LEAD WHERE status = 'closed_won'

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Lead Conversion Rate',
        CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.LEAD) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.LEAD)
            END AS DECIMAL(10,2)
        ),
        CAST(CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.LEAD) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.LEAD)
            END AS DECIMAL(5,2)) AS NVARCHAR(10)) + '%'
    FROM nawy.LEAD WHERE status = 'closed_won'

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Completed Deals',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' deals'
    FROM nawy.DEAL WHERE status = 'completed'

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Total GMV',
        CAST(ISNULL(SUM(sale_price), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(sale_price), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.DEAL WHERE status = 'completed'

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Avg Deal Size',
        CAST(ISNULL(AVG(sale_price), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(AVG(sale_price), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.DEAL WHERE status = 'completed'

    UNION ALL
    SELECT 3, '3. Sales Pipeline', 'Commissions Paid',
        CAST(ISNULL(SUM(commission_amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(commission_amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.COMMISSION WHERE status = 'paid'

    -- 4. NAWY NOW (MORTGAGE)
    UNION ALL
    SELECT 4, '4. Nawy Now', 'Mortgage Applications',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' applications'
    FROM nawy.MORTGAGE_APPLICATION

    UNION ALL
    SELECT 4, '4. Nawy Now', 'Disbursed Mortgages',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' disbursed'
    FROM nawy.MORTGAGE_APPLICATION WHERE status = 'disbursed'

    UNION ALL
    SELECT 4, '4. Nawy Now', 'Mortgage Portfolio Value',
        CAST(ISNULL(SUM(loan_amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(loan_amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.MORTGAGE_APPLICATION WHERE status = 'disbursed'

    UNION ALL
    SELECT 4, '4. Nawy Now', 'Total Installments',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' payments'
    FROM nawy.MORTGAGE_PAYMENT

    UNION ALL
    SELECT 4, '4. Nawy Now', 'Overdue Installments',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' overdue'
    FROM nawy.MORTGAGE_PAYMENT WHERE status = 'overdue'

    UNION ALL
    SELECT 4, '4. Nawy Now', 'Portfolio Default Rate',
        CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.MORTGAGE_PAYMENT) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.MORTGAGE_PAYMENT)
            END AS DECIMAL(10,2)
        ),
        CAST(CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.MORTGAGE_PAYMENT) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.MORTGAGE_PAYMENT)
            END AS DECIMAL(5,2)) AS NVARCHAR(10)) + '%'
    FROM nawy.MORTGAGE_PAYMENT WHERE status = 'overdue'

    -- 5. NAWY SHARES (FRACTIONAL INVESTMENT)
    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Total Offerings',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' offerings'
    FROM nawy.SHARE_OFFERING

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Active Offerings',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' open'
    FROM nawy.SHARE_OFFERING WHERE status = 'open'

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Total Investments',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' investments'
    FROM nawy.SHARE_INVESTMENT

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Total Capital Raised',
        CAST(ISNULL(SUM(total_amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(total_amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.SHARE_INVESTMENT

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Unique Investors',
        CAST(COUNT(DISTINCT user_id) AS DECIMAL(18,2)),
        CAST(COUNT(DISTINCT user_id) AS NVARCHAR(50)) + ' investors'
    FROM nawy.SHARE_INVESTMENT

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Completed Exits',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' exits'
    FROM nawy.SHARE_EXIT WHERE status = 'completed'

    UNION ALL
    SELECT 5, '5. Nawy Shares', 'Average ROI %',
        CAST(ISNULL(AVG(
            CASE WHEN si.total_amount > 0
                 THEN 100.0 * se.profit_loss / si.total_amount
                 ELSE NULL END
        ), 0) AS DECIMAL(10,2)),
        CAST(CAST(ISNULL(AVG(
            CASE WHEN si.total_amount > 0
                 THEN 100.0 * se.profit_loss / si.total_amount
                 ELSE NULL END
        ), 0) AS DECIMAL(5,2)) AS NVARCHAR(10)) + '%'
    FROM nawy.SHARE_EXIT se
    INNER JOIN nawy.SHARE_INVESTMENT si ON se.investment_id = si.investment_id
    WHERE se.status = 'completed'

    -- 6. NAWY UNLOCKED (PROPERTY MANAGEMENT)
    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Management Contracts',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' contracts'
    FROM nawy.MANAGEMENT_CONTRACT

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Active Contracts',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' active'
    FROM nawy.MANAGEMENT_CONTRACT WHERE status = 'active'

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Total Leases',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' leases'
    FROM nawy.LEASE

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Active Leases',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' active'
    FROM nawy.LEASE WHERE status = 'active'

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Occupancy Rate',
        CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.LEASE) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.LEASE)
            END AS DECIMAL(10,2)
        ),
        CAST(CAST(
            CASE WHEN (SELECT COUNT(*) FROM nawy.LEASE) = 0 THEN 0
                 ELSE 100.0 * COUNT(*) / (SELECT COUNT(*) FROM nawy.LEASE)
            END AS DECIMAL(5,2)) AS NVARCHAR(10)) + '%'
    FROM nawy.LEASE WHERE status = 'active'

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Total Rent Collected',
        CAST(ISNULL(SUM(amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.RENT_PAYMENT WHERE status = 'paid'

    UNION ALL
    SELECT 6, '6. Nawy Unlocked', 'Finishing Projects',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' projects'
    FROM nawy.FINISHING_PROJECT

    -- 7. COMPLIANCE
    UNION ALL
    SELECT 7, '7. Compliance', 'Total Escrow Accounts',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' accounts'
    FROM nawy.ESCROW_ACCOUNT

    UNION ALL
    SELECT 7, '7. Compliance', 'Active Escrows',
        CAST(COUNT(*) AS DECIMAL(18,2)),
        CAST(COUNT(*) AS NVARCHAR(50)) + ' active'
    FROM nawy.ESCROW_ACCOUNT WHERE status = 'active'

    UNION ALL
    SELECT 7, '7. Compliance', 'Total Escrow Held',
        CAST(ISNULL(SUM(deposit_amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(deposit_amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.ESCROW_ACCOUNT WHERE status = 'active'

    -- 8. REVENUE BY BUSINESS LINE
    UNION ALL
    SELECT 8, '8. Revenue', 'Nawy Partners Revenue',
        CAST(ISNULL(SUM(commission_amount), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(commission_amount), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.COMMISSION WHERE status = 'paid'

    UNION ALL
    SELECT 8, '8. Revenue', 'Nawy Now Revenue (Est.)',
        CAST(ISNULL(SUM(loan_amount * ISNULL(interest_rate, 0)), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(loan_amount * ISNULL(interest_rate, 0)), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.MORTGAGE_APPLICATION WHERE status = 'disbursed'

    UNION ALL
    SELECT 8, '8. Revenue', 'Nawy Shares Revenue',
        CAST(ISNULL(SUM(total_sale_value * exit_fee_percent), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(total_sale_value * exit_fee_percent), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.SHARE_EXIT WHERE status = 'completed'

    UNION ALL
    SELECT 8, '8. Revenue', 'Nawy Unlocked Revenue',
        CAST(ISNULL(SUM(rp.amount * mc.management_fee_percent), 0) AS DECIMAL(18,2)),
        CAST(CAST(ISNULL(SUM(rp.amount * mc.management_fee_percent), 0) / 1000000.0 AS DECIMAL(18,2)) AS NVARCHAR(50)) + 'M EGP'
    FROM nawy.RENT_PAYMENT rp
    INNER JOIN nawy.LEASE l ON rp.lease_id = l.lease_id
    INNER JOIN nawy.MANAGEMENT_CONTRACT mc ON l.contract_id = mc.contract_id
    WHERE rp.status = 'paid'
) AS kpis
ORDER BY sort_order, kpi_name;
GO