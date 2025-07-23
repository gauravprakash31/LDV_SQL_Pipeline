DROP SCHEMA IF EXISTS stage_orders CASCADE;
CREATE SCHEMA IF NOT EXISTS stage_orders;

IMPORT FOREIGN SCHEMA public
  LIMIT TO (
    "Orders",
    "OrderItems",
    "OrderItemsHistory",
    "OrderHistory",
    "Reservations",
    "OrderCoupons",
    "Coupons",

	"DynamicControlOptions",
	"OrderDynamicControlValues",
	"DynamicControlRoleMappings",
	"DynamicControls"
  )
FROM SERVER ordersapi_srv INTO stage_orders;

ALTER TABLE stage_orders."DynamicControlOptions" 		RENAME TO dc_options_o;
ALTER TABLE stage_orders."DynamicControlRoleMappings" 	RENAME TO dc_role_mappings_o;
ALTER TABLE stage_orders."DynamicControls" 				RENAME TO dc_o;
ALTER TABLE stage_orders."OrderDynamicControlValues" 	RENAME TO dc_values_o;

