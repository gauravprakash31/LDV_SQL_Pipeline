DROP TABLE IF EXISTS refund_report_sch.refund_report_final;

CREATE TABLE refund_report_sch.refund_report_final AS
SELECT
    rid                         AS "RID",
    order_number                AS "OrderId",
    order_item_id               AS "LineItemId",
    original_order_date         AS "OriginalOrderDate",
    transaction_date            AS "TransactionDate",
    original_line_item_amount   AS "OriginalLineItemAmount",
    order_type                  AS "OrderType",
    refund_amount               AS "RefundAmount",
    transaction_type            AS "TransactionType",
    payment_type                AS "PaymentMethod",
    payment_provider_name       AS "PaymentProcessor",
    refund_order_id             AS "RefundOrderId",
    user_name                   AS "User",
    product_name                AS "ProductName",
    rental_name                 AS "RentalType", 
    start_date                  AS "RentalStartDate",
    end_date                    AS "RentalEndDate",
    location_name               AS "LocationName",
    site_name                   AS "SubsiteLocationName",
    tax_percentage              AS "TaxPercent",
    line_item_sub_total         AS "LineItemSubTotal",
    promo_code_id               AS "PromoCodeId",
    coupon_discount             AS "CouponAmount",
    line_item_discount          AS "LineItemDiscount",
    gratuity                    AS "Gratuity",
    final_line_item_sub_total   AS "FinalLineItemSubTotal",
    booking_fee                 AS "BookingFee",
    processing_fee              AS "ProcessingFees",
    sales_tax                   AS "Tax",
    delivery_fee                AS "DeliveryFee",
    total_collected             AS "TotalCollected", 
    partner_name                AS "PartnerName",
    partner_id                  AS "PartnerId"
FROM refund_report_sch.refund_report_raw;

SELECT * FROM refund_report_sch.refund_report_final WHERE "RID" = 'LDV0014980'
ORDER BY "LineItemId" ASC;