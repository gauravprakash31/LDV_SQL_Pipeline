-- TRANSACTION REPORT: standalone SQL starting from clean_sch tables

-- Drop & recreate reporting schema for refund report
DROP SCHEMA IF EXISTS refund_report_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS refund_report_sch;

-- Build refund_report_raw with CTE
DROP TABLE IF EXISTS refund_report_sch.base_items;
CREATE TABLE refund_report_sch.base_items AS
SELECT
  oi.order_id,
  oi.order_item_id,
  o.order_number,
  r.reservation_code,
  oi.created_on_items      AS original_order_date,
  oi.start_date,
  oi.end_date,
  ui.user_name,
  prd.product_name,
  rt.rental_name,
  loc.location_name,
  site.location_name       AS site_name,
  COALESCE(site.tax_rate, loc.tax_rate) AS tax_percentage,
  oi.total_amount_items,
  oi.coupon_discount,
  oi.discount,
  oi.tip,
  oi.sales_tax,
  oi.delivery_fee,
  oi.booking_fee_item,
  oi.partner_id,
  pa.partner_name,
  pt.processing_fee,
  pr.refunded_processing_fee,
  pt.payment_source        AS order_type,
  pt.payment_type,
  pt.payment_provider_name,
  COALESCE(ocg.coupon_code, '') AS coupon_code,
  oh.refunded_total,
  oh.refund_order_number
  
FROM clean_sch.order_items oi

INNER JOIN clean_sch.orders o               ON o.order_id             = oi.order_id
LEFT JOIN clean_sch.reservations r    ON r.reservation_id        = o.reservation_id
LEFT JOIN clean_sch.users ui          ON ui.users_id            = o.created_by
LEFT JOIN clean_sch.products prd      ON prd.product_id         = oi.product_id
LEFT JOIN clean_sch.rental_types rt   ON rt.rental_types_id     = oi.rental_type_id
LEFT JOIN clean_sch.locations loc     ON loc.location_id        = oi.location_id
LEFT JOIN clean_sch.locations site    ON site.location_id       = oi.site_id
LEFT JOIN clean_sch.partners pa       ON pa.partner_id          = oi.partner_id
LEFT JOIN clean_sch.payment_transactions pt ON pt.order_id           = oi.order_id
LEFT JOIN clean_sch.payment_refund pr ON pr.payment_transaction_id = pt.payment_transaction_id
LEFT JOIN 

(
  SELECT order_item_id,
         STRING_AGG(c.coupon_code, ',') AS coupon_code
  FROM clean_sch.order_coupons oc
  JOIN clean_sch.coupons c ON c.coupon_id = oc.coupon_id
  GROUP BY order_item_id
) ocg ON ocg.order_item_id   = oi.order_item_id

LEFT JOIN clean_sch.order_history oh  ON oh.order_id        = oi.order_id;


SELECT * 
FROM refund_report_sch.base_items 
WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404'
ORDER BY order_item_id ASC;

DROP TABLE IF EXISTS refund_report_sch.payment_rows;
CREATE TABLE refund_report_sch.payment_rows AS
SELECT
  bi.reservation_code,
  bi.order_number,
  bi.order_item_id,
  bi.original_order_date,
  bi.original_order_date AS transaction_date,
  bi.total_amount_items,
  bi.order_type,
  0 AS refund_amount,
  
  'Payment' AS transaction_type,
  bi.payment_type,
  bi.payment_provider_name,
  NULL::text AS refund_order_number_actual,
  bi.user_name,
  bi.product_name,
  bi.rental_name,
  bi.start_date,
  bi.end_date,
  bi.location_name,
  bi.site_name,
  bi.tax_percentage,
  bi.total_amount_items AS line_item_sub_total,
  bi.coupon_code,
  bi.coupon_discount,
  bi.discount,
  bi.tip,
  bi.total_amount_items - bi.coupon_discount - bi.discount AS final_line_item_sub_total,
  (bi.booking_fee_item * bi.total_amount_items / NULLIF(o.total, 0)) AS booking_fee,
  (bi.processing_fee * bi.total_amount_items / NULLIF(o.total, 0)) AS processing_fees,
  bi.sales_tax,
  bi.delivery_fee,
  (
    (bi.total_amount_items - bi.coupon_discount - bi.discount)
    + (bi.booking_fee_item * bi.total_amount_items / NULLIF(o.total, 0))
    + bi.tip + bi.sales_tax + bi.delivery_fee
    - (bi.processing_fee * bi.total_amount_items / NULLIF(o.total, 0))
  ) AS total_collected,
  bi.refunded_total,
  bi.refund_order_number,
  bi.partner_name,
  bi.partner_id,
  bi.order_id
  
FROM refund_report_sch.base_items bi
JOIN clean_sch.orders o ON o.order_id = bi.order_id;


SELECT * 
FROM refund_report_sch.payment_rows 
WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404'
ORDER BY order_item_id ASC;

/*Refund Transactions*/

DROP TABLE IF EXISTS refund_report_sch.refund_rows;
CREATE TABLE refund_report_sch.refund_rows AS
SELECT DISTINCT ON (p.order_item_id)
  p.reservation_code,
  p.order_number,
  p.order_item_id,
  p.original_order_date,
  ih.created_on AS transaction_date,
  p.total_amount_items,
  p.order_type,
  p.refunded_total AS refund_amount,
  'Refund' AS transaction_type,
  p.payment_type,
  p.payment_provider_name,
  p.refund_order_number AS refund_order_number_actual,
  p.user_name,
  p.product_name,
  p.rental_name,
  p.start_date,
  p.end_date,
  p.location_name,
  p.site_name,
  p.tax_percentage,
  p.total_amount_items AS line_item_sub_total,
  p.coupon_code,
  p.coupon_discount,
  p.discount,
  p.tip,
  p.total_amount_items - p.coupon_discount - p.discount AS final_line_item_sub_total,
  (p.booking_fee_item * p.total_amount_items / NULLIF(o.total, 0)) AS booking_fee,
  (p.refunded_processing_fee * p.total_amount_items / NULLIF(o.total, 0)) AS processing_fees,
  p.sales_tax,
  p.delivery_fee,
  (
    (p.total_amount_items - p.coupon_discount - p.discount)
    + (p.booking_fee_item * p.total_amount_items / NULLIF(o.total, 0))
    + p.tip + p.sales_tax + p.delivery_fee
    - (p.refunded_processing_fee * p.total_amount_items / NULLIF(o.total, 0))
  ) AS total_collected,
  p.refunded_total,
  p.refund_order_number,
  p.partner_name,
  p.partner_id,
  p.order_id
  
FROM refund_report_sch.base_items p
JOIN clean_sch.order_items_history ih 	ON ih.order_item_id = p.order_item_id
JOIN clean_sch.order_history oh       	ON oh.order_id = p.order_id
JOIN clean_sch.orders o              	ON o.order_id = p.order_id
WHERE ih.refunded_quantity > 0 AND ih.refunded_total_item > 0;


SELECT *
FROM refund_report_sch.refund_rows
WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404'
ORDER BY order_item_id ASC;


/* Union of payments and refunds */
DROP TABLE IF EXISTS refund_report_sch.refund_report_union_raw;

CREATE TABLE refund_report_sch.refund_report_union_raw AS
SELECT
  reservation_code::text,
  order_number::text,
  order_item_id::text,
  original_order_date,
  transaction_date,
  total_amount_items::numeric,
  order_type::text,
  refund_amount::numeric,
  transaction_type::text,
  payment_type::text,
  payment_provider_name::text,
  refund_order_number_actual::text,
  user_name::text,
  product_name::text,
  rental_name::text,
  start_date,
  end_date,
  location_name::text,
  site_name::text,
  tax_percentage::numeric,
  line_item_sub_total::numeric,
  coupon_code::text,
  coupon_discount::numeric,
  discount::numeric,
  tip::numeric,
  final_line_item_sub_total::numeric,
  booking_fee::numeric,
  processing_fees::numeric,
  sales_tax::numeric,
  delivery_fee::numeric,
  total_collected::numeric,
  refunded_total::numeric,
  refund_order_number::text,
  partner_name::text,
  partner_id::text,
  order_id::text
  
FROM refund_report_sch.payment_rows

UNION ALL

SELECT
  reservation_code::text,
  order_number::text,
  order_item_id::text,
  original_order_date,
  transaction_date,
  total_amount_items::numeric,
  order_type::text,
  refund_amount::numeric,
  transaction_type::text,
  payment_type::text,
  payment_provider_name::text,
  refund_order_number_actual::text,
  user_name::text,
  product_name::text,
  rental_name::text,
  start_date,
  end_date,
  location_name::text,
  site_name::text,
  tax_percentage::numeric,
  line_item_sub_total::numeric,
  coupon_code::text,
  coupon_discount::numeric,
  discount::numeric,
  tip::numeric,
  final_line_item_sub_total::numeric,
  booking_fee::numeric,
  processing_fees::numeric,
  sales_tax::numeric,
  delivery_fee::numeric,
  total_collected::numeric,
  refunded_total::numeric,
  refund_order_number::text,
  partner_name::text,
  partner_id::text,
  order_id::text

FROM refund_report_sch.refund_rows;



SELECT *
FROM refund_report_sch.refund_report_union_raw
WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404'
ORDER BY order_item_id ASC;
