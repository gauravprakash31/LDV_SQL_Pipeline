CREATE SCHEMA IF NOT EXISTS process_sch;

-- Drop existing table if it exists
DROP TABLE IF EXISTS process_sch.orders_with_items;

-- Create new table with progressive joins
CREATE TABLE process_sch.orders_with_items AS
SELECT
	-- Orders table (Step 1)
	o.order_id,
	o.reservation_id,
	o.payment_transaction_id,
	o.created_by,
	o.booking_fee,
	o.total,
	o.order_number,

	-- Reservations table (Step 2)
	r.reservation_code,

	-- Order Items table (Step 3)
	oi.order_items_id,
	oi.product_id,
	oi.location_id,
	oi.site_id,
	oi.rental_type_id,
	oi.coupon_discount,
	oi.tip,
	o.delivery_fee,
	oi.discount,
	oi.sales_tax,
	oi.total_amount_items,
	oi.total_items,
--  oi.created_on AS created_on_items, -- message: Perhaps you meant to reference the column "o.created_by"
	oi.is_refunded,
	oi.start_date,
	oi.end_date,
	oi.partner_id,

	-- Order History table
	oh.refunded_total

FROM clean_sch.orders o
LEFT JOIN clean_sch.reservations r ON o.reservation_id = r.reservation_id
LEFT JOIN clean_sch.order_items oi ON o.order_id = oi.order_id
LEFT JOIN clean_sch.order_history oh ON o.order_id = oh.order_id;

SELECT *
FROM process_sch.orders_with_items
ORDER BY order_items_id;


-- Drop existing table if it exists
DROP TABLE IF EXISTS process_sch.orders_with_p_l_pa;

-- Create new table with product, location, partner, and user details
CREATE TABLE process_sch.orders_with_p_l_pa AS
SELECT
  oij.*,
  p.product_name,
  l.location_name,
 --pt.partner_name, -- ERROR:  missing FROM-clause entry for table "pt"
  u.user_name
FROM process_sch.orders_with_items oij
LEFT JOIN clean_sch.products p ON oij.product_id = p.product_id
LEFT JOIN clean_sch.locations l ON oij.location_id = l.location_id
--LEFT JOIN clean_sch.partners pt ON oij.partner_id = pt.partner_id -- error on this line, review later
LEFT JOIN clean_sch.users u ON oij.created_by = u.users_id;


SELECT *
FROM process_sch.orders_with_p_l_pa
ORDER BY order_items_id;

---Adding payment information
-- Drop existing table if it exists
DROP TABLE IF EXISTS process_sch.orders_with_payments;

-- Create table with payment transaction and refund info
CREATE TABLE process_sch.orders_with_payments AS
SELECT
  base.*,
  pt.amount,
  pt.processing_fee,
  pt.payment_type,
--pt.payment_source, --ERROR:  column pt.payment_source does not exist
  pt.payment_provider_name,
  pr.refunded_processing_fee

FROM process_sch.orders_with_p_l_pa base
LEFT JOIN clean_sch.payment_transactions pt ON base.order_id = pt.order_id
LEFT JOIN clean_sch.payment_refund pr ON pt.payment_transaction_id = pr.payment_transaction_id;


SELECT *
FROM process_sch.orders_with_payments
ORDER BY order_items_id;


----Creating Coupons table
-- Drop existing table if it exists
DROP TABLE IF EXISTS process_sch.coupons;

-- Create new table with grouped coupon codes
CREATE TABLE process_sch.coupons AS
SELECT
	oc.order_items_id,
	STRING_AGG(c.coupon_code, ',' ORDER BY c.coupon_code) AS coupon_code
FROM clean_sch.order_coupons oc
LEFT JOIN clean_sch.coupons c ON oc.coupon_id = c.coupon_id
--WHERE oc.order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404'
GROUP BY oc.order_items_id;


-- Drop table if it exists
DROP TABLE IF EXISTS process_sch.orders_with_coupons;

-- Create new table with joined coupon info
CREATE TABLE process_sch.orders_with_coupons AS
SELECT
	pay.*,
	c.coupon_code
FROM process_sch.orders_with_payments pay
LEFT JOIN process_sch.coupons c
  ON pay.order_items_id = c.order_items_id;


SELECT *
FROM process_sch.orders_with_coupons
ORDER BY order_items_id;


-- enrich with product/location/partner/user:
DROP TABLE IF EXISTS process_sch.orders_with_p_l_pa;
CREATE TABLE process_sch.orders_with_p_l_pa AS
SELECT
  oij.*,
  p.product_name,
  l.location_name,
 --pt.partner_name,
  u.user_name
FROM process_sch.orders_with_items oij
LEFT JOIN clean_sch.products  p  ON p.product_id       = oij.product_id
LEFT JOIN clean_sch.locations l  ON l.location_id      = oij.location_id
--LEFT JOIN clean_sch.partners  pt ON pt.partner_id      = oij.partner_id
LEFT JOIN clean_sch.users     u  ON u.users_id         = oij.created_by;

SELECT * FROM process_sch.orders_with_p_l_pa LIMIT 20;


