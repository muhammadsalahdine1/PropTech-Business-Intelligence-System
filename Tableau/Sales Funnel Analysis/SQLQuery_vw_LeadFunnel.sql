USE NawyProptechDB;
GO


CREATE OR ALTER VIEW nawy.vw_LeadFunnel AS
SELECT 
-- Lead identifiers
l.lead_id,
l.status     AS lead_status,
l.source     AS lead_source,
l.created_at AS lead_created_at,
l.last_activity_at,
-- Date helpers (for Tableau)
CAST     ( l.created_at AS DATE )   AS lead_created_date,
YEAR     ( l.created_at )           AS lead_year,
MONTH    ( l.created_at )           AS lead_month,
DATENAME ( MONTH, l.created_at )    AS lead_month_name,
DATEPART ( QUARTER, l.created_at )  AS lead_quarter,
-- Funnel stage (ordered)
CASE l.status
     WHEN 'new'         THEN 1
     WHEN 'contacted'   THEN 2
     WHEN 'viewing'     THEN 3
     WHEN 'negotiation' THEN 4
     WHEN 'closed_won'  THEN 5
     WHEN 'closed_lost' THEN 6
     ELSE 0
END  AS funnel_stage,
-- Outcome flags
CASE WHEN l.status = 'closed_won'  THEN 1 ELSE 0 END AS is_won,
CASE WHEN l.status = 'closed_lost' THEN 1 ELSE 0 END AS is_lost,
CASE WHEN l.status NOT IN ( 'closed_won','closed_lost' ) THEN 1 ELSE 0 END AS is_open,
-- Timing
DATEDIFF (DAY, l.created_at, l.last_activity_at) AS days_in_pipeline,
CASE WHEN l.status = 'closed_won' THEN DATEDIFF(DAY,l.created_at,l.last_activity_at) ELSE NULL END AS days_to_close,
-- Property attributes
p.property_id,
p.title AS property_title,
p.property_type,
p.listing_type,
p.city,
p.district,
p.compound_name,
p.price AS property_price,
p.area_sqm,
-- Broker attributes
b.broker_id,
b.broker_type,
b.agency_name,
u_b.full_name AS broker_name,
-- Buyer attributes
l.buyer_user_id,
u_buyer.full_name AS buyer_name,
u_buyer.user_type AS buyer_type,
-- Deal info (if converted)
d.deal_id,
d.sale_price   AS deal_sale_price,
d.payment_type AS deal_payment_type,
d.status       AS deal_status,
d.closed_at    AS deal_closed_at,
-- Commission (if any)
c.commission_amount,
c.status       AS commission_status

FROM nawy.LEAD l
LEFT JOIN nawy.PROPERTY p      ON l.property_id    = p.property_id
LEFT JOIN nawy.BROKER b        ON l.broker_id      = b.broker_id
LEFT JOIN nawy.[USER] u_b      ON b.user_id        = u_b.user_id
LEFT JOIN nawy.[USER] u_buyer  ON l.buyer_user_id = u_buyer.user_id
LEFT JOIN nawy.DEAL d          ON l.lead_id        = d.lead_id
LEFT JOIN nawy.COMMISSION c    ON d.deal_id        = c.deal_id;


GO




































