--DROP SCHEMA transform_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS transform_sch;

CREATE OR REPLACE VIEW transform_sch.vw_payments AS
SELECT
  /* keys */
  o.order_id,                    
  oi.order_items_id,              
  pt.payment_transaction_id,

  /* money */
  pt.amount            AS paid_amount,
  pt.processing_fee,
  o.total,
  oi.sales_tax,
  o.booking_fee,
  o.delivery_fee,

  /* payment meta */
  pt.payment_type,
  pt.payment_provider_name,
--pa.partner_name,

  /* location + site */
  loc.location_name,
  loc.tax_rate,
  site.location_name     AS site_name,
  site.tax_rate AS site_tax_rate

FROM clean_sch.orders                 o
--bring in one item row to access location_id & site_id
LEFT JOIN clean_sch.order_items        oi  ON oi.order_id = o.order_id

/* payments */
LEFT JOIN clean_sch.payment_transactions pt ON pt.order_id = o.order_id
--LEFT JOIN clean_sch.partners           pa  ON pa.partner_id = pt.partner_id
LEFT JOIN clean_sch.payment_refund     pr  ON pr.payment_transaction_id = pt.payment_transaction_id

/* kiosk / parent site look‑ups */
LEFT JOIN clean_sch.locations          loc  ON loc.location_id  = oi.location_id
LEFT JOIN clean_sch.locations          site ON site.location_id = oi.site_id;

/*
UPDATE clean_sch.order_items oi
SET partner_id = oi.partner_id
FROM clean_sch.payment_transactions pt
WHERE pt.order_id = oi.order_id;
*/

/* quick check
SELECT COUNT(*) AS items_without_partner
FROM clean_sch.order_items
WHERE partner_id IS NULL;
*/
