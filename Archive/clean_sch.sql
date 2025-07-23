DROP SCHEMA IF EXISTS clean_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS clean_sch;

/*ORDERS*/

-- orders --
CREATE TABLE clean_sch.orders AS
SELECT
  "Id"                   AS order_id,
  "ReservationId"        AS reservation_id,
  "PaymentTransactionId" AS payment_transaction_id,
  "CreatedBy"            AS created_by,
  "BookingFee"           AS booking_fee,
  "DeliveryFee"          AS delivery_fee,
  "Total"                AS total,
  "OrderNumber"          AS order_number
FROM stage_sch.orders;

-- ----- order_items -----
CREATE TABLE clean_sch.order_items AS
SELECT
  "Id"           	AS order_items_id,
  "OrderId"      	AS order_id,
  "ProductId"    	AS product_id,
  "LocationId"   	AS location_id,
  "SiteId"       	AS site_id,
  "RentalTypeId" 	AS rental_type_id,
  "PartnerId"		AS partner_id,	
  "CouponDiscount" 	AS coupon_discount,
  "Tip"            	AS tip,
  "Discount"       	AS discount,
  "SalesTax"       	AS sales_tax,
  "Total"			AS total_order_items, -- whats the purpose of this 
  "TotalAmount"    	AS total_amount_items,
  "CreatedOn"      	AS created_on_items,
  "IsRefunded"     	AS is_refunded,
  "StartDate"      	AS start_date,
  "EndDate"        	AS end_date
FROM stage_sch.order_items;

-- ----- order_history -----
CREATE TABLE clean_sch.order_history AS
SELECT
  "Id"              AS order_history_id,
  "OrderId"         AS order_id,
  "UserId"          AS user_id,
  "RefundedTotal"   AS refunded_total,
  "RefundOrderNumber" AS refund_order_number
FROM stage_sch.order_hist;

-- ----- order_items_history -----
CREATE TABLE clean_sch.order_items_history AS
SELECT
  "Id"         AS order_items_history_id,
  "OrderId"    AS order_id,
  "ProductId"  AS product_id,
  "LocationId" AS location_id,
  "SiteId"     AS site_id,
  "CreatedOn"  AS created_on
  -- LineItemId and PaymentTransactionId are foreign keys that come in during joins
FROM stage_sch.order_items_hist;

-- ----- reservations -----
CREATE TABLE clean_sch.reservations AS
SELECT
  "Id"             AS reservation_id,
  "ReservationCode" AS reservation_code
FROM stage_sch.reservations;

-- ----- users -----
CREATE TABLE clean_sch.users AS
SELECT
  "Id" AS users_id,
  CONCAT("FirstName", ' ', "LastName") AS user_name
FROM stage_sch.users;

-- ----- products -----
CREATE TABLE clean_sch.products AS
SELECT
  "Id"   AS product_id,
  "Name" AS product_name
FROM stage_sch.products;

-- ----- rental_types -----
CREATE TABLE clean_sch.rental_types AS
SELECT
  "Id"   AS rental_types_id,
  "Name" AS rental_name
FROM stage_sch.rental_types;

-- ----- locations -----
CREATE TABLE clean_sch.locations AS
SELECT
  "Id"      AS location_id,
  "Name"    AS location_name,
  "TaxRate" AS tax_rate
  -- SiteId through joins
FROM stage_sch.locations;

-- ----- payment_transactions -----
CREATE TABLE clean_sch.payment_transactions AS
SELECT
  "Id"                AS payment_transaction_id,
  "OrderId"           AS order_id,
  "ProcessingFee"     AS processing_fee,
  "Source"            AS source,
  "Amount"            AS amount,
  "PaymentType"       AS payment_type,
  "PaymentProviderName" AS payment_provider_name
FROM stage_sch.payment_transactions;

-- ----- payment_refund -----
CREATE TABLE clean_sch.payment_refund AS
SELECT
  "Id"                   AS payment_refund_id
--"PaymentTransactionId" AS payment_transaction_id, --ERROR:  column "PaymentTransactionId" does not exist
--"RefundedProcessingFee" AS refunded_processing_fee --ERROR:  column "RefundedProcessingFee" does not exist
FROM stage_sch.payment_refund;

-- ----- partners -----
CREATE TABLE clean_sch.partners AS
SELECT
  "Id"   AS partner_id,
  "Name" AS partner_name
FROM stage_sch.partners;

-- ----- coupons (lookups) -----
CREATE TABLE clean_sch.coupons AS
SELECT
  "Id"         AS coupon_id,
  "CouponCode" AS coupon_code
FROM stage_sch.coupons;

-- ----- order_coupons (bridge) -----
CREATE TABLE clean_sch.order_coupons AS
SELECT
  "OrderId"     AS order_id,
  "OrderItemId" AS order_items_id,
  "CouponId"    AS coupon_id
FROM stage_sch.order_coupons;
