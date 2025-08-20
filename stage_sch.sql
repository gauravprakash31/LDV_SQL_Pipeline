--DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
--DROP SERVER IF EXISTS ordersapi_srv CASCADE;
--DROP SERVER IF EXISTS productsapi_srv CASCADE;
--DROP SERVER IF EXISTS locationsapi_srv CASCADE;
--DROP SERVER IF EXISTS paymentsapi_srv CASCADE;

DROP SCHEMA IF EXISTS stage_sch CASCADE;
DROP SCHEMA IF EXISTS orders_sch CASCADE;
DROP SCHEMA IF EXISTS products_sch CASCADE;
DROP SCHEMA IF EXISTS locations_sch CASCADE;
DROP SCHEMA IF EXISTS payments_sch CASCADE;
DROP SCHEMA IF EXISTS users_sch CASCADE;


CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- ============================================================================
-- ORDERS FDW
-- ============================================================================

DROP SCHEMA IF EXISTS orders_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS orders_sch;

CREATE SERVER IF NOT EXISTS ordersapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'orders_db');

DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER ordersapi_srv;
CREATE USER MAPPING FOR CURRENT_USER
SERVER ordersapi_srv
OPTIONS(user 'postgres_fdw', password 'postgres_fdw1');

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Orders",
		"OrderItems",
		"OrderItemsHistory",
		"OrderHistory",
		"Reservations",
		"OrderCoupons",
		"Coupons",
		"DynamicControls",
		"DynamicControlOptions",
		"OrderDynamicControlValues",
		"OrderItemDynamicControls"
	)
	FROM SERVER ordersapi_srv INTO orders_sch;


-- ============================================================================
-- PRODUCTS FDW
-- ============================================================================
DROP SCHEMA IF EXISTS products_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS products_sch;

DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER productsapi_srv;

CREATE SERVER IF NOT EXISTS productsapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'products_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER productsapi_srv
OPTIONS(user 'postgres_fdw', password 'postgres_fdw1');

IMPORT FOREIGN SCHEMA public

	LIMIT TO (
		"Products",
		"RentalTypes",
		"DynamicControls",
		"DynamicControlOptions",
		"ProductDynamicControlValues",
		"DynamicControlProductMappings",
		"DynamicControlRoleMappings"
	)
	FROM SERVER productsapi_srv INTO products_sch;


-- ============================================================================
-- LOCATIONS FDW 
-- ============================================================================

DROP SCHEMA IF EXISTS locations_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS locations_sch;

DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER locationsapi_srv;

CREATE SERVER IF NOT EXISTS locationsapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'locations_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER locationsapi_srv
OPTIONS(user 'postgres_fdw', password 'postgres_fdw1');

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Locations",
		"DynamicControls",
		"DynamicControlOptions",
		"LocationDynamicControlValues",
		"DynamicControlLocationMappings",
		"DynamicControlRoleMappings"
	)
	FROM SERVER locationsapi_srv INTO locations_sch;


-- ============================================================================
-- PAYMENTS FDW 
-- ============================================================================
DROP SCHEMA IF EXISTS payments_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS payments_sch;

DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER paymentsapi_srv;

CREATE SERVER IF NOT EXISTS paymentsapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'payments_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER paymentsapi_srv
OPTIONS(user 'postgres_fdw', password 'postgres_fdw1');

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Partners",
		"PaymentTransactions",
		"PaymentRefund"
	)
	FROM SERVER paymentsapi_srv INTO payments_sch;

-- ============================================================================
-- USERS FDW 
-- ============================================================================
DROP SCHEMA IF EXISTS users_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS users_sch;

DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER usersapi_srv;

CREATE SERVER IF NOT EXISTS usersapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'users_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER usersapi_srv
OPTIONS(user 'postgres_fdw', password 'postgres_fdw1');

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Users"
	)
	FROM SERVER usersapi_srv INTO users_sch;


-- ============================================================================
-- COPY EVERYTHING INTO public 
-- ============================================================================

-- ORDERS

DROP TABLE IF EXISTS public."Orders" CASCADE;
CREATE TABLE public."Orders" AS
SELECT
  "Id",
  "ReservationId",
  "PaymentTransactionId",
  "CreatedBy",
  "BookingFee",
  "Total",
  "OrderNumber"
FROM orders_sch."Orders";

-- OrderItems
DROP TABLE IF EXISTS public."OrderItems" CASCADE;
CREATE TABLE public."OrderItems" AS
SELECT
  "Id",
  "OrderId",
  "ProductId",
  "LocationId",
  "SiteId",
  "RentalTypeId",
  "CouponDiscount",
  "BookingFee",
  "ParentOrderItemId",
  "IsALaCarte",
  "DeliveryFee",
  "Tip",
  "Discount",
  "SalesTax",
  "Total",
  "TotalAmount",
  "CreatedOn",
  "ModifiedOn",
  "IsRefunded",
  "StartDate",
  "EndDate",
  "PartnerId"
FROM orders_sch."OrderItems";

-- OrderItemsHistory
DROP TABLE IF EXISTS public."OrderItemsHistory" CASCADE;
CREATE TABLE public."OrderItemsHistory" AS

SELECT

  "Id",
  "OrderItemId",
  "OrderId",
  "RefundedQuantity",
  "RefundedTotalAmount",
  "TotalAmount",
  "CreatedOn",
  "RefundedCouponDiscount",
  "RefundedBookingFee",
  "RefundedTip",
  "RefundedDiscount",
  "RefundedTotal",
  "RefundedSalesTax",
  "SalesTax",
  "Discount",
  "BookingFee",
  "Total",
  "DeliveryFee",
  "CouponDiscount",
  "Tip"
  
FROM orders_sch."OrderItemsHistory";
	

-- OrderHistory
DROP TABLE IF EXISTS public."OrderHistory" CASCADE;
CREATE TABLE public."OrderHistory" AS
SELECT
  "Id",
  "OrderId",
  "UserId",
  "RefundedTotal",
  "RefundOrderNumber"
FROM orders_sch."OrderHistory";

-- Reservations
DROP TABLE IF EXISTS public."Reservations" CASCADE;
CREATE TABLE public."Reservations" AS
SELECT
  "Id",
  "ReservationCode"
FROM orders_sch."Reservations";

-- OrderCoupons
DROP TABLE IF EXISTS public."OrderCoupons" CASCADE;
CREATE TABLE public."OrderCoupons" AS
SELECT
  "OrderId",
  "CouponId",
  "OrderItemId"
FROM orders_sch."OrderCoupons";

-- Coupons
DROP TABLE IF EXISTS public."Coupons" CASCADE;
CREATE TABLE public."Coupons" AS
SELECT
  "Id",
  "CouponCode"
FROM orders_sch."Coupons";

-- Order-level DynamicControls
DROP TABLE IF EXISTS public."OrderDynamicControls" CASCADE;
CREATE TABLE public."OrderDynamicControls" AS
SELECT
  "Id",
  "DisplayName",
  "ShowInExport"
FROM orders_sch."DynamicControls";

DROP TABLE IF EXISTS public."OrderDynamicControlOptions" CASCADE;
CREATE TABLE public."OrderDynamicControlOptions" AS
SELECT
  "Id",
  "DynamicControlId",
  "Option"
FROM orders_sch."DynamicControlOptions";

DROP TABLE IF EXISTS public."OrderDynamicControlValues" CASCADE;
CREATE TABLE public."OrderDynamicControlValues" AS
SELECT
  "OrderId",
  "DynamicControlOptionId"
FROM orders_sch."OrderDynamicControlValues";

DROP TABLE IF EXISTS public."OrderItemDynamicControls" CASCADE;
CREATE TABLE public."OrderItemDynamicControls" AS
SELECT
  "Id",
  "OrderItemId",
  "DynamicControlId",
  "DynamicControlOptionId",
  "DynamicControlType"
FROM orders_sch."OrderItemDynamicControls";


-- PRODUCTS

-- Products & RentalTypes
DROP TABLE IF EXISTS public."Products" CASCADE;
CREATE TABLE public."Products" AS
SELECT
  "Id",
  "Name"
FROM products_sch."Products";

DROP TABLE IF EXISTS public."RentalTypes" CASCADE;
CREATE TABLE public."RentalTypes" AS
SELECT
  "Id",
  "Name"
FROM products_sch."RentalTypes";

-- Product-level DynamicControls
DROP TABLE IF EXISTS public."ProductDynamicControls" CASCADE;
CREATE TABLE public."ProductDynamicControls" AS
SELECT
  "Id",
  "DisplayName",
  "ShowInExport"
FROM products_sch."DynamicControls";

DROP TABLE IF EXISTS public."ProductDynamicControlOptions" CASCADE;
CREATE TABLE public."ProductDynamicControlOptions" AS
SELECT
  "Id",
  "DynamicControlId",
  "Option"
FROM products_sch."DynamicControlOptions";

DROP TABLE IF EXISTS public."ProductDynamicControlValues" CASCADE;
CREATE TABLE public."ProductDynamicControlValues" AS
SELECT
  "ProductId",
  "DynamicControlOptionId"
FROM products_sch."ProductDynamicControlValues";


-- LOCATIONS

-- Locations & Location-level DynamicControls
DROP TABLE IF EXISTS public."Locations" CASCADE;
CREATE TABLE public."Locations" AS
SELECT
  "Id",
  "Name",
  "TaxRate"
FROM locations_sch."Locations";

DROP TABLE IF EXISTS public."LocationDynamicControls" CASCADE;
CREATE TABLE public."LocationDynamicControls" AS
SELECT
  "Id",
  "DisplayName",
  "ShowInExport"
FROM locations_sch."DynamicControls";

DROP TABLE IF EXISTS public."LocationDynamicControlOptions" CASCADE;
CREATE TABLE public."LocationDynamicControlOptions" AS
SELECT
  "Id",
  "DynamicControlId",
  "Option"
FROM locations_sch."DynamicControlOptions";

DROP TABLE IF EXISTS public."LocationDynamicControlValues" CASCADE;
CREATE TABLE public."LocationDynamicControlValues" AS
SELECT
  "LocationId",
  "DynamicControlOptionId"
FROM locations_sch."LocationDynamicControlValues";

-- USERS
-- Users
DROP TABLE IF EXISTS public."Users" CASCADE;
CREATE TABLE public."Users" AS
SELECT
  "Id",
  "FirstName",
  "LastName"
FROM users_sch."Users";


-- PAYMENTS
-- Partners, PaymentTransactions, PaymentRefund
DROP TABLE IF EXISTS public."Partners" CASCADE;
CREATE TABLE public."Partners" AS
SELECT
  "Id",
  "Name"
FROM payments_sch."Partners";

DROP TABLE IF EXISTS public."PaymentTransactions" CASCADE;
CREATE TABLE public."PaymentTransactions" AS
SELECT
  "Id",
  "OrderId",
  "ProcessingFee",
  "Source",
  "Amount",
  "PaymentType",
  "Status",
  "CreatedOn",
  "PaymentProviderName"
FROM payments_sch."PaymentTransactions";

DROP TABLE IF EXISTS public."PaymentRefund" CASCADE;
CREATE TABLE public."PaymentRefund" AS
SELECT
  "Id",
  "Amount",
  "PaymentTransactionId",
  "RefundedProcessingFee"
FROM payments_sch."PaymentRefund";
