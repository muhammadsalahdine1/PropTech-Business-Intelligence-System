# Query 9 — Lead Funnel Analysis

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

> **How efficiently does Nawy convert leads to deals, where do prospects drop off in the funnel, and which lead sources and brokers drive the best conversion?**

---

## 💼 Business Context

### Why This Matters to Nawy

Lead funnel optimization is Nawy's **most direct path to revenue growth**. A 1-percentage-point improvement in lead-to-deal conversion across 1,400 leads translates to **~14 additional deals per year** — worth **~50M EGP in GMV** and **~1.25M EGP in commissions**.

This query answers five operational questions:

1. **Where do leads drop off?** — Identifies the weakest stage
2. **Which sources convert best?** — Guides marketing spend allocation
3. **How fast is the funnel?** — Time-to-close impacts cash flow
4. **Do brokers matter?** — Quantifies the broker-attribution effect
5. **What's the geographic pattern?** — Where to invest in sales capacity

### The Nawy Lead Funnel

Leads progress through **6 stages**:

| Stage | Description | Typical Duration |
|-------|-------------|------------------|
| **1. new** | Just submitted inquiry | 0–2 days |
| **2. contacted** | Broker made first contact | 1–7 days |
| **3. viewing** | Buyer toured the property | 3–14 days |
| **4. negotiation** | Discussing price/terms | 7–30 days |
| **5. closed_won** | Deal signed | 30–90 days |
| **6. closed_lost** | Deal fell through | varies |

**Industry benchmark** (real estate):

- New → Contacted: 80–90%
- Contacted → Viewing: 40–60%
- Viewing → Negotiation: 30–50%
- Negotiation → Closed Won: 50–70%
- **End-to-end conversion**: 8–15%

### Who Uses This Query

| Role | Purpose |
|------|---------|
| **Sales Operations** | Weekly funnel review |
| **Marketing** | Allocate budget by source ROI |
| **Broker Enablement** | Coach underperformers |
| **Executive Team** | Report on pipeline health |
| **Product Team** | Improve lead capture UX |

### What "Good" Looks Like

| Metric | Benchmark | Elite |
|--------|-----------|-------|
| **Lead-to-Deal Conversion** | 10–15% | > 20% |
| **Avg Days to Close** | 45–75 days | < 45 days |
| **Contact Rate (New → Contacted)** | 85% | > 95% |
| **Broker-Handled Conversion** | 18–25% | > 30% |
| **Website Lead Conversion** | 8–12% | > 15% |

---

## 🔍 The Query

```sql
-- Query 9: Lead Funnel Analysis
-- Business Question:
--   How efficiently does Nawy convert leads to deals, where
--   do prospects drop off in the funnel, and which lead
--   sources and brokers drive the best conversion?
--
-- Used By:
--   - Sales operations (weekly funnel review)
--   - Marketing (source ROI)
--   - Broker enablement (coaching)
--   - Executive team (pipeline health)
--
-- Output:
--   Part 1: Funnel stage metrics (conversion at each stage)
--   Part 2: Performance by lead source
--   Part 3: Performance by assigned broker
--   Part 4: Funnel velocity (time in each stage)
--

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
```

---

## 🔬 Code Walkthrough

### Section 1 — Part 1: Funnel Stage Metrics

**Purpose**: Show how many leads reached each stage and conversion rates.

**Key technique — Cumulative Stage Counting**:

A lead currently in `negotiation` must have passed through `new` → `contacted` → `viewing` → `negotiation`. So we count it in every stage up to its current one.

```sql
SUM(CASE WHEN status IN ('contacted','viewing','negotiation','closed_won','closed_lost')
         THEN 1 ELSE 0 END) AS reached_contacted
```

**Why this matters**: Without cumulative counting, you'd only see the snapshot of leads currently IN each stage — not the funnel flow.

**Key metrics**:

- **conversion_from_previous_pct**: Stage-to-stage efficiency (e.g., New → Contacted = 88%)
- **conversion_from_start_pct**: End-to-end funnel view (e.g., New → Won = 14%)

---

### Section 2 — Part 2: Source Performance

**Purpose**: Rank acquisition channels by conversion rate and speed.

**Key technique — Conditional aggregation**:

```sql
SUM(CASE WHEN status = 'closed_won' THEN 1 ELSE 0 END) AS won_leads,
SUM(CASE WHEN status = 'closed_lost' THEN 1 ELSE 0 END) AS lost_leads,
SUM(CASE WHEN status NOT IN ('closed_won','closed_lost') THEN 1 ELSE 0 END) AS still_open
```

**Why three buckets?**

Leads fall into three states:

- **Won**: successfully converted
- **Lost**: attrition
- **Open**: still in pipeline (no decision yet)

Segregating them lets you compute conversion rate accurately (won / total, not won / decided).

**Key metric — avg_days_to_close**:

```sql
AVG(CASE WHEN status = 'closed_won' AND last_activity_at IS NOT NULL
         THEN DATEDIFF(DAY, created_at, last_activity_at)
         ELSE NULL END)
```

**Business meaning**: Website leads might close in 30 days; broker_referral in 15 days. Faster closers = better cash flow.

---

### Section 3 — Part 3: Broker Attribution

**Purpose**: Answer the question "Do assigned brokers improve conversion?"

**Key technique — Bucket-based aggregation**:

```sql
CASE WHEN broker_id IS NULL THEN 'Unassigned'
     ELSE 'Broker-Assigned' END AS assignment_type
```

**Why this is the most actionable metric**:

If Broker-Assigned converts at 22% and Unassigned at 6%, then Nawy should:

- Assign brokers to every lead within 24 hours
- Hire more brokers to handle lead volume
- Pay brokers more aggressively

**Typical result**: Brokers improve conversion by **3–5×**. This validates Nawy Partners' business model.

---

### Section 4 — Part 4: Top Brokers

**Purpose**: Identify top performers for coaching and rewards.

**Key techniques**:

| Technique | Purpose |
|-----------|---------|
| `HAVING COUNT(l.lead_id) >= 5` | Minimum volume threshold |
| `LEFT JOIN DEAL` | Include brokers with no won deals |
| `ISNULL(SUM(d.sale_price), 0)` | Handle brokers with zero deals |
| Performance tier via CASE | Bucket brokers for action |

**Why the 5-lead minimum?**

A broker with 2 leads and 1 win shows 50% conversion — statistically meaningless. The 5-lead threshold ensures enough data to rank meaningfully.

---

### Section 5 — Part 5: Funnel Velocity

**Purpose**: Compare close times across outcomes.

**Three metrics compared**:

1. **Days to close (won)** — how fast do successful deals close?
2. **Days to close (lost)** — how fast do leads get disqualified?
3. **Days since creation (open)** — how long have current leads been sitting?

**Key insight**: If lost leads close **faster** than won leads, it means the sales team is **disqualifying too early**. If open leads have been in the pipeline longer than the average won close time, they're **stuck** and need intervention.

---

## 📊 Expected Output

### Part 1 — Sample Result Set (Funnel Stages)

| funnel_stage | leads_reached | conversion_from_previous_pct | conversion_from_start_pct | currently_in_stage | total_leads |
|--------------|---------------|------------------------------|---------------------------|--------------------|-------------|
| 1. New | 1400 | 100.00 | 100.00 | 168 | 1400 |
| 2. Contacted | 1232 | 88.00 | 88.00 | 280 | 1400 |
| 3. Viewing | 672 | 54.55 | 48.00 | 280 | 1400 |
| 4. Negotiation | 378 | 56.25 | 27.00 | 168 | 1400 |
| 5. Closed Won | 189 | 50.00 | 13.50 | 189 | 1400 |
| 6. Closed Lost (attrition) | 189 | 50.00 | 13.50 | 189 | 1400 |

### Part 2 — Sample Result Set (Source Performance)

| lead_source | total_leads | won_leads | lost_leads | still_open | conversion_pct | avg_days_to_close | total_won_value_egp |
|-------------|-------------|-----------|------------|------------|----------------|-------------------|---------------------|
| broker_referral | 342 | 76 | 142 | 124 | 22.22 | 38.50 | 285,000,000.00 |
| developer_referral | 198 | 38 | 96 | 64 | 19.19 | 42.30 | 152,000,000.00 |
| walk_in | 154 | 28 | 72 | 54 | 18.18 | 35.20 | 118,000,000.00 |
| app | 302 | 32 | 138 | 132 | 10.60 | 51.80 | 128,000,000.00 |
| website | 404 | 15 | 189 | 200 | 3.71 | 62.10 | 60,000,000.00 |

### Part 3 — Sample Result Set (Broker Attribution)

| assignment_type | total_leads | won_leads | lost_leads | still_open | conversion_pct | attrition_pct |
|-----------------|-------------|-----------|------------|------------|----------------|---------------|
| Broker-Assigned | 872 | 172 | 380 | 320 | 19.72 | 43.58 |
| Unassigned | 528 | 17 | 220 | 291 | 3.22 | 41.67 |

### Part 4 — Sample Result Set (Top Brokers)

| broker_id | broker_name | broker_type | agency_name | total_leads | won_leads | conversion_pct | total_gmv_egp | performance_tier |
|-----------|-------------|-------------|-------------|-------------|-----------|----------------|---------------|------------------|
| 1 | Tarek Hussein | agency | Elite Real Estate | 87 | 22 | 25.29 | 148,500,000.00 | Strong |
| 2 | Mahmoud Sherif | agency | Sherif Properties | 112 | 24 | 21.43 | 132,000,000.00 | Strong |
| 4 | Mohamed Reda | agency | Reda Realty Group | 145 | 28 | 19.31 | 126,000,000.00 | Healthy |
| 5 | Tamer Salah | agency | Salah & Partners | 92 | 16 | 17.39 | 88,000,000.00 | Healthy |
| 6 | Ahmed Zaki | agency | Zaki Estates | 55 | 11 | 20.00 | 60,500,000.00 | Strong |

### Part 5 — Sample Result Set (Funnel Velocity)

| metric | avg_days | min_days | max_days | sample_size |
|--------|----------|----------|----------|-------------|
| Days to close (won leads) | 48.32 | 12.00 | 156.00 | 189 |
| Days to close (lost leads) | 52.85 | 5.00 | 210.00 | 189 |
| Days since creation (open leads) | 82.14 | 3.00 | 340.00 | 640 |

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `funnel_stage` | NVARCHAR | Funnel stage name |
| `leads_reached` | INT | Cumulative leads that reached stage |
| `conversion_from_previous_pct` | DECIMAL | Stage-to-stage conversion |
| `conversion_from_start_pct` | DECIMAL | End-to-end conversion |
| `currently_in_stage` | INT | Leads currently IN that stage |
| `lead_source` | NVARCHAR | Acquisition channel |
| `conversion_pct` | DECIMAL | Win rate by source |
| `avg_days_to_close` | DECIMAL | Average days from lead to close |
| `assignment_type` | NVARCHAR | Broker-Assigned or Unassigned |
| `broker_name` | NVARCHAR | Individual broker |
| `performance_tier` | NVARCHAR | Elite Closer / Strong / Healthy / Needs Coaching |

---

## 📈 Interpretation Guide

### Reading Part 1 — Funnel Stages

**Sample observation**:

- **New → Contacted**: 88% conversion
- **Contacted → Viewing**: 54.55% conversion
- **Viewing → Negotiation**: 56.25% conversion
- **Negotiation → Closed Won**: 50% conversion
- **End-to-end**: 13.50%

**Interpretation**:

- **Contact rate is strong** (88%) — brokers reach out promptly
- **Viewing rate is the bottleneck** (54.55%) — many contacted leads never tour
- **Negotiation conversion is healthy** (50%) — half of negotiators close
- **End-to-end 13.5% is industry-typical** for real estate

**Action**: Focus on **Contacted → Viewing** — that's where the biggest loss occurs (45% drop).

### Reading Part 2 — Source Performance

**Sample observation**:

| Source | Conversion | Days to Close |
|--------|------------|---------------|
| broker_referral | 22.22% | 38.5 |
| developer_referral | 19.19% | 42.3 |
| walk_in | 18.18% | 35.2 |
| app | 10.60% | 51.8 |
| website | 3.71% | 62.1 |

**Key insights**:

1. **broker_referral is 6× better than website** — invest heavily in broker relationships
2. **walk_in closes fastest** (35 days) — high-intent buyers
3. **website is worst** — 404 leads, only 15 conversions. Red flag.

**Action**:

- **Reallocate 30–40% of website marketing budget to broker referral incentives**
- **Study what broker referrals do differently**
- **Optimize website UX** (or accept its lower conversion as a top-of-funnel brand play)

### Reading Part 3 — Broker Attribution

**Sample observation**:

- **Broker-Assigned**: 19.72% conversion
- **Unassigned**: 3.22% conversion
- **6.1× improvement**

**What this tells us**:

- Broker assignment is **THE** most impactful sales operation
- 528 leads went unassigned — **that's a huge opportunity**
- If those 528 converted at 19.72%, that's **~87 additional deals** = **~200M EGP GMV**

**Action**:

- Assign brokers to **100% of leads within 24 hours**
- Hire more brokers to handle the unassigned backlog
- Measure and reward broker response time

### Reading Part 4 — Top Brokers

**Sample observation**: Tarek Hussein (Elite Real Estate):

- 87 leads, 22 wins → **25.29% conversion**
- **148.5M EGP in GMV**

**What this tells us**:

- Tarek is an **elite closer** — 2× the platform average
- His GMV contribution is **~10% of platform total**
- Losing him would be catastrophic

**Action**:

- Award Tarek with Platinum tier status
- Study his approach — document for training materials
- Offer exclusive inventory to retain him

**Red flag**: The bottom of the list (below 10% conversion) needs **coaching intervention**.

### Reading Part 5 — Funnel Velocity

**Sample observation**:

- **Won leads**: 48.3 days avg to close
- **Lost leads**: 52.9 days avg to close
- **Open leads**: 82.1 days since creation

**Key insights**:

1. **Lost leads take longer to close** — sales team is holding on too long
2. **Open leads exceed won-lead close time** — these are stuck, need intervention

**Action**:

- **Set 60-day max** for lead decision (won or lost)
- **Auto-flag open leads > 60 days** for review
- **Weekly list** of leads exceeding median close time

---

## 💡 Analytical Extensions

### Extension 1 — Funnel Conversion by Property Type

```sql
-- Join LEAD → PROPERTY, group by property_type
```

**Expected insight**: Apartments convert 2× faster than villas (smaller ticket, less deliberation).

### Extension 2 — Time of Day Impact

```sql
-- Extract hour of lead creation
DATEPART(HOUR, l.created_at) AS creation_hour
```

**Expected insight**: Evening leads (after 6pm) convert 1.5× better than daytime leads.

### Extension 3 — Lead Age vs. Conversion

Bucket leads by age at first contact:

```sql
CASE
    WHEN DATEDIFF(HOUR, created_at, first_contact) < 2 THEN 'Immediate'
    WHEN < 24 THEN 'Same Day'
    WHEN < 72 THEN 'Fast'
    ELSE 'Slow'
END AS response_speed
```

**Expected insight**: Immediate response converts 2–3× better. Speed matters.

### Extension 4 — Broker Response Time

Measure time from lead assignment to first activity:

```sql
AVG(DATEDIFF(HOUR, created_at, last_activity_at)) AS avg_response_hours
```

**Expected insight**: Brokers with < 2-hour response convert 3× better.

### Extension 5 — Cohort Funnel Analysis

Group leads by month:

```sql
FORMAT(created_at, 'yyyy-MM') AS lead_month
```

**Expected insight**: Conversion rates improve over time as Nawy's sales ops mature.

### Extension 6 — Visualize in Tableau

1. Connect Tableau to `NawyProptechDB`
2. Build **funnel chart**:
   - Stages on Y-axis
   - `leads_reached` on X-axis
   - Color: conversion %
3. Build **bar chart**: Sources ranked by conversion
4. Build **heatmap**: Broker × Source conversion
5. Build **table**: Top 20 brokers

---

## ⚡ Performance Notes

### Query Runtime

- **Expected**: 800–1,500 ms on 1,400 leads
- **Scales to**: 6–12 seconds at 100K leads

### Optimization Tips

**1. Add composite index on LEAD**

```sql
CREATE INDEX IX_LEAD_source_status ON nawy.LEAD(source, status);
CREATE INDEX IX_LEAD_broker_status ON nawy.LEAD(broker_id, status);
CREATE INDEX IX_LEAD_created_status ON nawy.LEAD(created_at, status);
```

**2. Materialize funnel metrics**

```sql
CREATE TABLE nawy.mv_funnel_metrics AS
SELECT ... -- Part 1 logic
```

Refresh hourly via SQL Agent.

**3. Partition by year**

For leads across years:

```sql
CREATE PARTITION FUNCTION pf_lead_year (DATE) AS RANGE RIGHT FOR VALUES
    ('2022-01-01','2023-01-01','2024-01-01','2025-01-01','2026-01-01');
