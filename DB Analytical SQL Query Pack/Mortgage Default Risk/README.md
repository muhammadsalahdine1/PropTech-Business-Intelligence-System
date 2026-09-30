# Query 3 — Mortgage Default Risk

> **Analytical SQL Query for Nawy Proptech Platform**

## 📖 Table of Contents

- [Business Question](#-business-question)
- [Business Context](#-business-context)
- [The Query](#-the-query)
- [Code Walkthrough](#-code-walkthrough)
- [Expected Output](#-expected-output)
- [Interpretation Guide](#-interpretation-guide)
- [Analytical Extensions](#-analytical-extensions)
- [Performance Notes](#-performance-notes)



## 🎯 Business Question

> **What is the mortgage default rate on Nawy Now, and which borrower segments or property types carry the highest risk?**

---

## 💼 Business Context

### Why This Matters to Nawy

Nawy Now is a **FRA-licensed mortgage originator** (License No. 25, issued 2024) that holds mortgages on its balance sheet before securitizing them. Default risk directly impacts:

1. **Portfolio Valuation** — Each defaulted loan costs Nawy 40–60% of the outstanding balance (after recovery).
2. **Securitization Pricing** — Nawy has securitized EGP 443M in mortgages; higher default rates raise the cost of capital.
3. **Capital Reserve Requirements** — Under FRA rules, Nawy must hold reserves proportional to portfolio risk.
4. **Underwriting Policy** — Historical default patterns inform down payment minimums, interest rates, and approval criteria.

### Who Uses This Query

| Role | Purpose |
|------|---------|
| **Nawy Now Risk Team** | Monitor portfolio health daily |
| **Securitization Partners** | Assess pool quality before purchase |
| **Executive Team** | Board-level reporting on credit risk |
| **Underwriting** | Adjust approval criteria based on segment performance |
| **Collections** | Prioritize high-risk loans for intervention |

### What "Good" Looks Like

| Default Rate | Portfolio Health | Action |
|--------------|------------------|--------|
| **< 3%** | Excellent | Maintain current underwriting |
| **3–5%** | Healthy | Standard monitoring |
| **5–8%** | Elevated | Review underwriting criteria |
| **8–12%** | High | Tighten down payment requirements |
| **> 12%** | Critical | Immediate policy overhaul |

### Regulatory Context

Under **FRA Resolution No. 125 of 2025**, Nawy Now must:

- Classify each loan by risk category (performing, watch-list, substandard, doubtful, loss)
- Report default rates monthly
- Maintain minimum capital reserves based on risk-weighted assets

This query provides the data foundation for those reports.

---

## 🔍 The Query

```sql
-- Query 3: Mortgage Default Risk Analysis
-- Business Question:
--   What is the mortgage default rate on Nawy Now, and which
--   borrower segments or property types carry the highest risk?
--
-- Used By:
--   - Nawy Now risk team (daily monitoring)
--   - Securitization partners (pool quality assessment)
--   - Executive team (board reporting)
--   - Underwriting (approval criteria tuning)
--   - Collections (prioritization)
--
-- Output:
--   Per-application risk metrics plus summary by property type.
--


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
```

---

## 🔬 Code Walkthrough

### Section 1 — CTE: `mortgage_risk_scored`

**Purpose**: Compute per-application risk metrics with payment history.

**Key techniques**:

| Technique | Purpose |
|-----------|---------|
| `INNER JOIN` to `USER`, `PROPERTY` | Filter to valid applications only |
| `LEFT JOIN` to `MORTGAGE_PAYMENT` | Include applications with no payments yet |
| `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` | Conditional counting — counts only overdue rows |
| `ma.status IN ('approved','disbursed')` | Only active loans; exclude rejected/submitted |
| `GROUP BY` on all non-aggregated columns | SQL Server requirement |

**Why LEFT JOIN on payments?**

A freshly disbursed mortgage may have zero payments generated yet. LEFT JOIN keeps it in the result with 0 counts.

**Why filter `approved` AND `disbursed`?**

- `submitted` and `under_review` — not yet credit risk
- `rejected` — no loan originated
- `approved` — approved but not yet funded; still counts as potential default
- `disbursed` — funded; full credit risk

---

### Section 2 — Risk Category Logic

```sql
CASE
    WHEN overdue_count >= 3 THEN 'High Risk'
    WHEN overdue_count >= 1 THEN 'Medium Risk'
    WHEN paid_count = total_installments THEN 'Fully Current'
    ELSE 'Low Risk'
END
```

**Business rationale**:

| Category | Rule | Action |
|----------|------|--------|
| **High Risk** | 3+ overdue | Trigger default procedure; escalate to collections |
| **Medium Risk** | 1–2 overdue | Watch list; monitor closely |
| **Fully Current** | All payments on time | Standard servicing |
| **Low Risk** | Has pending future payments, no overdue | Standard servicing |

**Why 3+ overdue = High Risk?**

This mirrors industry practice. FRA guidelines and Egyptian mortgage norms treat **3 consecutive missed payments** as default trigger. It's the threshold at which:
- Legal action can begin
- Loan loss provisions must be booked
- Securitization pools flag the asset

---

### Section 3 — Summary by Property Type

**Purpose**: Aggregate risk by asset class to inform underwriting.

**Key techniques**:

| Technique | Purpose |
|-----------|---------|
| Subquery `sub` | Pre-compute risk category at the application level |
| Outer `GROUP BY property_type` | Roll up to property type |
| `SUM(CASE ...)` | Count high-risk and medium-risk separately |

**Why compute risk in a subquery first?**

You can't use a window function or a CASE based on aggregate results directly in the same `GROUP BY`. By computing risk per application in the subquery, the outer query can aggregate cleanly.

---

## 📊 Expected Output

### Part 1 — Sample Result Set (Per-Application)

| application_id | borrower_name | property_title | city | property_type | loan_amount | down_payment_pct | interest_rate_pct | total_installments | paid_count | overdue_count | payment_completion_pct | risk_category |
|----------------|---------------|----------------|------|---------------|-------------|------------------|-------------------|--------------------|-----------|---------------|-----------------------|---------------|
| 45 | Sara Adel | 3BR Apartment in Villette | Cairo | apartment | 4,930,000 | 15.00 | 16.50 | 84 | 12 | 5 | 14.29 | High Risk |
| 78 | Omar Fathy | 4BR Villa in Allegria | Cairo | villa | 14,450,000 | 15.00 | 14.00 | 120 | 8 | 4 | 6.67 | High Risk |
| 112 | Nour El-Sayed | 2BR Apartment in Badya | Giza | apartment | 2,720,000 | 15.00 | 18.00 | 60 | 22 | 3 | 36.67 | High Risk |
| 201 | Khaled Mansour | 3BR Townhouse in Swan Lake | Cairo | townhouse | 6,375,000 | 15.00 | 15.00 | 84 | 18 | 2 | 21.43 | Medium Risk |
| 234 | Menna Ayman | 2BR Apartment in Hyde Park | Cairo | apartment | 3,400,000 | 15.00 | 17.00 | 120 | 35 | 1 | 29.17 | Medium Risk |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Part 2 — Sample Result Set (Summary)

| property_type | total_mortgages | high_risk_count | medium_risk_count | high_risk_pct | avg_loan_amount | avg_down_payment_pct | avg_term_months |
|---------------|-----------------|-----------------|-------------------|---------------|-----------------|----------------------|-----------------|
| office | 12 | 3 | 2 | 25.00 | 3,850,000.00 | 15.00 | 84.00 |
| chalet | 18 | 3 | 4 | 16.67 | 4,250,000.00 | 15.00 | 96.00 |
| apartment | 145 | 14 | 22 | 9.66 | 3,600,000.00 | 15.00 | 78.00 |
| townhouse | 38 | 3 | 5 | 7.89 | 6,200,000.00 | 15.00 | 102.00 |
| duplex | 22 | 1 | 3 | 4.55 | 5,800,000.00 | 15.00 | 90.00 |
| villa | 45 | 2 | 4 | 4.44 | 12,500,000.00 | 15.00 | 108.00 |

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `application_id` | BIGINT | Unique mortgage ID |
| `borrower_name` | NVARCHAR | Applicant's full name |
| `property_title` | NVARCHAR | Property being financed |
| `city` | NVARCHAR | Property location |
| `property_type` | NVARCHAR | apartment, villa, townhouse, office, chalet, duplex |
| `property_price` | DECIMAL | Full property price |
| `loan_amount` | DECIMAL | Financed amount |
| `down_payment_pct` | DECIMAL | Down payment percentage |
| `installment_months` | INT | Loan term in months |
| `interest_rate_pct` | DECIMAL | Annual interest rate |
| `monthly_payment` | DECIMAL | Fixed monthly installment |
| `total_installments` | INT | Total scheduled payments |
| `paid_count` | INT | Installments paid |
| `overdue_count` | INT | Installments overdue |
| `pending_count` | INT | Future installments |
| `payment_completion_pct` | DECIMAL | Percentage paid |
| `overdue_rate_pct` | DECIMAL | Percentage overdue |
| `risk_category` | NVARCHAR | High Risk / Medium Risk / Low Risk / Fully Current |

---

## 📈 Interpretation Guide

### Reading the Per-Application Output

**Sample observation**: Application #45 (Sara Adel) shows:

- 12 paid out of 84 total installments
- 5 overdue → **High Risk**
- Payment completion: 14.29%

**What this tells us**:
- The borrower is only 1 year into a 7-year loan
- She's already missed 5 payments
- **Action**: Escalate to collections; consider restructuring or repossession

**Sample observation**: Application #234 (Menna Ayman):

- 35 paid out of 120
- 1 overdue → **Medium Risk**
- Payment completion: 29.17%

**What this tells us**:
- She's a consistent payer (only 1 miss)
- Likely a temporary delay
- **Action**: Send reminder; monitor next 2 payments

### Interpreting the Summary

**Key insight from sample data**:

| Property Type | High-Risk % | Interpretation |
|---------------|-------------|----------------|
| **office** | 25.00% | **Highest risk** — commercial loans are volatile |
| **chalet** | 16.67% | Seasonal income → seasonal payment issues |
| **apartment** | 9.66% | Largest segment; average risk |
| **townhouse** | 7.89% | Moderate risk |
| **duplex** | 4.55% | Lower risk |
| **villa** | 4.44% | **Lowest risk** — high-net-worth borrowers |

**Strategic implications**:

1. **Office mortgages**: Raise down payment to 20% or require business income verification
2. **Chalet mortgages**: Offer seasonal payment plans (pause in winter)
3. **Villa mortgages**: Best risk profile — expand this segment
4. **Apartment mortgages**: Largest volume — even small improvement in default rate has massive impact

### Red Flags

| Signal | Interpretation | Action |
|--------|----------------|--------|
| High Risk > 15% in any segment | Underwriting failure in that segment | Immediate review |
| Medium Risk growing 20%+ QoQ | Emerging default wave | Preemptive collections |
| Down payment < 15% correlates with default | Insufficient borrower skin-in-game | Raise minimum |
| Long term (120mo) + High Risk | Payment fatigue over long horizon | Consider shorter terms |
| Short term (36mo) + High Risk | Borrower overcommitted | Affordability check failed |

---

## 💡 Analytical Extensions

### Extension 1 — Default Rate by Borrower Segment

Join `TENANT` for income and employment data:

```sql
LEFT JOIN nawy.TENANT t ON ma.user_id = t.user_id
-- Then GROUP BY t.employment_status
```

**Expected insight**: Self-employed borrowers show 2–3× default rate vs. salaried.

### Extension 2 — Vintage Analysis

Group defaults by origination cohort:

```sql
YEAR(ma.approved_at) AS origination_year
-- Then GROUP BY origination_year
```

**Expected insight**: 2023 vintages may show higher defaults due to EGP devaluation.

### Extension 3 — Rolling 6-Month Default Trend

Calculate month-over-month default rate:

```sql
YEAR(mp.due_date) AS year,
MONTH(mp.due_date) AS month,
100.0 * SUM(CASE WHEN mp.status = 'overdue' THEN 1 ELSE 0 END)
      / COUNT(*) AS monthly_overdue_pct
-- GROUP BY year, month
-- ORDER BY year, month
```

**Expected insight**: Default spikes in specific months (post-Ramadan, summer).

### Extension 4 — Roll Rate Analysis

Track how Medium Risk applications migrate to High Risk over time:

```sql
-- Snapshot risk category monthly
-- Track transitions: Medium → High (roll rate)
```

**Expected insight**: Roll rate of 20–30% means Medium Risk is a leading indicator.

### Extension 5 — Geographic Risk Concentration

Add city-level aggregation:

```sql
GROUP BY city, property_type
```

**Expected insight**: Certain cities/compounds have cluster defaults — usually a sign of developer delays.

### Extension 6 — Visualize in Tableau

1. Connect Tableau to `NawyProptechDB`
2. Use the query as a **Custom SQL** data source
3. Build:
   - **Bar chart**: Default % by property type
   - **Scatter plot**: `down_payment_pct` vs `overdue_count` (correlation check)
   - **Heatmap**: City × Property Type by default rate
   - **Waterfall**: Portfolio movement from Current → Watch → High Risk

---

## ⚡ Performance Notes

### Query Runtime

- **Expected**: 500–900 ms on 280 applications × ~4,200 payments
- **Scales to**: 3–5 seconds at 50K applications with proper indexes

### Relevant Indexes

```sql
CREATE INDEX IX_MORTGAGE_status ON nawy.MORTGAGE_APPLICATION(status);
CREATE INDEX IX_MORTGAGE_user ON nawy.MORTGAGE_APPLICATION(user_id);
CREATE INDEX IX_MORTGAGE_property ON nawy.MORTGAGE_APPLICATION(property_id);
CREATE INDEX IX_MORTGAGE_PAYMENT_status_due ON nawy.MORTGAGE_PAYMENT(status, due_date);
```

### Optimization Tips

**1. Partition payments by year**

If `MORTGAGE_PAYMENT` grows beyond 10M rows:

```sql
CREATE PARTITION FUNCTION pf_year (DATE) AS RANGE RIGHT FOR VALUES
    ('2022-01-01','2023-01-01','2024-01-01','2025-01-01','2026-01-01');
```

**2. Pre-aggregate risk scores**

Create a nightly materialized view:

```sql
CREATE TABLE nawy.mv_mortgage_risk AS
SELECT ... -- CTE logic
```

**3. Add computed column**

For fast filtering:

```sql
ALTER TABLE nawy.MORTGAGE_PAYMENT
ADD days_overdue AS DATEDIFF(DAY, due_date, ISNULL(paid_date, GETDATE()));
```
