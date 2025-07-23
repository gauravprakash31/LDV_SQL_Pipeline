/* add payment + refund dollars */

DROP TABLE IF EXISTS process_sch.orders_with_payments;
CREATE TABLE process_sch.orders_with_payments AS
SELECT
  base.*,
  pay.amount,
  pay.processing_fee,
  pay.source            AS payment_source,      -- rename
  pay.payment_type,
  pay.payment_provider_name,
  pr.refunded_processing_fee
--pr.refunded_total AS payment_refunded_total   -- avoid col clash --ERROR:  column pr.refunded_total does not exist
FROM process_sch.orders_with_p_l_pa base
LEFT JOIN clean_sch.payment_transactions pay
       ON pay.order_id = base.order_id
LEFT JOIN clean_sch.payment_refund pr
       ON pr.payment_transaction_id = pay.payment_transaction_id;

SELECT * FROM process_sch.orders_with_payments LIMIT 20;


/* coupon aggregator */
DROP TABLE IF EXISTS process_sch.coupons;
CREATE TABLE process_sch.coupons AS
SELECT
  oc.order_items_id,
  STRING_AGG(c.coupon_code, ',' ORDER BY c.coupon_code) AS coupon_code
FROM clean_sch.order_coupons oc
LEFT JOIN clean_sch.coupons c ON c.coupon_id = oc.coupon_id
GROUP BY oc.order_items_id;

SELECT * FROM process_sch.coupons LIMIT 20;


/* merge coupons into payments chain */
DROP TABLE IF EXISTS process_sch.orders_with_coupons;
CREATE TABLE process_sch.orders_with_coupons AS
SELECT
  pay.*,
  c.coupon_code
FROM process_sch.orders_with_payments pay
LEFT JOIN process_sch.coupons c
       ON c.order_items_id = pay.order_items_id;

SELECT * FROM process_sch.orders_with_coupons LIMIT 20;

