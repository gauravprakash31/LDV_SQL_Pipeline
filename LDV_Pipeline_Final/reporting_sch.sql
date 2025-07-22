DROP TABLE IF EXISTS reporting_sch.order_report_final;

CREATE TABLE reporting_sch.order_report_final AS
SELECT
    reservation_code,
    order_number,
    order_items_id                     AS line_item_id,
    order_date,
    user_name,
    product_name,
    start_date,
    end_date,
    location_name                      AS location,
    site_name                          AS substitue_location,
    tax_percentage,
    promo_code_id,
    coupon_discount,
    line_item_discount,
    gratuity                           AS tip,
    final_line_item_sub_total          AS line_subtotal,
    booking_fee,
    delivery_fee,
    create_lineitem_processing_fee     AS processing_fee,
    refund_lineitem_processing_fee     AS processing_fee_refund,
    total_lineitem_processing_fee      AS processing_fee_total,
    sales_tax,
    total_collected,
    order_level_refund,
    paid_amount,
    order_type                         AS order_source,
    payment_type,
    payment_provider_name,
    partner_name,
    is_refunded
FROM reporting_sch.order_report_raw;

SELECT * FROM reporting_sch.order_report_final;