/*ORDERS_DB*/
--orders

DROP SCHEMA IF EXISTS clean_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS clean_sch;

DROP TABLE IF EXISTS clean_sch.orders;
CREATE TABLE clean_sch.orders AS
SELECT
	"Id" 					AS order_id,
	"ReservationId" 		AS reservation_id,
	"PaymentTransactionId" 	AS payment_transaction_id,
	"CreatedBy"				AS created_by,
	"BookingFee" 			AS order_booking_fee,
	"Total" 				AS total,
	"OrderNumber" 			AS order_number
FROM stage_sch.orders;

--order_items
DROP TABLE IF EXISTS clean_sch.order_items;
CREATE TABLE clean_sch.order_items AS
SELECT

	"Id"					AS order_item_id,
	"OrderId"				AS order_id,
	"ProductId"				AS product_id,
	"LocationId"			AS location_id,
	"BookingFee"			AS booking_fee_item,
	"SiteId"				AS site_id,
	"RentalTypeId"			AS rental_type_id,
	"CouponDiscount"		AS coupon_discount,
	"DeliveryFee"			AS delivery_fee,
	"Tip"					AS tip,
	"Discount"				AS discount,
	"SalesTax"				AS sales_tax,
	"Total"					AS total_items,
	"TotalAmount"			AS total_amount_items,
	"CreatedOn"				AS created_on_items,
	"ModifiedOn"			AS modified_on_items,
	"IsRefunded"			AS is_refunded,
	"StartDate"				AS start_date,
	"EndDate"				AS end_date,
	"PartnerId"				AS partner_id
FROM stage_sch.order_items;

--order_history
DROP TABLE IF EXISTS clean_sch.order_history;
CREATE TABLE clean_sch.order_history AS
SELECT
	"Id" 					AS order_history_id,
	"OrderId"				AS order_id,
	"UserId"				AS user_id,
	"RefundedTotal"			AS refunded_total,
	"RefundOrderNumber"		AS refund_order_number
	
FROM stage_sch.order_history;

--order_item_history
DROP TABLE IF EXISTS clean_sch.order_items_history;
CREATE TABLE clean_sch.order_items_history AS
SELECT
	"Id"					AS order_item_history_id,
	"OrderId"				AS order_id,
	"ProductId"				AS product_id,
	"LocationId"			AS location_id,
	"SiteId"				AS site_id,
	"CreatedOn"				AS created_on,
	"TotalAmount"			AS total_amount_items_history	
	
FROM stage_sch.order_items_history;

--reservations
DROP TABLE IF EXISTS clean_sch.reservations;
CREATE TABLE clean_sch.reservations AS
SELECT
	"Id"					AS reservation_id,
	"ReservationCode"		AS reservation_code
FROM stage_sch.reservations;

---order_coupons
DROP TABLE IF EXISTS clean_sch.order_coupons;

CREATE TABLE clean_sch.order_coupons AS
SELECT
	"OrderId" 				AS order_id,
	"CouponId"				AS coupon_id,
	"OrderItemId"			AS order_item_id
FROM stage_sch.order_coupons;

--coupons
DROP TABLE IF EXISTS clean_sch.coupons;
CREATE TABLE clean_sch.coupons AS
SELECT
	"Id" 					AS coupon_id,
	"CouponCode"			AS coupon_code
FROM stage_sch.coupons;


--Orders Dynamic Tables
--DC_Values

--DC_Values
DROP TABLE IF EXISTS clean_sch.dc_o;
CREATE TABLE clean_sch.dc_o AS
SELECT

	"Id" 			AS dc_id_o,
	"Name"			AS dc_name_o,
	"ShowInExport"	AS show_in_export_o
	
FROM stage_sch.dc_o;

--DC_Options

DROP TABLE IF EXISTS clean_sch.dc_options_o;
CREATE TABLE clean_sch.dc_options_o AS
SELECT
	"Id" 						AS dc_option_id_o,
	"DynamicControlId"			AS dc_id_o,
	"Option"					AS dc_option_o
FROM stage_sch.dc_options_o;

--DC_Values

DROP TABLE IF EXISTS clean_sch.dc_values_o;
CREATE TABLE clean_sch.dc_values_o AS
SELECT

	"OrderId" 					AS dc_order_id_o,
	"DynamicControlOptionId"	AS dc_option_id_o
	
FROM stage_sch.dc_values_o;

--DC_items

DROP TABLE IF EXISTS clean_sch.dc_items_o;
CREATE TABLE clean_sch.dc_items_o AS
SELECT

"Id"							AS  dc_item_id_o,
"OrderItemId"					AS  dc_order_item_id,
"DynamicControlId"				AS	dc_id_o,
"DynamicControlOptionId"		AS	dc_option_id_o,
"DynamicControlType"			AS	dc_type

	
FROM stage_sch.dc_items_o;

--/* PRODUCTS_DB */
--products
DROP TABLE IF EXISTS clean_sch.products;
CREATE TABLE clean_sch.products AS
SELECT
	"Id" 					AS product_id,
	"Name"					AS product_name
FROM stage_sch.products;

--rental_types

DROP TABLE IF EXISTS clean_sch.rental_types;
CREATE TABLE clean_sch.rental_types AS
SELECT 
	"Id" 					AS rental_types_id,
	"Name"					AS rental_name
FROM stage_sch.rental_types;

--Dynamic Control
-- products dynamic controls
DROP TABLE IF EXISTS clean_sch.rental_types;
CREATE TABLE clean_sch.dc_p  AS
SELECT
    "Id"    AS dc_id_p,
    "Name"  AS dc_name_p,
	"ShowInExport"	AS show_in_export_p
	
FROM stage_sch.dc_p;

CREATE TABLE clean_sch.dc_options_p AS
SELECT

    "Id"               AS dc_option_id_p,
    "DynamicControlId" AS dc_id_p,
    "Option"           AS dc_option_p
	
FROM stage_sch.dc_options_p;

CREATE TABLE clean_sch.dc_values_p AS
SELECT

    "Id"					AS dc_values_id_p,
	"ProductId"             AS product_id,
    "DynamicControlOptionId" AS dc_option_id_p
	
FROM stage_sch.dc_values_p;

/* LOCATIONS */

--locations
DROP TABLE IF EXISTS clean_sch.locations;
CREATE TABLE clean_sch.locations AS
SELECT

	"Id"					AS location_id,	
	"Name"					AS location_name,
	"TaxRate"				AS tax_rate
	
FROM stage_sch.locations;

-- locations dynamic controls
CREATE TABLE clean_sch.dc_l  AS
SELECT
    "Id"    AS dc_id_l,
    "Name"  AS dc_name_l,
	"ShowInExport"	AS show_in_export_l
	
FROM stage_sch.dc_l;

CREATE TABLE clean_sch.dc_options_l AS
SELECT
    "Id"               AS dc_option_id_l,
    "DynamicControlId" AS dc_id_l,
    "Option"           AS dc_option_l
FROM stage_sch.dc_options_l;

CREATE TABLE clean_sch.dc_values_l AS
SELECT
    "Id"					AS dc_values_id_l,
	"LocationId"            AS location_id,
    "DynamicControlOptionId" AS dc_option_id_l
FROM stage_sch.dc_values_l;

/* USERS */

--users
DROP TABLE IF EXISTS clean_sch.users;
CREATE TABLE clean_sch.users AS
SELECT
	"Id"					AS users_id,
	CONCAT("FirstName", ' ', "LastName") AS user_name
	
FROM stage_sch.users;


/* PAYMENTS */

--payment_transactions
DROP TABLE IF EXISTS clean_sch.payment_transactions;
CREATE TABLE clean_sch.payment_transactions AS
SELECT
	"Id"					AS payment_transaction_id,
	"OrderId"				AS order_id,
	"ProcessingFee"			AS processing_fee,
	"Source"				AS payment_source, 
	"Amount"				AS amount,
	"PaymentType"			AS payment_type,
	"PaymentProviderName"	AS payment_provider_name
	
FROM stage_sch.payment_transactions;

--partners
DROP TABLE IF EXISTS clean_sch.partners;
CREATE TABLE clean_sch.partners AS
SELECT
	"Id" 					AS partner_id,
	"Name"					AS partner_name
	
FROM stage_sch.partners;
	
--payment_refund-- in stage_sch (connected to refund and payment transaction id)

DROP TABLE IF EXISTS clean_sch.payment_refund;
CREATE TABLE clean_sch.payment_refund AS
SELECT
	"Id" 					AS payment_refund_id,
	"PaymentTransactionId" 	AS payment_transaction_id,
	"RefundedProcessingFee"	AS refunded_processing_fee
	
FROM stage_sch.payment_refund;

