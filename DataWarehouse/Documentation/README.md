# Nawy Proptech Platform — Dimensional Model Documentation



## 🎯 Introduction

### What Is This Document?

This is the **authoritative dimensional modeling reference** for the Nawy Proptech data warehouse. It documents:

- Every dimension table (structure, grain, attributes)
- Every fact table (grain, measures, dimensions)
- The relationships between them (the bus matrix)
- Design decisions and why they were made
- Standards for extending the model




## 🔍 Query Examples

### Example 1 — Sales Dashboard

```sql
-- Total GMV by month and city
SELECT
    d.year_month,
    g.city,
    SUM(f.gmv_egp) AS total_gmv,
    COUNT(f.deal_key) AS deal_count,
    SUM(f.gmv_egp) / COUNT(f.deal_key) AS avg_deal_size
FROM nawy_dw.FactDeal f
JOIN nawy_dw.DimDate d ON f.closed_date_key = d.date_key
JOIN nawy_dw.DimProperty p ON f.property_key = p.property_key AND p.is_current = 1
JOIN nawy_dw.DimGeography g ON p.geography_key = g.geography_key
WHERE d.year = 2026
GROUP BY d.year_month, g.city
ORDER BY d.year_month, total_gmv DESC;
```

### Example 2 — CLV by User

```sql
-- Total lifetime value per user across all business lines
SELECT
    u.user_key,
    u.full_name,
    u.clv_tier,
    SUM(r.revenue_amount_egp) AS total_revenue
FROM nawy_dw.DimUser u
JOIN nawy_dw.FactRevenue r ON u.user_key = r.user_key
WHERE u.is_current = 1
GROUP BY u.user_key, u.full_name, u.clv_tier
ORDER BY total_revenue DESC;
```

### Example 3 — Funnel Analysis

```sql
-- Conversion rates by source
SELECT
    f.source,
    COUNT(*) AS total_leads,
    SUM(f.is_won_flag) AS won,
    SUM(f.is_lost_flag) AS lost,
    CAST(100.0 * SUM(f.is_won_flag) / COUNT(*) AS DECIMAL(5,2)) AS conversion_pct
FROM nawy_dw.FactLead f
GROUP BY f.source
ORDER BY conversion_pct DESC;
```

### Example 4 — SCD Type 2 History

```sql
-- Full history of a specific property's price changes
SELECT
    p.property_key,
    p.current_price_egp,
    p.current_status,
    p.valid_from,
    p.valid_to,
    p.is_current
FROM nawy_dw.DimProperty p
WHERE p.property_id = 42
ORDER BY p.valid_from;
```

### Example 5 — Accumulating Snapshot

```sql
-- Mortgage application process durations
SELECT
    AVG(DATEDIFF(DAY,
        d_submitted.date,
        d_approved.date)) AS avg_days_to_approval,
    COUNT(*) AS total_applications
FROM nawy_dw.FactMortgageApplication f
JOIN nawy_dw.DimDate d_submitted ON f.submitted_date_key = d_submitted.date_key
JOIN nawy_dw.DimDate d_approved ON f.approved_date_key = d_approved.date_key
WHERE f.is_approved_flag = 1;
```

### Example 6 — Role-Playing Dimension

```sql
-- Rent payments received early vs late
SELECT
    CASE
        WHEN d_paid.date < d_due.date THEN 'Early'
        WHEN d_paid.date = d_due.date THEN 'On Time'
        ELSE 'Late'
    END AS payment_timing,
    COUNT(*) AS payment_count,
    SUM(f.amount_egp) AS total_amount
FROM nawy_dw.FactRentPayment f
JOIN nawy_dw.DimDate d_due ON f.due_date_key = d_due.date_key
LEFT JOIN nawy_dw.DimDate d_paid ON f.paid_date_key = d_paid.date_key
WHERE f.is_paid_flag = 1
GROUP BY
    CASE
        WHEN d_paid.date < d_due.date THEN 'Early'
        WHEN d_paid.date = d_due.date THEN 'On Time'
        ELSE 'Late'
    END;
```

---
