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

CREATE SCHEMA IF NOT EXISTS stage_sch;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

--OrdersAPI

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

CREATE TABLE stage_sch.orders AS
SELECT * FROM orders_sch."Orders";

CREATE TABLE stage_sch.order_items AS
SELECT * FROM orders_sch."OrderItems";

CREATE TABLE stage_sch.order_items_history AS
SELECT * FROM orders_sch."OrderItemsHistory";

CREATE TABLE stage_sch.order_history AS
SELECT * FROM orders_sch."OrderHistory";

CREATE TABLE stage_sch.reservations AS
SELECT * FROM orders_sch."Reservations";

CREATE TABLE stage_sch.order_coupons AS
SELECT * FROM orders_sch."OrderCoupons";

CREATE TABLE stage_sch.coupons AS
SELECT * FROM orders_sch."Coupons";

CREATE TABLE stage_sch.dc_o AS
SELECT * FROM orders_sch."DynamicControls";

CREATE TABLE stage_sch.dc_options_o AS
SELECT * FROM orders_sch."DynamicControlOptions";

CREATE TABLE stage_sch.dc_values_o AS
SELECT * FROM orders_sch."OrderDynamicControlValues";

CREATE TABLE stage_sch.dc_items_o AS
SELECT * FROM orders_sch."OrderItemDynamicControls";


--ProductsAPI
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

CREATE TABLE stage_sch.products AS
SELECT * FROM products_sch."Products";

CREATE TABLE stage_sch.rental_types AS
SELECT * FROM products_sch."RentalTypes";

CREATE TABLE stage_sch.dc_p AS
SELECT * FROM products_sch."DynamicControls";

CREATE TABLE stage_sch.dc_options_p AS
SELECT * FROM products_sch."DynamicControlOptions";

CREATE TABLE stage_sch.dc_values_p AS
SELECT * FROM products_sch."ProductDynamicControlValues";

CREATE TABLE stage_sch.dc_product_mappings_p AS
SELECT * FROM products_sch."DynamicControlProductMappings";

CREATE TABLE stage_sch.dc_role_mappings_p AS
SELECT * FROM products_sch."DynamicControlRoleMappings";


--LocationsAPI
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

CREATE TABLE stage_sch.locations AS
SELECT * FROM locations_sch."Locations";

CREATE TABLE stage_sch.dc_l AS
SELECT * FROM locations_sch."DynamicControls";

CREATE TABLE stage_sch.dc_options_l AS
SELECT * FROM locations_sch."DynamicControlOptions";

CREATE TABLE stage_sch.dc_values_l AS
SELECT * FROM locations_sch."LocationDynamicControlValues";

CREATE TABLE stage_sch.dc_location_mappings_l AS
SELECT * FROM locations_sch."DynamicControlLocationMappings";

CREATE TABLE stage_sch.dc_role_mappings_l AS
SELECT * FROM locations_sch."DynamicControlRoleMappings";

	
--PaymentsAPI

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

CREATE TABLE stage_sch.partners AS
SELECT * FROM payments_sch."Partners";

CREATE TABLE stage_sch.payment_transactions AS
SELECT * FROM payments_sch."PaymentTransactions";

CREATE TABLE stage_sch.payment_refund AS
SELECT * FROM payments_sch."PaymentRefund";

--UsersAPI

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

CREATE TABLE stage_sch.users AS
SELECT * FROM users_sch."Users";

