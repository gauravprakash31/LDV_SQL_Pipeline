DROP SCHEMA clean_sch CASCADE;
CREATE SCHEMA clean_sch;

/* ORDERS */
--orders
CREATE TABLE clean_sch.orders AS
SELECT
	"Id" 					AS order_id,
	"ReservationId" 		AS reservation_id,
	"PaymentTransactionId" 	AS payment_transaction_id,
	"CreatedBy"				AS created_by,
	"BookingFee" 			AS booking_fee,
	"DeliveryFee" 			AS delivery_fee,
	"Total" 				AS total,
	"OrderNumber" 			AS order_number
FROM stage_sch.orders
WHERE "Id" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

--order_items
CREATE TABLE clean_sch.order_items AS
SELECT
	"Id"					AS order_items_id,
	"OrderId"				AS order_id,
	"ProductId"				AS product_id,
	"LocationId"			AS location_id,
	"SiteId"				AS site_id,
	"RentalTypeId"			AS rental_type_id,
	"CouponDiscount"		AS coupon_discount,
	"Tip"					AS tip,
	"Discount"				AS discount,
	"SalesTax"				AS sales_tax,
	"TotalAmount"			AS total_amount,
	"CreatedOn"				AS created_on,
	"IsRefunded"			AS is_refunded,
	"StartDate"				AS start_date,
	"EndDate"				AS end_date
FROM stage_sch.order_items
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

--order_item_history
CREATE TABLE clean_sch.order_item_history AS
SELECT
	"Id"					AS order_item_history_id,
	"OrderId"				AS order_id,
	"ProductId"				AS product_id,
	"LocationId"			AS location_id,
	"SiteId"				AS site_id,
	"CreatedOn"				AS created_on,
--  "LineItemId"			AS line_item_id, -- is the order item tables id-- have to use joins
--  "PaymentTransactionId"	AS payment_transaction_id	
FROM stage_sch.order_items_hist
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

--order_history
CREATE TABLE clean_sch.order_history AS
SELECT
	"Id" 					AS order_history_id,
	"OrderId"				AS order_id,
	"UserId"				AS user_id,
	"RefundedTotal"			AS refunded_total,
	"RefundOrderNumber"		AS refund_order_number
FROM stage_sch.order_hist 
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

/* RESERVATIONS */
--reservations
CREATE TABLE clean_sch.reservations AS
SELECT
	"Id"					AS reservation_id,
	"ReservationCode"		AS reservation_code
FROM stage_sch.reservations;

/* USERS */
--users
DROP TABLE clean_sch.users;
CREATE TABLE clean_sch.users AS
SELECT
	"Id"					AS users_id,
	CONCAT("FirstName", ' ', "LastName") AS user_name
--	"CreatedBy"				AS created_by -- All the places that say "created by" is their foreign key, what do i do? its all different everywhere
FROM stage_sch.users;
SELECT * FROM clean_sch.users;

/* PRODUCTS */
--products
CREATE TABLE clean_sch.products AS
SELECT
	"Id" 					AS product_id,
	"Name"					AS product_name
FROM stage_sch.products;

--rental_types
CREATE TABLE clean_sch.rental_types AS
SELECT 
	"Id" 					AS rental_types_id,
	"Name"					AS rental_name
FROM stage_sch.rental_types;

/* LOCATIONS */
--locations
CREATE TABLE clean_sch.locations AS
SELECT 
	"Id"					AS location_id,
--  "SiteId"				AS site_id,	
	"Name"					AS location_name,
	"TaxRate"				AS tax_rate

-- what are subsite name and subsite taxrate?	
FROM stage_sch.locations;

/* PAYMENTS */
--payment_transactions
CREATE TABLE clean_sch.payment_transactions AS
SELECT
	"Id"					AS payment_transaction_id,
	"OrderId"				AS order_id,
	"ProcessingFee"			AS processing_fee,
	"Source"				AS "source", --put this in double quotes cause its a func name
	"Amount"				AS amount,
	"PaymentType"			AS payment_type,
	"PaymentProviderName"	AS payment_provider_name
FROM stage_sch.payment_transactions
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

--partners
CREATE TABLE clean_sch.partners AS
SELECT
	"Id" 					AS partner_id,
	"Name"					AS partner_name
FROM stage_sch.partners;
	
--payment_refund-- in stage_sch (connected to refund and payment transaction id)
CREATE TABLE clean_sch.payment_refund AS
SELECT
	"Id" 					AS payment_refund_id,
	"PaymentTransactionId" 	AS payment_transaction_id,
	"RefundedProcessingFee"	AS refunded_processing_fee
FROM stage_sch.payment_refund;

/* COUPONS */
--coupons
CREATE TABLE clean_sch.coupons AS
SELECT
	"Id" 					AS coupon_id,
	"CouponCode"			AS coupon_code
FROM stage_sch.coupons;