DROP SCHEMA IF EXISTS clean_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS clean_sch;

-- ORDERS (orders_db)

-- orders
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

-- order_items
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
	"TotalAmount"			AS total_amount_items,
	"Total"					AS total_items, -- added new
	"CreatedOn"				AS created_on_items, -- added new
	"IsRefunded"			AS is_refunded,
	"StartDate"				AS start_date,
	"EndDate"				AS end_date,
	"PartnerId"				AS partner_id
FROM stage_sch.order_items
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

-- order_history
CREATE TABLE clean_sch.order_history AS
SELECT
	"Id" 					AS order_history_id,
	"OrderId"				AS order_id,
	"UserId"				AS user_id,
	"RefundedTotal"			AS refunded_total,
	"RefundOrderNumber"		AS refund_order_number
FROM stage_sch.order_history
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

-- order_items_history
CREATE TABLE clean_sch.order_items_history AS
SELECT
	"Id"					AS order_items_history_id,
	"OrderId"				AS order_id,
	"ProductId"				AS product_id,
	"LocationId"			AS location_id,
	"SiteId"				AS site_id,
	"CreatedOn"				AS created_on,
	"TotalAmount"			AS total_amount_items_history	
FROM stage_sch.order_items_history
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

-- orders dynamic controls
CREATE TABLE clean_sch.dynamic_controls_o AS
SELECT
    "Id"        AS dc_id,
    "Name"      AS dc_name
FROM stage_orders.dynamic_controls_o;


-- RESERVATIONS	(orders_db)

-- reservations
CREATE TABLE clean_sch.reservations AS
SELECT
	"Id"					AS reservation_id,
	"ReservationCode"		AS reservation_code
FROM stage_sch.reservations;


-- USERS (users_db)

-- users
CREATE TABLE clean_sch.users AS
SELECT
	"Id"					AS users_id,
	CONCAT("FirstName", ' ', "LastName") AS user_name
FROM stage_sch.users;


-- PRODUCTS (products_db)

-- products
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

-- products dynamic controls
CREATE TABLE clean_sch.dynamic_controls_p  AS
SELECT
    "Id"    AS dc_id_p,
    "Name"  AS dc_name_p
FROM stage_products.dynamic_controls_p;

CREATE TABLE clean_sch.dynamic_control_options_p AS
SELECT
    "Id"               AS dc_option_id_p,
    "DynamicControlId" AS dc_id_p,
    "Option"           AS dc_option_p
FROM stage_products.dynamic_control_options_p;

CREATE TABLE clean_sch.product_dynamic_control_values_p AS
SELECT
    "ProductId"             AS product_id,
    "DynamicControlOptionId" AS dc_option_id_p
FROM stage_products.product_dynamic_control_values_p;

CREATE TABLE clean_sch.dynamic_control_product_mappings_p AS
SELECT
    "ProductId"             AS product_id,
    "DynamicControlOptionId" AS dc_option_id_p
FROM stage_products.dynamic_control_product_mappings_p;

CREATE TABLE clean_sch.dynamic_control_role_mappings_p AS
SELECT
    "RoleId"            AS role_id,
    "DynamicControlId"  AS dc_id_p
FROM stage_products.dynamic_control_role_mappings_p;


-- LOCATIONS (locations_db)

--locations
CREATE TABLE clean_sch.locations AS
SELECT 
	"Id"					AS location_id,	
	"Name"					AS location_name,
	"TaxRate"				AS tax_rate
FROM stage_sch.locations;

-- locations dynamic controls
CREATE TABLE clean_sch.dynamic_controls_l  AS
SELECT
    "Id"    AS dc_id_l,
    "Name"  AS dc_name_l
FROM stage_locations.dynamic_controls_l;

CREATE TABLE clean_sch.dynamic_control_options_l AS
SELECT
    "Id"               AS dc_option_id_l,
    "DynamicControlId" AS dc_id_l,
    "Option"           AS dc_option_l
FROM stage_locations.dynamic_control_options_l;

CREATE TABLE clean_sch.location_dynamic_control_values_l AS
SELECT
    "LocationId"            AS location_id,
    "DynamicControlOptionId" AS dc_option_id_l
FROM stage_locations.location_dynamic_control_values_l;

CREATE TABLE clean_sch.dynamic_control_location_mappings_l AS
SELECT
    "LocationId"            AS location_id,
    "DynamicControlOptionId" AS dc_option_id_l
FROM stage_locations.dynamic_control_location_mappings_l;

CREATE TABLE clean_sch.dynamic_control_role_mappings_l AS
SELECT
    "RoleId"           AS role_id,
    "DynamicControlId" AS dc_id_l
FROM stage_locations.dynamic_control_role_mappings_l;


-- COUPONS (orders_db)

-- order_coupons
CREATE TABLE clean_sch.order_coupons AS
SELECT
	"OrderId" 				AS order_id,
	"CouponId"				AS coupon_id,
	"OrderItemId"			AS order_items_id
FROM stage_sch.order_coupons;

-- coupons
CREATE TABLE clean_sch.coupons AS
SELECT
	"Id" 					AS coupon_id,
	"CouponCode"			AS coupon_code
FROM stage_sch.coupons;


-- PAYMENTS (payments_db)

-- payment_transactions
CREATE TABLE clean_sch.payment_transactions AS
SELECT
	"Id"					AS payment_transaction_id,
	"OrderId"				AS order_id,
	"ProcessingFee"			AS processing_fee,
	"Source"				AS source,
	"Amount"				AS amount,
	"PaymentType"			AS payment_type,
	"PaymentProviderName"	AS payment_provider_name
FROM stage_sch.payment_transactions
WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';

-- partners
CREATE TABLE clean_sch.partners AS
SELECT
	"Id" 					AS partner_id,
	"Name"					AS partner_name
FROM stage_sch.partners;
	
-- payment_refund
CREATE TABLE clean_sch.payment_refund AS
SELECT
	"Id" 					AS payment_refund_id,
	"PaymentTransactionId" 	AS payment_transaction_id,
	"RefundedProcessingFee"	AS refunded_processing_fee
FROM stage_sch.payment_refund;