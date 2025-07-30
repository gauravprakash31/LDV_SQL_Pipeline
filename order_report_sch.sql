--ORDER REPORT--

DROP SCHEMA IF EXISTS order_report_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS order_report_sch;


-- step 1: orders, order items, reservations, order history, order item history - for booking fee
DROP TABLE IF EXISTS order_report_sch.orders_with_items;
CREATE TABLE order_report_sch.orders_with_items AS
SELECT DISTINCT
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
    oi.total_amount_items + COALESCE(ih.refunded_total_item, 0)AS actual_amount_items,
    oi.total_items,
    oi.created_on_items,
    CASE WHEN COALESCE(ih.refunded_total_item, 0) > 0 THEN TRUE ELSE oi.is_refunded END AS is_refunded,
    oi.start_date,
    oi.end_date,
    oi.partner_id,
    --oh.refunded_total         AS order_level_refund,
    oi.booking_fee_item       AS line_item_booking_fee,
    COALESCE(ih.refunded_total_item,0) AS refunded_total_item
	
FROM clean_sch.orders o
LEFT JOIN clean_sch.reservations r       ON r.reservation_id = o.reservation_id
LEFT JOIN clean_sch.order_items oi       ON oi.order_id = o.order_id
LEFT JOIN clean_sch.order_history oh     ON oh.order_id = o.order_id
LEFT JOIN clean_sch.order_items_history ih ON ih.order_item_id = oi.order_item_id AND ih.refunded_total_item > 0;

--CHECK---
SELECT * FROM clean_sch.order_items WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404' ORDER BY order_item_id;

SELECT count(DISTINCT order_id) FROM order_report_sch.orders_with_items; 
SELECT * FROM order_report_sch.orders_with_items WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404' ORDER BY order_item_id;

SELECT * FROM order_report_sch.orders_with_items WHERE order_number = 100000005009;

-- step 2: product, location, site, user, partner
DROP TABLE IF EXISTS order_report_sch.orders_with_p_l_u;
CREATE TABLE order_report_sch.orders_with_p_l_u AS
SELECT
    base.*,
	
    p.product_name,
    l.location_name,
    site.location_name                 AS site_name,
    u.user_name,
    pa.partner_name,
    ROUND(COALESCE(site.tax_rate, l.tax_rate)::numeric, 2) AS tax_percentage
FROM order_report_sch.orders_with_items base

LEFT JOIN clean_sch.products p         ON p.product_id = base.product_id
LEFT JOIN clean_sch.locations l        ON l.location_id = base.location_id
LEFT JOIN clean_sch.locations site     ON site.location_id = base.site_id
LEFT JOIN clean_sch.users u            ON u.users_id = base.created_by
LEFT JOIN clean_sch.partners pa        ON pa.partner_id = base.partner_id;

--CHECK--
SELECT count(DISTINCT order_id) FROM order_report_sch.orders_with_p_l_u ;
SELECT * FROM order_report_sch.orders_with_p_l_u WHERE order_number = 100000005009 ORDER BY order_item_id;

-- step 3: payment and refund info
DROP TABLE IF EXISTS order_report_sch.orders_with_payments;
CREATE TABLE order_report_sch.orders_with_payments AS
SELECT
    plu.*,
    pt.amount                        AS original_amount,
    pt.processing_fee,
    pt.payment_source,
    pt.payment_type,
    COALESCE(pt.payment_provider_name, 'Unknown') AS payment_provider_name,
    tmp.sum_total_refund_amount,
    tmp.sum_refunded_processing_fee

FROM order_report_sch.orders_with_p_l_u plu
LEFT JOIN clean_sch.payment_transactions pt ON pt.order_id = plu.order_id
LEFT JOIN (
    SELECT 
        payment_transaction_id, 
        SUM(total_refund_amount) AS sum_total_refund_amount,
        SUM(refunded_processing_fee) AS sum_refunded_processing_fee
    FROM clean_sch.payment_refund 
    GROUP BY payment_transaction_id
) AS tmp ON pt.payment_transaction_id = tmp.payment_transaction_id;

SELECT * FROM order_report_sch.orders_with_payments WHERE order_number = 100000005009 ORDER BY order_item_id;


-- step 4: aggregate coupon codes
DROP TABLE IF EXISTS order_report_sch.orders_with_coupons;
CREATE TABLE order_report_sch.orders_with_coupons AS

WITH agg AS (
    SELECT
        oc.order_item_id,
        STRING_AGG(c.coupon_code, ',' ORDER BY c.coupon_code) AS coupon_code
    FROM clean_sch.order_coupons oc
    INNER JOIN clean_sch.coupons c ON c.coupon_id = oc.coupon_id
    GROUP BY oc.order_item_id
)

SELECT
    pay.*,
    agg.coupon_code
FROM order_report_sch.orders_with_payments pay
LEFT JOIN agg ON agg.order_item_id = pay.order_item_id;

SELECT count(DISTINCT order_id) FROM order_report_sch.orders_with_coupons; 
SELECT * FROM order_report_sch.orders_with_coupons WHERE order_number = 100000005184 ORDER BY order_item_id;

/* ORDERS RAW REPORT */
/* ORDERS RAW REPORT - formatted dates, blank user, nulls handled */
DROP TABLE IF EXISTS order_report_sch.order_report_raw;

CREATE TABLE order_report_sch.order_report_raw AS
SELECT
    ocp.reservation_code,
    ocp.order_id                          AS order_id_original,
    ocp.order_number,
    ocp.order_item_id,
    TO_CHAR(ocp.created_on_items, 'MM/DD/YYYY')         AS created_on_items,
    COALESCE(ocp.original_amount, 0)                    AS original_amount,
    COALESCE(ocp.sum_total_refund_amount, 0)            AS order_level_refund,
    COALESCE(ocp.total, 0)                              AS total,
    COALESCE(ocp.payment_source, '')                    AS payment_source,
    COALESCE(ocp.payment_type, '')                      AS payment_type,
    COALESCE(ocp.payment_provider_name, '')             AS payment_provider_name,
    ocp.is_refunded,
    CASE 
        WHEN ocp.payment_source = 'Consumer Web' THEN ''
        ELSE COALESCE(ocp.user_name, '')
    END                                                 AS user_name,
    COALESCE(ocp.product_name, '')                      AS product_name,
    TO_CHAR(ocp.start_date, 'MM/DD/YYYY')               AS start_date,
    TO_CHAR(ocp.end_date, 'MM/DD/YYYY')                 AS end_date,
    COALESCE(ocp.location_name, '')                     AS location_name,
    COALESCE(ocp.site_name, '')                         AS site_name,
    COALESCE(ocp.total_items, 0)                        AS total_items,
    COALESCE(ocp.coupon_code, '')                       AS coupon_code,
    COALESCE(ocp.coupon_discount, 0)                    AS coupon_discount,
    COALESCE(ocp.discount, 0)                           AS discount,
    COALESCE(ocp.tip, 0)                                AS tip,
    GREATEST(
        COALESCE(total_items, 0) 
        - COALESCE(coupon_discount, 0) 
        - COALESCE(discount, 0), 0
    )                                                   AS final_line_item_sub_total,
    COALESCE(ocp.line_item_booking_fee, 0)              AS line_item_booking_fee,
    (COALESCE(ocp.processing_fee, 0) * COALESCE(ocp.actual_amount_items, 0) / NULLIF(ocp.original_amount, 0)) AS create_line_item_processing_fee,
    (COALESCE(ocp.sum_refunded_processing_fee, 0) * COALESCE(refunded_total_item, 0) / NULLIF(ocp.sum_total_refund_amount, 0))  AS refund_line_item_processing_fee,
    COALESCE(ocp.tax_percentage, 0)                     AS tax_percentage,
    COALESCE(ocp.sales_tax, 0)                          AS sales_tax,
    COALESCE(ocp.delivery_fee, 0)                       AS delivery_fee,
    COALESCE(ocp.partner_name, '')                      AS partner_name,
    ocp.partner_id,
    COALESCE(ocp.order_booking_fee, 0)                  AS order_booking_fee,
    COALESCE(ocp.processing_fee, 0)                     AS processing_fee,
    COALESCE(ocp.sum_refunded_processing_fee, 0)        AS refunded_processing_fee,
    COALESCE(ocp.actual_amount_items, 0)                 AS actual_amount_items,
    COALESCE(ocp.total, 0)                              AS total_order_value,
    COALESCE(ocp.coupon_discount, 0)                    AS coupon_discount_duplicate

	
FROM order_report_sch.orders_with_coupons ocp;

SELECT count(DISTINCT order_id) FROM order_report_sch.orders_with_coupons;
SELECT * FROM order_report_sch.order_report_raw WHERE order_id_original = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404' ORDER BY order_item_id;

/* ORDERS FINAL REPORT */

DROP TABLE IF EXISTS order_report_sch.order_report_final;

CREATE TABLE order_report_sch.order_report_final AS
SELECT
    reservation_code                           AS "RID",
    order_number                               AS "Order Id",
    order_item_id                              AS "Line Item Id",
    created_on_items                           AS "Order Date",
    original_amount                            AS "Original Order Amount",
    order_level_refund                         AS "Order Refunded Amount",
    ROUND(total::numeric, 2)                   AS "Order Amount",
    payment_source                             AS "Order Type",
    payment_type                               AS "Payment Method",
    payment_provider_name                      AS "Payment Processor",
    is_refunded                                AS "Refunded?",
    COALESCE(user_name,'')                     AS "User",
    product_name                               AS "Product Name",
    start_date                                 AS "Rental Start Date",
    end_date                                   AS "Rental End Date",
    location_name                              AS "Location",
    site_name                                  AS "Subsite Location",
    total_items                                AS "Line Item Sub Total",
    coupon_code                                AS "Promo Code Id",
    ROUND(coupon_discount::numeric, 2)         AS "Coupon Amount",
    discount                                   AS "Line Item Discount",
    tip                                        AS "Gratuity",
    ROUND(final_line_item_sub_total::numeric, 2)           AS "Final Line Item Sub Total",
    ROUND(line_item_booking_fee::numeric, 2)               AS "Booking Fee",
    ROUND(create_line_item_processing_fee::numeric, 2)     AS "Create Line Item Payment Processor Fee",
    ROUND(refund_line_item_processing_fee::numeric, 2)     AS "Refund Line Item Payment Processor Fee",
    ROUND((create_line_item_processing_fee - refund_line_item_processing_fee)::numeric, 2) 
        AS "Total Line Item Payment Processor Fee",
    tax_percentage                             AS "Tax%",
    ROUND(sales_tax::numeric, 2)               AS "Tax",
    delivery_fee                               AS "Delivery Fee",
    ROUND((
        tip + final_line_item_sub_total + line_item_booking_fee + sales_tax
        - (create_line_item_processing_fee - refund_line_item_processing_fee)
    )::numeric, 2)                              AS "Total Collected",
    partner_name                               AS "Partner Name",
    partner_id									AS "Partner Id"
FROM order_report_sch.order_report_raw;

SELECT count(DISTINCT "Order Id") FROM order_report_sch.order_report_final;

SELECT DISTINCT * FROM order_report_sch.order_report_final WHERE "RID" = 'LDV0014809' ORDER BY "Line Item Id";
SELECT DISTINCT * FROM order_report_sch.order_report_final WHERE "RID" = 'LDV0014980' ORDER BY "Line Item Id";

DROP TABLE IF EXISTS order_report_sch.order_report_g;

CREATE TABLE order_report_sch.order_report_g AS
SELECT f.*
FROM order_report_sch.order_report_final f
INNER JOIN order_report_sch.expected_order_ids e 
  ON f."Order Id"::BIGINT = e.order_number;

--CHECK--
SELECT count(DISTINCT "Order Id") FROM order_report_sch.order_report_g;

SELECT DISTINCT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014809' ORDER BY "Line Item Id";
SELECT DISTINCT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014980' ORDER BY "Line Item Id";
