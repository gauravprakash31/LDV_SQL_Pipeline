/*ORDERS_DB*/
--orders
DROP TABLE IF EXISTS clean_sch.orders;
CREATE TABLE clean_sch.orders AS
SELECT
	"Id" 					AS order_id,
	"ReservationId" 		AS reservation_id,
	"PaymentTransactionId" 	AS payment_transaction_id,
	"CreatedBy"				AS created_by,
	"BookingFee" 			AS booking_fee,
	"Total" 				AS total,
	"OrderNumber" 			AS order_number
FROM stage_sch."Orders"
WHERE "Id" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';


--order_items
DROP TABLE IF EXISTS clean_sch.order_items;
CREATE TABLE clean_sch.order_items AS
SELECT
	"Id"					AS order_item_id,
	"OrderId"				AS order_id,
	"ProductId"				AS product_id,
	"LocationId"			AS location_id,
	"SiteId"				AS site_id,
	"RentalTypeId"			AS rental_type_id,
	"CouponDiscount"		AS coupon_discount,
	"DeliveryFee"			AS delivery_fee,
	"Tip"					AS tip,
	"Discount"				AS discount,
	"SalesTax"				AS sales_tax,
	"Total"					AS total_items,
	"TotalAmount"			AS total_amount_items,
	"CreatedOn"				AS created_on,
	"IsRefunded"			AS is_refunded,
	"StartDate"				AS start_date,
	"EndDate"				AS end_date,
	"PartnerId"				AS partner_id
FROM stage_sch."OrderItems"
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

--order_history
DROP TABLE IF EXISTS clean_sch.order_history;
CREATE TABLE clean_sch.order_history AS
SELECT
	"Id" 					AS order_history_id,
	"OrderId"				AS order_id,
	"UserId"				AS user_id,
	"RefundedTotal"			AS refunded_total,
	"RefundOrderNumber"		AS refund_order_number
FROM stage_sch."OrderHistory"
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

--order_item_history
DROP TABLE IF EXISTS clean_sch.order_item_history;
CREATE TABLE clean_sch.order_item_history AS
SELECT
	"Id"					AS order_item_history_id,
	"OrderId"				AS order_id,
	"ProductId"				AS product_id,
	"LocationId"			AS location_id,
	"SiteId"				AS site_id,
	"CreatedOn"				AS created_on,
	"TotalAmount"			AS total_amount_items_history	
FROM stage_sch."OrderItemsHistory"
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

--reservations
DROP TABLE IF EXISTS clean_sch.reservations;
CREATE TABLE clean_sch.reservations AS
SELECT
	"Id"					AS reservation_id,
	"ReservationCode"		AS reservation_code
FROM stage_sch."Reservations";

---order_coupons
DROP TABLE IF EXISTS clean_sch.order_coupons;

CREATE TABLE clean_sch.order_coupons AS
SELECT
	"OrderId" 				AS order_id,
	"CouponId"				AS coupon_id,
	"OrderItemId"			AS order_item_id
FROM stage_sch."OrderCoupons";

--coupons
DROP TABLE IF EXISTS clean_sch.coupons;
CREATE TABLE clean_sch.coupons AS
SELECT
	"Id" 					AS coupon_id,
	"CouponCode"			AS coupon_code
FROM stage_sch."Coupons";


--/* PRODUCTS_DB */
--products
DROP TABLE IF EXISTS clean_sch.products;
CREATE TABLE clean_sch.products AS
SELECT
	"Id" 					AS product_id,
	"Name"					AS product_name
FROM stage_sch."Products";

--rental_types
DROP TABLE IF EXISTS clean_sch.rental_types;
CREATE TABLE clean_sch.rental_types AS
SELECT 
	"Id" 					AS rental_types_id,
	"Name"					AS rental_name
FROM stage_sch."RentalTypes";


/* LOCATIONS */

--locations
DROP TABLE IF EXISTS clean_sch.locations;
CREATE TABLE clean_sch.locations AS
SELECT 
	"Id"					AS location_id,	
	"Name"					AS location_name,
	"TaxRate"				AS tax_rate
FROM stage_sch."Locations";

/* USERS */

--users
DROP TABLE IF EXISTS clean_sch.users;
CREATE TABLE clean_sch.users AS
SELECT
	"Id"					AS users_id,
	CONCAT("FirstName", ' ', "LastName") AS user_name
--	"CreatedBy"				AS created_by -- All the places that say "created by" is their foreign key, what do i do? its all different everywhere
FROM stage_sch."Users";


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
FROM stage_sch."PaymentTransactions"
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

--partners
DROP TABLE IF EXISTS clean_sch.partners;
CREATE TABLE clean_sch.partners AS
SELECT
	"Id" 					AS partner_id,
	"Name"					AS partner_name
FROM stage_sch."Partners";
	
--payment_refund-- in stage_sch (connected to refund and payment transaction id)
DROP TABLE IF EXISTS clean_sch.payment_refund;
CREATE TABLE clean_sch.payment_refund AS
SELECT
	"Id" 					AS payment_refund_id,
	"PaymentTransactionId" 	AS payment_transaction_id,
	"RefundedProcessingFee"	AS refunded_processing_fee
FROM stage_sch."PaymentRefund";

