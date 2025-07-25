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
	order_amount					AS "Order Amount", 
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
    coupon_amount					AS "Coupon Amount",
    line_item_discount				AS "Line Item Discount",			
    gratuity                        AS "Gratuity",
	final_line_item_sub_total       AS "Final Line Item Sub Total",
    booking_fee						AS "Booking Fee",
    create_lineitem_processing_fee  AS "Create Line Item Payment Processor Fee",
    refund_lineitem_processing_fee  AS "Refund Line Item Payment Processor Fee", 
	total_line_item_processing_fee   AS "Total Line Item Payment Processor Fee", 
	tax_p							AS "Tax%",  
    tax		 						AS "Tax", 
	delivery_fee					AS "Delivery Fee",	
    total_collected					AS "Total Collected",
	partner_name					AS "Parner Name",
	partner_id						AS "PartnerId" 
	
FROM order_report_sch.order_report_raw; --WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

SELECT * FROM order_report_sch.order_report_final 
WHERE "RID" = 'LDV0014980'
ORDER BY "Line Item Id" ASC; --WHERE "Order Id" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';