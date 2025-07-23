/* ORDER REPORT */
DROP TABLE IF EXISTS reporting_sch.order_report_final;

CREATE TABLE reporting_sch.order_report_final AS
SELECT
    reservation_code				AS "RID",
    order_number					AS "Order Id",
    order_items_id                  AS "Line Item Id",
    order_date						AS "Order Date",
	original_order_amount 			AS "Original Order Amount",
	order_refunded_amount			AS "Order Refunded Amount",
	order_amount					AS "Order Amount", -- tried ROUND() but not working
	order_type						AS "OrderType",
	payment_type					AS "Payment Method",
    payment_provider_name			AS "Payment Processer",
    is_refunded						AS "Refunded?",
	user_name						AS "User",
	product_name					AS "Product Name",
    start_date						AS "Rental Start Date",
    end_date						AS "Rental End Date",
    location_name                   AS "Location",
    site_name                       AS "Substitue Location",
  --tax_percentage,-- is this the *Tax Counties* thing? why does it say Later in the description
  	total_items						AS "Line Item Sub Total",
	promo_code_id					AS "Promo Code Id",
    coupon_discount					AS "Coupon Amount",
    line_item_discount				AS "Line Item Discount",			
    gratuity                        AS "Gratuity",
	final_line_item_sub_total       AS "Final Line Item Sub Total",
    booking_fee						AS "Booking Fee",
    create_lineitem_processing_fee  AS "Create Line Item Payment Processor Fee",
    refund_lineitem_processing_fee  AS "Refund Line Item Payment Processor Fee",
	total_lineitem_processing_fee   AS "Total Line Item Payment Processor Fee",
	tax_percentage					AS "Tax%",  
    sales_tax 						AS "Tax",
	delivery_fee					AS "Delivery Fee",	
    total_collected					AS "Total Collected",
	partner_name					AS "Parner Name",
	partner_id						AS "PartnerId" 
	
FROM reporting_sch.order_report_raw;

SELECT * FROM reporting_sch.order_report_final;

/*/* REFUND REPORT */
DROP TABLE IF EXISTS report_sch.refund_report_raw;

CREATE TABLE report_sch.refund_report_raw AS
SELECT
    /* === keys === */
    p.order_id,
    p.order_item_id,
    p.order_number,
    p.reservation_code                              AS rid,

    /* === original order info === */
    p.created_on_items                              AS original_order_date,
    ih.created_on                                   AS transaction_date,        -- from OrderItemsHistory
    p.total_amount_items                            AS original_line_item_amount,

    /* === refund meta === */
    CASE
        WHEN ih.id IS NOT NULL THEN 'Refund'
        ELSE 'Payment'
    END                                             AS transaction_type,

    oh.refunded_total                               AS refund_amount,            -- order-level
    oh.refund_order_number                          AS refund_order_id,

    /* === payment info === */
    pt.source                                       AS order_type,
    pt.payment_type,
    pt.payment_provider_name,

    /* === user & product === */
    p.user_name,
    p.product_name,
    p.rental_name,
    p.start_date,
    p.end_date,

    /* === location === */
    p.location_name,
    p.site_name,
    p.tax_percentage,

    /* === discounts / promo === */
    p.total_amount_items                            AS line_item_sub_total,
    p.coupon_code                                   AS promo_code_id,
    p.coupon_discount,
    p.discount                                      AS line_item_discount,
    p.tip                                           AS gratuity,

    /* === line-level calc === */
    p.total_amount_items
      - p.coupon_discount
      - p.discount                                  AS final_line_item_sub_total,

    /* === fees & tax === */
    p.booking_fee,
    p.delivery_fee,
    p.processing_fee,
    p.sales_tax,

    /* === total collected (same formula as order report) === */
    p.paid_amount
      - oh.refunded_total
      - COALESCE(pr.refunded_processing_fee,0)      AS total_collected,

    /* === partner === */
    p.partner_name,
    p.partner_id

FROM process_sch.orders_with_coupons           p
/* line-item–level history (has CreatedOn and maybe TransactionType) */
LEFT JOIN clean_sch.order_items_history        ih
       ON ih.order_item_id = p.order_item_id
/* order-level refund totals */
LEFT JOIN clean_sch.order_history              oh
       ON oh.order_id       = p.order_id
/* payment transaction & refund fee */
LEFT JOIN clean_sch.payment_transactions       pt
       ON pt.order_id      = p.order_id
LEFT JOIN clean_sch.payment_refund             pr
       ON pr.payment_transaction_id = pt.payment_transaction_id
;

/* ----------------------------------------------------------------
   2. FINAL – only the columns & headers in the PDF
   ---------------------------------------------------------------- */
DROP TABLE IF EXISTS reporting_sch.refund_report_final;

CREATE TABLE reporting_sch.refund_report_final AS
SELECT
    rid                         AS "RID",
    order_number                AS "OrderId",
    order_items_id               AS "LineItemId",
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
FROM reporting_sch.refund_report_raw;
*/