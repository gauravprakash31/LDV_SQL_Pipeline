--ORDER REPORT--

DROP SCHEMA IF EXISTS process_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS process_sch;

/* ORDERS */
-- STEP 1: Orders + Items + Reservations + Order History + Order Item History (for Booking Fee)
DROP TABLE IF EXISTS process_sch.orders_with_items;
CREATE TABLE process_sch.orders_with_items AS
SELECT
    o.order_id,
    o.reservation_id,
    o.payment_transaction_id,
    o.created_by,
    o.order_booking_fee,
    oi.delivery_fee,
    o.total,
    o.order_number,
    r.reservation_code,
    oi.order_item_id,
    oi.product_id,
    oi.location_id,
	oi.modified_on_items,
    oi.site_id,
    oi.rental_type_id,
    oi.coupon_discount,
    oi.tip,
    oi.discount,
    oi.sales_tax,
    oi.total_amount_items,
    oi.total_items,
    oi.created_on_items,
    oi.is_refunded,
    oi.start_date,
    oi.end_date,
    oi.partner_id,
    oh.refunded_total     AS order_level_refund,
    oi.booking_fee_item   AS line_item_booking_fee,
	ih.refunded_total_item
	
FROM clean_sch.orders o
LEFT JOIN clean_sch.reservations r       ON r.reservation_id = o.reservation_id
LEFT JOIN clean_sch.order_items oi       ON oi.order_id = o.order_id
LEFT JOIN clean_sch.order_history oh     ON oh.order_id = o.order_id
LEFT JOIN clean_sch.order_items_history ih 	ON ih.order_item_id = oi.order_item_id;

SELECT * FROM process_sch.orders_with_items 
WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404'
ORDER BY order_item_id ASC; --WHERE "Order Id" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';


-- STEP 2: Add Product, Location, Site, User, Partner
DROP TABLE IF EXISTS process_sch.orders_with_p_l_u;
CREATE TABLE process_sch.orders_with_p_l_u AS
SELECT
    base.*,
    p.product_name,
    l.location_name,
    site.location_name           AS site_name,
    u.user_name,
    pa.partner_name,
    ROUND(COALESCE(site.tax_rate, l.tax_rate)::numeric, 2) AS tax_percentage
FROM process_sch.orders_with_items base
LEFT JOIN clean_sch.products p         ON p.product_id = base.product_id
LEFT JOIN clean_sch.locations l        ON l.location_id = base.location_id
LEFT JOIN clean_sch.locations site     ON site.location_id = base.site_id
LEFT JOIN clean_sch.users u            ON u.users_id = base.created_by
LEFT JOIN clean_sch.partners pa        ON pa.partner_id = base.partner_id;


-- STEP 3: Add Payment and Refund Info
DROP TABLE IF EXISTS process_sch.orders_with_payments;
CREATE TABLE process_sch.orders_with_payments AS
SELECT
    plu.*,
    pt.amount                        AS original_amount,
    pt.processing_fee,
    pr.refunded_processing_fee,
    pt.payment_source,
    pt.payment_type,
    COALESCE(pt.payment_provider_name, 'Unknown') AS payment_provider_name
FROM process_sch.orders_with_p_l_u plu
LEFT JOIN clean_sch.payment_transactions pt   ON pt.order_id = plu.order_id
LEFT JOIN clean_sch.payment_refund pr         ON pr.payment_transaction_id = pt.payment_transaction_id;

-- STEP 3: Add Payment and Refund Info
DROP TABLE IF EXISTS process_sch.orders_with_refund;
CREATE TABLE process_sch.orders_with_refund AS
SELECT
    pt.payment_transaction_id,
    MAX(pr.total_refund_amount)		AS max_total_refund_amount,
    SUM(pr.refunded_processing_fee)	AS total_refunded_processing_fee

FROM clean_sch.payment_transactions pt  
INNER JOIN clean_sch.payment_refund pr         ON pr.payment_transaction_id = pt.payment_transaction_id
GROUP BY pt.payment_transaction_id;

SELECT * 
FROM process_sch.orders_with_refund
WHERE payment_transaction_id = 'e1230bbb-e682-409f-96f6-436222efe7d9';


-- STEP 4: Aggregate Coupon Codes
DROP TABLE IF EXISTS process_sch.orders_with_coupons;
CREATE TABLE process_sch.orders_with_coupons AS
WITH agg AS (
    SELECT
        oc.order_item_id,
        STRING_AGG(c.coupon_code, ',' ORDER BY c.coupon_code) AS coupon_code
    FROM clean_sch.order_coupons oc
    JOIN clean_sch.coupons c ON c.coupon_id = oc.coupon_id
    GROUP BY oc.order_item_id
)
SELECT
    pay.*,
    agg.coupon_code
FROM process_sch.orders_with_payments pay
LEFT JOIN agg ON agg.order_item_id = pay.order_item_id;

-- STEP 5: Raw Reporting Table
DROP SCHEMA IF EXISTS order_report_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS order_report_sch;

DROP TABLE IF EXISTS order_report_sch.order_report_raw;
CREATE TABLE order_report_sch.order_report_raw AS
SELECT
    ocp.reservation_code            AS rid,
    ocp.order_id                    AS order_id_original,
    ocp.order_number                AS order_id,
    ocp.order_item_id               AS line_item_id,
    ocp.created_on_items            AS order_date,
    ocp.original_amount             AS original_order_amount,
    ocp.order_level_refund          AS order_refunded_amount,
    ocp.total                       AS order_amount,
    ocp.payment_source              AS order_type,
    ocp.payment_type                AS payment_method,
    ocp.payment_provider_name       AS payment_processor,
    ocp.is_refunded                 AS Refunded,
    ocp.user_name,
    ocp.product_name,
    ocp.start_date                  AS rental_start_date,
    ocp.end_date                    AS rental_end_date,
    ocp.location_name,
    ocp.site_name                   AS subsite_location,
    ocp.total_items                 AS line_item_sub_total,
    ocp.coupon_code                 AS promo_code_id,
    ocp.coupon_discount             AS coupon_amount,
    ocp.discount                    AS line_item_discount,
    ocp.tip                         AS gratuity,
	
    GREATEST(
        COALESCE(total_items, 0)
        - COALESCE(coupon_discount, 0)
        - COALESCE(discount, 0),
        0)                               AS final_line_item_sub_total,
    
	ocp.line_item_booking_fee       AS booking_fee,
	
    (COALESCE(processing_fee, 0) * total_amount_items / NULLIF(original_amount, 0)) AS create_line_item_processing_fee,
	
    (COALESCE(refunded_processing_fee, 0) * total_amount_items / NULLIF(total, 0)) AS refund_line_item_processing_fee,
	
        
	ocp.tax_percentage              AS tax_p,
    ocp.sales_tax                   AS tax,
    ocp.delivery_fee,
    ocp.partner_name,
    ocp.partner_id,
    ocp.order_booking_fee,
    ocp.processing_fee,
    ocp.refunded_processing_fee,
    ocp.total_amount_items,
	ocp.total,
    ocp.coupon_discount
	
FROM process_sch.orders_with_coupons ocp;


SELECT * 
FROM reporting_sch.order_report_raw
WHERE order_id_original = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404'
ORDER BY line_item_id;

/* ORDER REPORT */
DROP TABLE IF EXISTS order_report_sch.order_report_final;

CREATE TABLE order_report_sch.order_report_final AS
SELECT
    rid								AS "RID",
    order_id						AS "Order Id",
    line_item_id                   	AS "Line Item Id",
	order_date						AS "Order Date",
	original_order_amount 			AS "Original Order Amount",
	order_refunded_amount			AS "Order Refunded Amount",
	ROUND(order_amount::numeric,2)					AS "Order Amount", 
	order_type						AS "OrderType", 
	payment_method					AS "Payment Method",
    payment_processor				AS "Payment Processer",
    Refunded						AS "Refunded?",
	user_name						AS "User", -- why is Prasad Polsani everywhere?
	product_name					AS "Product Name",
    rental_start_date				AS "Rental Start Date",
    rental_end_date					AS "Rental End Date",
    location_name                   AS "Location",
    subsite_location 	            AS "Substitue Location",
	-- tax counties
  	line_item_sub_total				AS "Line Item Sub Total",
	promo_code_id					AS "Promo Code Id",
    ROUND(coupon_amount::numeric,2)					AS "Coupon Amount",
    line_item_discount				AS "Line Item Discount",			
    gratuity                        AS "Gratuity",
	ROUND(final_line_item_sub_total::numeric,2)       AS "Final Line Item Sub Total",
    ROUND(booking_fee::numeric,2)						AS "Booking Fee",
    ROUND(create_line_item_processing_fee::numeric,2)  AS "Create Line Item Payment Processor Fee",
    ROUND(refund_line_item_processing_fee::numeric,2)  AS "Refund Line Item Payment Processor Fee", 
	ROUND((create_line_item_processing_fee - refund_line_item_processing_fee)::numeric,2)  AS "Total Line Item Payment Processor Fee", 
	tax_p							AS "Tax%",  
    ROUND(tax::numeric,2)		 						AS "Tax", 
	delivery_fee					AS "Delivery Fee",	
    ROUND(((gratuity+final_line_item_sub_total+booking_fee+tax)
		- (create_line_item_processing_fee - refund_line_item_processing_fee))::numeric,2)	AS "Total Collected",
	partner_name					AS "Parner Name",
	partner_id						AS "PartnerId" 
	
FROM order_report_sch.order_report_raw; --WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

SELECT * FROM order_report_sch.order_report_final 
WHERE "RID" = 'LDV0014980'
ORDER BY "Line Item Id" ASC; --WHERE "Order Id" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';
