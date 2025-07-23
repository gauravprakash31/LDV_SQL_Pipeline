DROP SCHEMA IF EXISTS process_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS process_sch;

--DROP TABLE IF EXISTS process_sch.orders_with_items            CASCADE;
--DROP TABLE IF EXISTS process_sch.orders_with_p_l_u            CASCADE;
--DROP TABLE IF EXISTS process_sch.orders_with_payments         CASCADE;
--DROP TABLE IF EXISTS process_sch.orders_with_coupons          CASCADE;
--DROP TABLE IF EXISTS process_sch.order_report_raw             CASCADE;
--DROP TABLE IF EXISTS process_sch.order_report_final           CASCADE;


/* orders -> items -> reservations -> history */
CREATE TABLE process_sch.orders_with_items AS
SELECT
    o.order_id,
    o.reservation_id,
    o.payment_transaction_id,
    o.created_by,
    o.booking_fee,
    o.delivery_fee,
    o.total,
    o.order_number,
    r.reservation_code,
    oi.order_items_id,
    oi.product_id,
    oi.location_id,
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
    oh.refunded_total   AS order_level_refund
FROM clean_sch.orders o
LEFT JOIN clean_sch.reservations r ON r.reservation_id = o.reservation_id
LEFT JOIN clean_sch.order_items oi ON oi.order_id = o.order_id
LEFT JOIN clean_sch.order_history oh ON oh.order_id = o.order_id;


/* add product, location/site, user, partner */
CREATE TABLE process_sch.orders_with_p_l_u AS
SELECT
    base.*,
    p.product_name,
    l.location_name,
    site.location_name AS site_name,
    u.user_name,
    pa.partner_name,
    COALESCE(site.tax_rate, l.tax_rate) AS tax_percentage
FROM process_sch.orders_with_items base
LEFT JOIN clean_sch.products p ON p.product_id = base.product_id
LEFT JOIN clean_sch.locations l ON l.location_id = base.location_id
LEFT JOIN clean_sch.locations site ON site.location_id = base.site_id
LEFT JOIN clean_sch.users u ON u.users_id = base.created_by
LEFT JOIN clean_sch.partners pa ON pa.partner_id = base.partner_id;


/* add payment and refund info */
CREATE TABLE process_sch.orders_with_payments AS
SELECT
    plu.*,
    pt.amount AS paid_amount,
    pt.processing_fee,
    pr.refunded_processing_fee,
    pt.source AS order_type,
    pt.payment_type,
    pt.payment_provider_name
FROM process_sch.orders_with_p_l_u plu
LEFT JOIN clean_sch.payment_transactions pt ON pt.order_id = plu.order_id
LEFT JOIN clean_sch.payment_refund pr ON pr.payment_transaction_id = pt.payment_transaction_id;


/* aggregate coupon codes */ -- should go with orders
CREATE TABLE process_sch.orders_with_coupons AS
WITH agg AS (
    SELECT
        oc.order_items_id,
        STRING_AGG(c.coupon_code, ',' ORDER BY c.coupon_code) AS coupon_code
    FROM clean_sch.order_coupons oc
    JOIN clean_sch.coupons c ON c.coupon_id = oc.coupon_id
    GROUP BY oc.order_items_id
)
SELECT
    pay.*,
    agg.coupon_code
FROM process_sch.orders_with_payments pay
LEFT JOIN agg ON agg.order_items_id = pay.order_items_id;


/* === REPORT LAYER === */
DROP SCHEMA IF EXISTS reporting_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS reporting_sch;


/* ORDER REPORT - raw layer */
CREATE TABLE reporting_sch.order_report_raw AS
SELECT
    ocp.order_id,
    ocp.order_items_id,
    ocp.order_number,
    ocp.reservation_code,
    ocp.created_on_items AS order_date,
    ocp.user_name,
    ocp.product_name,
    ocp.start_date,
    ocp.end_date,
    ocp.location_name,
    ocp.site_name,
    ocp.tax_percentage,
    ocp.total AS order_amount,
    ocp.order_level_refund AS order_refunded_amount,
    ocp.paid_amount AS original_order_amount,
    ocp.processing_fee,
    ocp.refunded_processing_fee,
    ocp.booking_fee,
    ocp.delivery_fee,
    ocp.sales_tax,
    ocp.total_amount_items,
	ocp.total_items,
    ocp.coupon_code AS promo_code_id,
    ocp.coupon_discount,
    ocp.discount AS line_item_discount,
    ocp.tip AS gratuity,
    ocp.total_amount_items - ocp.coupon_discount - ocp.discount AS final_line_item_sub_total,
    ocp.processing_fee * (ocp.total_amount_items / NULLIF(ocp.total,0)) AS create_lineitem_processing_fee,
    ocp.refunded_processing_fee * (ocp.total_amount_items / NULLIF(ocp.total,0)) AS refund_lineitem_processing_fee,
    (ocp.processing_fee + COALESCE(ocp.refunded_processing_fee,0)) * (ocp.total_amount_items / NULLIF(ocp.total,0)) AS total_lineitem_processing_fee,
    ocp.paid_amount - ocp.order_level_refund - COALESCE(ocp.refunded_processing_fee,0) AS total_collected,
    ocp.is_refunded,
    ocp.order_type,
    ocp.payment_type,
    ocp.payment_provider_name,
    ocp.partner_name,
    ocp.partner_id
FROM process_sch.orders_with_coupons ocp;


--SELECT COUNT(*) AS raw_rows FROM reporting_sch.order_report_raw;

/*/* REFUND REPORT - raw layer */
DROP TABLE IF EXISTS report_sch.refund_report_raw;

CREATE TABLE report_sch.refund_report_raw AS
SELECT
    p.order_id,
    p.order_item_id,
    p.order_number,
    p.reservation_code                              AS rid,
    p.created_on_items                              AS original_order_date,
    ih.created_on                                   AS transaction_date,
    p.total_amount_items                            AS original_line_item_amount,

    CASE
        WHEN ih.id IS NOT NULL THEN 'Refund'
        ELSE 'Payment'
    END                                             AS transaction_type,

    oh.refunded_total                               AS refund_amount,
    oh.refund_order_number                          AS refund_order_id,

    pt.source                                       AS order_type,
    pt.payment_type,
    pt.payment_provider_name,

    p.user_name,
    p.product_name,
    p.rental_name,
    p.start_date,
    p.end_date,

    p.location_name,
    p.site_name,
    p.tax_percentage,

    p.total_amount_items                            AS line_item_sub_total,
    p.coupon_code                                   AS promo_code_id,
    p.coupon_discount,
    p.discount                                      AS line_item_discount,
    p.tip                                           AS gratuity,

    p.total_amount_items
      - p.coupon_discount
      - p.discount                                  AS final_line_item_sub_total,

    p.booking_fee,
    p.delivery_fee,
    p.processing_fee,
    p.sales_tax,

    p.paid_amount
      - oh.refunded_total
      - COALESCE(pr.refunded_processing_fee,0)      AS total_collected,

    p.partner_name,
    p.partner_id

FROM process_sch.orders_with_coupons           p
LEFT JOIN clean_sch.order_items_history        ih ON ih.order_items_id = p.order_items_id --ERROR:  column ih.order_items_id does not exist
LEFT JOIN clean_sch.order_history              oh ON oh.order_id       = p.order_id
LEFT JOIN clean_sch.payment_transactions       pt ON pt.order_id      = p.order_id
LEFT JOIN clean_sch.payment_refund             pr ON pr.payment_transaction_id = pt.payment_transaction_id;
*/

