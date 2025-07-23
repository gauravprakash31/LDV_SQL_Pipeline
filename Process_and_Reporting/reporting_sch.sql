/* ORDER REPORT */
DROP TABLE IF EXISTS reporting_sch.order_report_final;

CREATE TABLE reporting_sch.order_report_final AS
SELECT
    reservation_code				AS "RID",
    order_number					AS "Order Id",
    order_item_id                   AS "Line Item Id",
	order_date						AS "Order Date",
	original_order_amount 			AS "Original Order Amount",
	order_refunded_amount			AS "Order Refunded Amount",
	order_amount					AS "Order Amount", 
	order_type						AS "OrderType", 
	payment_type					AS "Payment Method",
    payment_provider_name			AS "Payment Processer",
    is_refunded						AS "Refunded?",
	user_name						AS "User", -- why is Prasad Polsani everywhere?
	product_name					AS "Product Name",
    start_date						AS "Rental Start Date",
    end_date						AS "Rental End Date",
    location_name                   AS "Location",
    site_name                       AS "Substitue Location",
  --tax_percentage,-- is this the *Tax Counties* thing? why does it say Later in the description
  	total_amount_items				AS "Line Item Sub Total", -- fix
	promo_code_id					AS "Promo Code Id",
    coupon_discount					AS "Coupon Amount",
    line_item_discount				AS "Line Item Discount",			
    gratuity                        AS "Gratuity",
	final_line_item_sub_total       AS "Final Line Item Sub Total", -- fix
    booking_fee						AS "Booking Fee", -- fix
    create_lineitem_processing_fee  AS "Create Line Item Payment Processor Fee", -- fix
    refund_lineitem_processing_fee  AS "Refund Line Item Payment Processor Fee", -- fix
	total_lineitem_processing_fee   AS "Total Line Item Payment Processor Fee", -- fix
	tax_percentage					AS "Tax%",  
    sales_tax 						AS "Tax", 
	delivery_fee					AS "Delivery Fee",	
    total_collected					AS "Total Collected", -- fix
	partner_name					AS "Parner Name",
	partner_id						AS "PartnerId" 
	
FROM reporting_sch.order_report_raw WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

--SELECT * FROM reporting_sch.order_report_final;


/* REFUND REPORT */
DROP TABLE IF EXISTS reporting_sch.refund_report_final;

CREATE TABLE reporting_sch.refund_report_final AS
SELECT
    rid                         AS "RID",
    order_number                AS "OrderId",
    order_item_id               AS "LineItemId",
    original_order_date         AS "OriginalOrderDate",
    --transaction_date            AS "TransactionDate", --ERROR:  column "transaction_date" does not exist
    original_line_item_amount   AS "OriginalLineItemAmount",
    order_type                  AS "OrderType",
    refund_amount               AS "RefundAmount", -- should be null- fix
    --transaction_type            AS "TransactionType", -- fix
    payment_type                AS "PaymentMethod",
    payment_provider_name       AS "PaymentProcessor",
    refund_order_id             AS "RefundOrderId",
    user_name                   AS "User",
    product_name                AS "ProductName",
    --rental_name                 AS "RentalType",
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
FROM reporting_sch.refund_report_raw WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';;

SELECT * FROM reporting_sch.refund_report_final;
