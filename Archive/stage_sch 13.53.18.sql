DROP SCHEMA IF EXISTS stage_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS stage_sch;

-- orders

CREATE TABLE stage_sch.orders 				AS 		SELECT * FROM stage_orders."Orders";

CREATE TABLE stage_sch.order_items 			AS		SELECT * FROM stage_orders."OrderItems";

CREATE TABLE stage_sch.order_items_history 	AS		SELECT * FROM stage_orders."OrderItemsHistory";

CREATE TABLE stage_sch.order_history 		AS		SELECT * FROM stage_orders."OrderHistory";

CREATE TABLE stage_sch.reservations 		AS		SELECT * FROM stage_orders."Reservations";

CREATE TABLE stage_sch.order_coupons 		AS		SELECT * FROM stage_orders."OrderCoupons";

CREATE TABLE stage_sch.coupons 				AS		SELECT * FROM stage_orders."Coupons";

--  orders dynamic
CREATE TABLE stage_sch.dc_o					AS 		SELECT * FROM stage_orders.dc_o;
CREATE TABLE stage_sch.dc_options_o			AS 		SELECT * FROM stage_orders.dc_options_o;
CREATE TABLE stage_sch.dc_values_o			AS 		SELECT * FROM stage_orders.dc_values_o;

-- products
CREATE TABLE stage_sch.products 			AS		SELECT * FROM stage_products."Products";

CREATE TABLE stage_sch.rental_types 		AS		SELECT * FROM stage_products."RentalTypes";

-- products dynamic
CREATE TABLE stage_sch.dc_values_p  		AS		SELECT * FROM stage_products.dc_values_p;

CREATE TABLE stage_sch.dc_p                 AS		SELECT * FROM stage_products.dc_p;

CREATE TABLE stage_sch.dc_options_p         AS		SELECT * FROM stage_products.dc_options_p;

CREATE TABLE stage_sch.dc_product_mappings_p	AS	SELECT * FROM stage_products.dc_product_mappings_p;

CREATE TABLE stage_sch.dc_role_mappings_p   AS		SELECT * FROM stage_products.dc_role_mappings_p;


-- locations
CREATE TABLE stage_sch.locations 			AS		SELECT * FROM stage_locations."Locations";

-- locations dynamic
CREATE TABLE stage_sch.dc_values_l   		AS		SELECT * FROM stage_locations.dc_values_l;

CREATE TABLE stage_sch.dc_l                 AS		SELECT * FROM stage_locations.dc_l;

CREATE TABLE stage_sch.dc_options_l         AS		SELECT * FROM stage_locations.dc_options_l;

CREATE TABLE stage_sch.dc_location_mappings_l AS	SELECT * FROM stage_locations.dc_location_mappings_l;

CREATE TABLE stage_sch.dc_role_mappings_l    AS		SELECT * FROM stage_locations.dc_role_mappings_l;


-- payments
CREATE TABLE stage_sch.partners 			AS		SELECT * FROM stage_payments."Partners";

CREATE TABLE stage_sch.payment_transactions AS		SELECT * FROM stage_payments."PaymentTransactions";

CREATE TABLE stage_sch.payment_refund 		AS		SELECT * FROM stage_payments."PaymentRefund";


-- users
CREATE TABLE stage_sch.users 				AS  	SELECT * FROM stage_users."Users";
