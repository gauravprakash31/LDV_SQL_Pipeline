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

	"OrderDynamicControlValues"
  )
FROM SERVER ordersapi_srv INTO stage_orders;

ALTER TABLE stage_orders."OrderDynamicControlValues" 	RENAME TO dynamic_controls_o;

