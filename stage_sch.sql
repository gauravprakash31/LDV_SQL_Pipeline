--DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
--DROP SCHEMA IF EXISTS stage_sch CASCADE;
--DROP SERVER IF EXISTS ordersapi_srv CASCADE;
--DROP SERVER IF EXISTS productsapi_srv CASCADE;
--DROP SERVER IF EXISTS locationsapi_srv CASCADE;
--DROP SERVER IF EXISTS paymentsapi_srv CASCADE;
CREATE SCHEMA IF NOT EXISTS stage_sch;
CREATE SCHEMA IF NOT EXISTS order_sch;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

--OrdersAPI
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
		"DynamicControlRoleMappings"
	)
	FROM SERVER ordersapi_srv INTO order_sch;

CREATE TABLE stage_sch.orders AS
SELECT * FROM order_sch."Orders";

CREATE TABLE stage_sch.order_items AS
SELECT * FROM order_sch."OrderItems";

CREATE TABLE stage_sch.order_items_history AS
SELECT * FROM order_sch."OrderItemsHistory";

CREATE TABLE stage_sch.order_history AS
SELECT * FROM order_sch."OrderHistory";

CREATE TABLE stage_sch.reservations AS
SELECT * FROM order_sch."Reservations";

CREATE TABLE stage_sch.order_coupons AS
SELECT * FROM order_sch."OrderCoupons";

CREATE TABLE stage_sch.coupons AS
SELECT * FROM order_sch."Coupons";

CREATE TABLE stage_sch.dc_o AS
SELECT * FROM order_sch."DynamicControls";

CREATE TABLE stage_sch.dc_options_o AS
SELECT * FROM order_sch."DynamicControlOptions";

CREATE TABLE stage_sch.dc_values_o AS
SELECT * FROM order_sch."OrderDynamicControlValues";

CREATE TABLE stage_sch.dc_role_mappings_o AS
SELECT * FROM order_sch."DynamicControlRoleMappings";


--ProductsAPI
CREATE SCHEMA IF NOT EXISTS product_sch;

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
	FROM SERVER productsapi_srv INTO product_sch;

CREATE TABLE stage_sch.products AS
SELECT * FROM product_sch."Products";

CREATE TABLE stage_sch.rental_types AS
SELECT * FROM product_sch."RentalTypes";

CREATE TABLE stage_sch.dc_p AS
SELECT * FROM product_sch."DynamicControls";

CREATE TABLE stage_sch.dc_options_p AS
SELECT * FROM product_sch."DynamicControlOptions";

CREATE TABLE stage_sch.dc_values_p AS
SELECT * FROM product_sch."ProductDynamicControlValues";

CREATE TABLE stage_sch.dc_product_mappings_p AS
SELECT * FROM product_sch."DynamicControlProductMappings";

CREATE TABLE stage_sch.dc_role_mappings_p AS
SELECT * FROM product_sch."DynamicControlRoleMappings";


--LocationsAPI
CREATE SCHEMA IF NOT EXISTS location_sch;

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
	FROM SERVER locationsapi_srv INTO location_sch;

CREATE TABLE stage_sch.locations AS
SELECT * FROM location_sch."Locations";

CREATE TABLE stage_sch.dc_l AS
SELECT * FROM location_sch."DynamicControls";

CREATE TABLE stage_sch.dc_options_l AS
SELECT * FROM location_sch."DynamicControlOptions";

CREATE TABLE stage_sch.dc_values_l AS
SELECT * FROM location_sch."LocationDynamicControlValues";

CREATE TABLE stage_sch.dc_location_mappings_l AS
SELECT * FROM location_sch."DynamicControlLocationMappings";

CREATE TABLE stage_sch.dc_role_mappings_l AS
SELECT * FROM location_sch."DynamicControlRoleMappings";

	
--PaymentsAPI
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
	FROM SERVER paymentsapi_srv INTO stage_sch;

CREATE TABLE stage_sch.partners AS
SELECT * FROM stage_sch."Partners";

CREATE TABLE stage_sch.payment_transactions AS
SELECT * FROM stage_sch."PaymentTransactions";

CREATE TABLE stage_sch.payment_refund AS
SELECT * FROM stage_sch."PaymentRefund";

--UsersAPI

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
	FROM SERVER usersapi_srv INTO stage_sch;

CREATE TABLE stage_sch.users AS
SELECT * FROM stage_sch."Users";
