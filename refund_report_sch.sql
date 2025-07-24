DROP TABLE IF EXISTS refund_report_sch.refund_report_final CASCADE;

CREATE TABLE refund_report_sch.refund_report_final AS
SELECT
    rid                         AS "RID",
    order_number                AS "Order Id",
    order_item_id               AS "Line Item Id",
    original_order_date         AS "Original Order Date",
    transaction_date            AS "Transaction Date",
    original_line_item_amount   AS "Original Line Item Amount",
    order_type                  AS "Order Type",
    refund_amount               AS "RefundAmount",
    transaction_type            AS "Transaction Type",
    payment_type                AS "Payment Method",
    payment_provider_name       AS "Payment Processor",
    refund_order_id             AS "Refund Order Id",
    user_name                   AS "User",
    product_name                AS "Product Name",
    rental_name                 AS "Rental Type", 
    start_date                  AS "Rental Start Date",
    end_date                    AS "Rental End Date",
    location_name               AS "Location",
    site_name                   AS "Subsite Location",
	-- tax counties
	line_item_sub_total         AS "Line Item Sub Total",
    promo_code_id               AS "Promo Code Id",
    coupon_discount             AS "Coupon Amount",
    line_item_discount          AS "Line Item Discount",
    gratuity                    AS "Gratuity",
    final_line_item_sub_total   AS "Final Line Item Sub Total",
    booking_fee                 AS "Booking Fee",
    processing_fee              AS "Processing Fees",
	tax_p						AS "Tax%",  
    sales_tax                   AS "Tax",
    delivery_fee                AS "Delivery Fee",
    total_collected             AS "Total Collected", 
    partner_name                AS "Partner Name",
    partner_id                  AS "PartnerId"
FROM refund_report_sch.refund_report_raw;

SELECT * FROM refund_report_sch.refund_report_final WHERE "RID" = 'LDV0014980'
ORDER BY "Line Item Id" ASC;