# Analytical SQL Queries

> **10 queries answering real business questions across Nawy's five business lines**
>
> ## 🎯 Overview

This folder contains **10 analytical SQL queries** that answer the most important business questions for a Nawy-style proptech platform. Each query:

- **Targets a real business problem** — not academic exercises
- **Includes full documentation** — business context, walkthrough, interpretation
- **Uses the views and tables** from the main database schema
- **Feeds directly into Tableau/Power BI** — no further SQL needed
- **Provides actionable recommendations** — not just numbers

### Coverage

| Business Line | Queries | Focus |
|---------------|---------|-------|
| **Property Analytics** | 1, 8 | Market pricing, asset profitability |
| **Sales Pipeline** | 2, 9 | Broker performance, funnel conversion |
| **Nawy Now** | 3 | Mortgage default risk |
| **Nawy Shares** | 4 | Fractional investment ROI |
| **Nawy Unlocked** | 5 | Occupancy & rental yield |
| **Cross-Business** | 6, 7 | CLV, cross-sell opportunities |
| **Executive** | 10 | Board-level KPIs |

---

## 📋 Query Index

| # | Query | Domain | Business Question | Complexity |
|---|-------|--------|-------------------|------------|
| 1 | [Market Pricing Trends](./01_market_pricing_trends.md) | Property | Which property segments are appreciating fastest? | Intermediate |
| 2 | [Broker Performance](./02_broker_performance.md) | Sales | Who are the top-performing brokers? | Intermediate |
| 3 | [Mortgage Default Risk](./03_mortgage_default_risk.md) | Nawy Now | What's the mortgage default rate by segment? | Advanced |
| 4 | [Shares ROI Analysis](./04_shares_roi_analysis.md) | Nawy Shares | Which offerings deliver the best investor returns? | Advanced |
| 5 | [Occupancy Analysis](./05_occupancy_analysis.md) | Nawy Unlocked | What's the occupancy rate and rental yield? | Advanced |
| 6 | [Customer Lifetime Value](./06_customer_lifetime_value.md) | Cross-Business | Who are the highest-value customers? | Advanced |
| 7 | [Cross-Sell Opportunities](./07_cross_sell_opportunities.md) | Growth | Which users should we target for cross-sell? | Intermediate |
| 8 | [Property Profitability](./08_property_profitability.md) | Asset Mgmt | Which properties generate the most revenue? | Advanced |
| 9 | [Lead Funnel Analysis](./09_lead_funnel_analysis.md) | Sales Ops | Where do leads drop off in the funnel? | Advanced |
| 10 | [Executive KPIs](./10_executive_kpis.md) | Executive | What's the board-level performance summary? | Advanced |

---

## 💼 Business Value Map

Each query maps to a specific role and decision:

| Query | Primary User | Key Decision Enabled |
|-------|--------------|----------------------|
| **1. Market Pricing** | Pricing Analyst, Nawy Shares Committee | Which markets to prioritize? |
| **2. Broker Performance** | Nawy Partners Team | Which brokers deserve exclusive inventory? |
| **3. Mortgage Default** | Risk Team, Securitization Partners | Should we tighten underwriting? |
| **4. Shares ROI** | Investment Committee, Marketing | Which offerings to replicate? |
| **5. Occupancy** | Unlocked Operations, Owner Relations | Which properties to acquire/deprioritize? |
| **6. CLV** | VIP Relations, Marketing | Who are the VIPs worth retaining? |
| **7. Cross-Sell** | Growth Team, CRM Automation | Who to target with which next product? |
| **8. Property Profitability** | Asset Management, Developer Relations | Which assets to promote or exit? |
| **9. Lead Funnel** | Sales Operations, Broker Enablement | Where to fix pipeline bottlenecks? |
| **10. Executive KPIs** | CEO, Board, Investors | How is the platform performing? |

---

## 🗂️ Query Categories

### 📊 Property & Market Analytics

**Query 1 — Market Pricing Trends**
- Year-over-year price appreciation by city, property type
- Identifies hypergrowth markets (North Coast chalets: +25% YoY)
- Feeds Nawy Shares offering selection

**Query 8 — Property Profitability**
- Total revenue per property across all business lines
- Ranks compounds and developers
- Reveals "holy grail" properties (5 revenue streams engaged)

### 💼 Sales & Broker Analytics

**Query 2 — Broker Performance**
- Top broker leaderboard with tier classification
- Lead-to-deal conversion rates
- Tier system: Platinum / Gold / Silver / Bronze / Rising

**Query 9 — Lead Funnel Analysis**
- Conversion at each pipeline stage
- Broker attribution effect (6× improvement)
- Source quality (broker_referral: 22% vs. website: 3.7%)

### 🏦 Financial Products

**Query 3 — Mortgage Default Risk**
- Portfolio default rate by property type
- High-risk / Medium-risk / Low-risk classification
- Feeds FRA regulatory reporting

**Query 4 — Shares ROI Analysis**
- Average ROI by offering, city, property type
- Best performer: North Coast chalets at 108% ROI
- Investor segmentation and exit timing

**Query 5 — Occupancy & Rental Yield**
- Occupancy rate per contract
- Rental income and management fee revenue
- Performance tier: Elite / Healthy / Underperforming / Vacant

### 📈 Growth & Executive

**Query 6 — Customer Lifetime Value**
- Total revenue per user across all business lines
- VIP / High Value / Standard / Low Value tiers
- Pareto validation (top 12% → 65% of revenue)

**Query 7 — Cross-Sell Opportunities**
- Engagement segmentation (Single-Line → Multi-Line)
- Prioritized target list with next-service recommendations
- Pair analysis (Properties + Shares is the strongest combo)

**Query 10 — Executive KPIs**
- Single-screen board dashboard
- 45+ KPIs across 8 categories
- Revenue by business line, GMV, default rate, occupancy
