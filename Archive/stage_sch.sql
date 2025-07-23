/*DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
DROP SCHEMA IF EXISTS stage_sch CASCADE;
DROP SERVER IF EXISTS ordersapi_srv CASCADE;
DROP SERVER IF EXISTS productsapi_srv CASCADE;
DROP SERVER IF EXISTS locationsapi_srv CASCADE;
DROP SERVER IF EXISTS paymentsapi_srv CASCADE;*/

CREATE SCHEMA stage_sch;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

--OrdersAPI
CREATE SERVER ordersapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'orders_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER ordersapi_srv
OPTIONS(user 'postgres', password 'Sharvari04');

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Orders",
		"OrderItems",
		"OrderItemsHistory",
		"OrderHistory",
		"Reservations",
		"OrderCoupons",
		"Coupons"
	)
	FROM SERVER ordersapi_srv INTO stage_sch;

CREATE TABLE stage_sch.orders AS
SELECT * FROM stage_sch."Orders";

CREATE TABLE stage_sch.order_items AS
SELECT * FROM stage_sch."OrderItems";

CREATE TABLE stage_sch.order_items_hist AS
SELECT * FROM stage_sch."OrderItemsHistory";

CREATE TABLE stage_sch.order_hist AS
SELECT * FROM stage_sch."OrderHistory";

CREATE TABLE stage_sch.reservations AS
SELECT * FROM stage_sch."Reservations";

CREATE TABLE stage_sch.order_coupons AS
SELECT * FROM stage_sch."OrderCoupons";

CREATE TABLE stage_sch.coupons AS
SELECT * FROM stage_sch."Coupons";

--ProductsAPI
CREATE SERVER productsapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'products_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER productsapi_srv
OPTIONS(user 'postgres', password 'Sharvari04');

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Products",
		"RentalTypes"
	)
	FROM SERVER productsapi_srv INTO stage_sch;

CREATE TABLE stage_sch.products AS
SELECT * FROM stage_sch."Products";

CREATE TABLE stage_sch.rental_types AS
SELECT * FROM stage_sch."RentalTypes";

--LocationsAPI
CREATE SERVER locationsapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'locations_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER locationsapi_srv
OPTIONS(user 'postgres', password 'Sharvari04');

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Locations"
	)
	FROM SERVER locationsapi_srv INTO stage_sch;

CREATE TABLE stage_sch.locations AS
SELECT * FROM stage_sch."Locations";

--PaymentsAPI
CREATE SERVER paymentsapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'payments_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER paymentsapi_srv
OPTIONS(user 'postgres', password 'Sharvari04');

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Partners",
		"PaymentTransactions",
		"PaymentRefund",
		"Partners"
	)
	FROM SERVER paymentsapi_srv INTO stage_sch;

CREATE TABLE stage_sch.partners AS
SELECT * FROM stage_sch."Partners";

CREATE TABLE stage_sch.payment_transactions AS
SELECT * FROM stage_sch."PaymentTransactions";

CREATE TABLE stage_sch.payment_refund AS
SELECT * FROM stage_sch."PaymentRefund";

CREATE TABLE stage_sch.payment_refund AS
SELECT * FROM stage_sch."Partners";

--UsersAPI
CREATE SERVER usersapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'users_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER usersapi_srv
OPTIONS(user 'postgres', password 'Sharvari04');

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Users"
	)
	FROM SERVER usersapi_srv INTO stage_sch;

CREATE TABLE stage_sch.users AS
SELECT * FROM stage_sch."Users";
