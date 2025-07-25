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
    oih.booking_fee       AS line_item_booking_fee
FROM clean_sch.orders o
LEFT JOIN clean_sch.reservations r       ON r.reservation_id = o.reservation_id
LEFT JOIN clean_sch.order_items oi       ON oi.order_id = o.order_id
LEFT JOIN clean_sch.order_history oh     ON oh.order_id = o.order_id
LEFT JOIN clean_sch.order_item_history oih ON oih.order_item_id = oi.order_item_id;


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
        0
    )                               AS final_line_item_sub_total,
    ocp.line_item_booking_fee       AS booking_fee,
    (COALESCE(processing_fee, 0) * total_amount_items / NULLIF(total, 0)) AS create_lineitem_processing_fee,
    (COALESCE(refunded_processing_fee, 0) * total_amount_items / NULLIF(total, 0)) AS refund_lineitem_processing_fee,
    ((COALESCE(processing_fee, 0) * total_amount_items / NULLIF(total, 0)) - (COALESCE(refunded_processing_fee, 0) * total_amount_items / NULLIF(total, 0))) AS total_line_item_processing_fee,
    ocp.tax_percentage              AS tax_p,
    ocp.sales_tax                   AS tax,
    ocp.delivery_fee,
  	(
        GREATEST(
            COALESCE(total_items, 0)
            - COALESCE(coupon_discount, 0)
            - COALESCE(discount, 0),
            0
        )
        + COALESCE(ocp.line_item_booking_fee, 0)
        + COALESCE(ocp.tip, 0)
        + COALESCE(ocp.sales_tax, 0)
        + COALESCE(ocp.delivery_fee, 0)
        - (COALESCE(ocp.processing_fee, 0) * ocp.total_amount_items / NULLIF(ocp.total, 0))
    )                               AS total_collected,
    ocp.partner_name,
    ocp.partner_id,
    ocp.order_booking_fee,
    ocp.processing_fee,
    ocp.refunded_processing_fee,
    ocp.total_amount_items,
    ocp.coupon_discount
FROM process_sch.orders_with_coupons ocp;


/* REFUND */
CREATE SCHEMA IF NOT EXISTS refund_report_sch;
DROP TABLE IF EXISTS refund_report_sch.refund_report_raw;

CREATE TABLE refund_report_sch.refund_report_raw AS
SELECT
    p.order_id,
    p.order_item_id,
    p.order_number,
    p.reservation_code           AS rid,
    rt.rental_name,
    p.created_on_items           AS original_order_date,
    ih.created_on                AS transaction_date,
    p.line_item_booking_fee      AS booking_fee,
    p.total_amount_items         AS original_line_item_amount,
    CASE WHEN ih.order_item_history_id IS NOT NULL THEN 'Refund' ELSE 'Payment' END AS transaction_type,
    oh.refunded_total            AS refund_amount,
    oh.refund_order_number       AS refund_order_id,
    pt.payment_source            AS order_type,
    pt.payment_type,
    pt.payment_provider_name,
    p.user_name,
    p.product_name,
    p.start_date,
    p.end_date,
    p.location_name,
    p.site_name,
    p.tax_percentage,
    p.total_items                AS line_item_sub_total,
    p.coupon_code                AS promo_code_id,
    p.coupon_discount,
    p.discount                   AS line_item_discount,
    p.tip                        AS gratuity,
    GREATEST(
        COALESCE(p.total_items, 0)
        - COALESCE(p.coupon_discount, 0)
        - COALESCE(p.discount, 0),
        0
    )                             AS final_line_item_sub_total,
    p.delivery_fee,
    (COALESCE(p.processing_fee, 0) * p.total_amount_items / NULLIF(p.total, 0)) AS processing_fee,
    p.sales_tax,
    p.tax_percentage             AS tax_p,
    (
        GREATEST(
            COALESCE(p.total_items, 0)
            - COALESCE(p.coupon_discount, 0)
            - COALESCE(p.discount, 0),
            0
        )
        + COALESCE(p.line_item_booking_fee, 0)
        + COALESCE(p.tip, 0)
        + COALESCE(p.sales_tax, 0)
        + COALESCE(p.delivery_fee, 0)
        - (COALESCE(p.processing_fee, 0) * p.total_amount_items / NULLIF(p.total, 0))
    )                             AS total_collected,
    CASE WHEN pt.payment_source = 'Consumer Web' THEN NULL ELSE p.partner_name END AS partner_name,
    CASE WHEN pt.payment_source = 'Consumer Web' THEN NULL ELSE p.partner_id END   AS partner_id
FROM process_sch.orders_with_coupons p
LEFT JOIN clean_sch.order_item_history ih  ON ih.order_item_id = p.order_item_id
LEFT JOIN clean_sch.order_history oh        ON oh.order_id       = p.order_id
LEFT JOIN clean_sch.users u                 ON u.users_id        = COALESCE(oh.user_id, p.created_by)
LEFT JOIN clean_sch.rental_types rt         ON rt.rental_types_id = p.rental_type_id
LEFT JOIN clean_sch.payment_transactions pt ON pt.order_id       = p.order_id