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
CREATE TABLE stage_sch.dynamic_controls_o	AS		SELECT * FROM stage_orders.dynamic_controls_o;


-- products
CREATE TABLE stage_sch.products 			AS		SELECT * FROM stage_products."Products";

CREATE TABLE stage_sch.rental_types 		AS		SELECT * FROM stage_products."RentalTypes";

-- products dynamic
CREATE TABLE stage_sch.product_dynamic_control_values_p   AS
SELECT * FROM stage_products.product_dynamic_control_values_p;

CREATE TABLE stage_sch.dynamic_controls_p                 AS
SELECT * FROM stage_products.dynamic_controls_p;

CREATE TABLE stage_sch.dynamic_control_options_p          AS
SELECT * FROM stage_products.dynamic_control_options_p;

CREATE TABLE stage_sch.dynamic_control_product_mappings_p AS
SELECT * FROM stage_products.dynamic_control_product_mappings_p;

CREATE TABLE stage_sch.dynamic_control_role_mappings_p    AS
SELECT * FROM stage_products.dynamic_control_role_mappings_p;


-- locations
CREATE TABLE stage_sch.locations 			AS		SELECT * FROM stage_locations."Locations";

-- locations dynamic
CREATE TABLE stage_sch.location_dynamic_control_values_l   AS
SELECT * FROM stage_locations.location_dynamic_control_values_l;

CREATE TABLE stage_sch.dynamic_controls_l                  AS
SELECT * FROM stage_locations.dynamic_controls_l;

CREATE TABLE stage_sch.dynamic_control_options_l           AS
SELECT * FROM stage_locations.dynamic_control_options_l;

CREATE TABLE stage_sch.dynamic_control_location_mappings_l AS
SELECT * FROM stage_locations.dynamic_control_location_mappings_l;

CREATE TABLE stage_sch.dynamic_control_role_mappings_l     AS
SELECT * FROM stage_locations.dynamic_control_role_mappings_l;


-- payments
CREATE TABLE stage_sch.partners 			AS		SELECT * FROM stage_payments."Partners";

CREATE TABLE stage_sch.payment_transactions AS		SELECT * FROM stage_payments."PaymentTransactions";

CREATE TABLE stage_sch.payment_refund 		AS		SELECT * FROM stage_payments."PaymentRefund";


-- users
CREATE TABLE stage_sch.users 				AS  	SELECT * FROM stage_users."Users";
