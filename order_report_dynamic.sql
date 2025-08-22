--===============================================================
-- Order_report_sch.sql
-- Build static order_report_final with NULLs → blanks
--==============================================================

CREATE EXTENSION IF NOT EXISTS tablefunc;

DROP SCHEMA IF EXISTS order_report_sch CASCADE;
CREATE SCHEMA order_report_sch;

---------------------------------------------------------------------------------------------------
-- STEP 1.1: orders_with_items (include refunded‐item history)
---------------------------------------------------------------------------------------------------
---Processing Order_item_history table

DROP TABLE IF EXISTS order_report_sch.orders_item_history_agg;

CREATE TABLE order_report_sch.orders_item_history_agg AS
WITH earliest_amounts AS (
  SELECT
    "OrderId"								   AS order_id,
    "OrderItemId"                        	   AS order_item_id,
    "TotalAmount"                              AS earliest_total_amount,
    COALESCE("RefundedTotalAmount", 0.00)      AS refunded_total_item,
    "CreatedOn"                                AS transaction_date_oih,
    "RefundedTotal"                            AS refunded_total,
    "RefundedCouponDiscount"                   AS refunded_coupon,
    "RefundedTip"                              AS refunded_tip,
    "RefundedDiscount"                         AS refunded_discount,
    "RefundedBookingFee"                       AS refunded_booking_fee,
    "RefundedSalesTax"                         AS refunded_sales_tax,
    "Discount"                                 AS discount_oih,
	"Total"									   AS total_oih,
    "SalesTax"                                 AS salestax_oih,
    "BookingFee"                               AS bookingfee_oih,
    "DeliveryFee"                              AS deliveryfee_oih,
    "Tip"                                      AS tip_oih,
    "CouponDiscount"                           AS coupon_discount_oih,
	"TotalAmount"							   AS total_amount_oih,
    
    ROW_NUMBER() OVER (
      PARTITION BY "OrderItemId"
      ORDER BY "CreatedOn" ASC
    ) AS rn
  FROM public."OrderItemsHistory"
  WHERE "RefundedTotalAmount" > 0
)
SELECT *
FROM earliest_amounts ea
WHERE ea.rn = 1;


--CHECK

SELECT * FROM order_report_sch.orders_item_history_agg WHERE order_item_id = 'a949b60f-42e0-44e6-9c6f-b1420ca13203' ORDER BY order_item_id;

DROP TABLE IF EXISTS order_report_sch.orders_with_items;
CREATE TABLE order_report_sch.orders_with_items AS
SELECT
  o."Id"                    AS order_id,
  oi."Id"          			AS order_item_id,
  o."ReservationId"         AS reservation_id,
  o."PaymentTransactionId"  AS payment_transaction_id,
  o."CreatedBy"             AS created_by,
  o."BookingFee"            AS order_booking_fee,
  oi."DeliveryFee"          AS delivery_fee,
  o."Total"                 AS total,
  o."OrderNumber"           AS order_number,
  r."ReservationCode"       AS reservation_code,
  oi."ProductId"            AS product_id,
  oi."LocationId"           AS location_id,
  oi."ModifiedOn"           AS modified_on_items,
  oi."SiteId"               AS site_id,
  oi."RentalTypeId"         AS rental_type_id,
  oi."CouponDiscount"       AS coupon_discount,
  oi."Tip"                  AS tip,
  oi."Discount"             AS discount,
  oi."SalesTax"             AS sales_tax,
  oi."Total"                AS total_items,
  oi."CreatedOn"            AS created_on_items,
  CASE
    WHEN COALESCE(ih_agg.refunded_total_item,0.00) >0 THEN TRUE
    ELSE FALSE
  END                       AS is_refunded,
  oi."StartDate"            AS start_date,
  oi."EndDate"              AS end_date,
  oi."PartnerId"            AS partner_id,
  oi."BookingFee"           AS line_item_booking_fee,
  oi."ParentOrderItemId",
  oi."IsALaCarte",
  oi."TotalAmount"          AS total_amount_items,
  COALESCE(ih_agg.refunded_total_item,0.00)   AS refunded_total_item,
  COALESCE(ih_agg.earliest_total_amount,0.00)   AS earliest_total_amount,

    CASE
    WHEN COALESCE(ih_agg.refunded_total_item,0.00) >0 THEN ih_agg.earliest_total_amount
    ELSE oi."TotalAmount"
  END  AS actual_amount_items
  
FROM public."Orders"       o
LEFT JOIN public."Reservations"        r  ON r."Id"              = o."ReservationId"
LEFT JOIN public."OrderItems"         oi  ON oi."OrderId"         = o."Id" 
LEFT JOIN order_report_sch.orders_item_history_agg AS ih_agg ON ih_agg.order_item_id = oi."Id"
WHERE NOT (oi."ParentOrderItemId" IS NULL AND oi."IsALaCarte" = true);



-- CHECKS
SELECT * FROM order_report_sch.orders_with_items WHERE order_number = 100000005009 ORDER BY order_item_id;
SELECT * FROM public."OrderItems" WHERE "OrderId" = '6456eadf-9715-4408-8e1e-4d8a548c22e8';
SELECT count(DISTINCT order_id) FROM order_report_sch.orders_with_items;
SELECT * FROM order_report_sch.orders_with_items WHERE order_number = 100000005009;

SELECT * FROM public."OrderItems"   WHERE  "Id"  = 'b18f25b5-8985-4ec2-b4fb-17275107b82b';

---------------------------------------------------------------------------------------------------
-- STEP 1.2: orders_with_p_l_u (enrich with product, location, site, user, partner, tax%)
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.orders_with_p_l_u;
CREATE TABLE order_report_sch.orders_with_p_l_u AS
SELECT
  base.*,
  p."Name"               AS product_name,
  l."Name"               AS location_name,
  site."Name"            AS site_name,
  CONCAT(u."FirstName",' ',u."LastName") AS user_name,
  pa."Name"              AS partner_name,
  ROUND(COALESCE(site."TaxRate",l."TaxRate")::numeric,2) AS tax_percentage
FROM order_report_sch.orders_with_items AS base
LEFT JOIN public."Products"   p   ON p."Id"           = base.product_id
LEFT JOIN public."Locations"  l   ON l."Id"           = base.location_id
LEFT JOIN public."Locations"  site ON site."Id"       = base.site_id
LEFT JOIN public."Users"      u   ON u."Id"           = base.created_by
LEFT JOIN public."Partners"   pa  ON pa."Id"          = base.partner_id;

-- CHECKS
SELECT * FROM order_report_sch.orders_with_p_l_u 
 WHERE order_number = 100000005184 ORDER BY order_item_id;
SELECT count(DISTINCT order_id) FROM order_report_sch.orders_with_p_l_u;


---------------------------------------------------------------------------------------------------
-- STEP 1.3: orders_with_payments (attach txn + refund sums)
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.orders_with_payments;

CREATE TABLE order_report_sch.orders_with_payments AS
SELECT
  plu.*,
  pt."Amount"                        AS original_amount,
  pt."ProcessingFee"                 AS processing_fee,
  pt."Source"                        AS payment_source,
  pt."PaymentType"                   AS payment_type,
  COALESCE(pt."PaymentProviderName", '') AS payment_provider_name,
  
  -- Apply COALESCE AFTER the join to avoid NULLs when no match found
  COALESCE(rf.sum_total_refund_amount, 0.00)      AS sum_total_refund_amount,
  COALESCE(rf.sum_refunded_processing_fee, 0.00)  AS sum_refunded_processing_fee

FROM order_report_sch.orders_with_p_l_u AS plu

LEFT JOIN public."PaymentTransactions" pt
  ON pt."OrderId" = plu.order_id

LEFT JOIN (
  SELECT
    "PaymentTransactionId" AS payment_transaction_id,
    ROUND(SUM("Amount")::numeric, 2)               AS sum_total_refund_amount,
    ROUND(SUM("RefundedProcessingFee")::numeric, 2) AS sum_refunded_processing_fee
  FROM public."PaymentRefund"
  GROUP BY "PaymentTransactionId"
) rf
  ON rf.payment_transaction_id = pt."Id";


-- CHECKS
SELECT * FROM order_report_sch.orders_with_payments
 WHERE order_number = 100000004977 ORDER BY order_item_id;

SELECT * FROM public."PaymentRefund"
 WHERE "PaymentTransactionId" = '801bea46-e53b-4cdd-a52e-a201fab97133';
---------------------------------------------------------------------------------------------------
-- STEP 1.4: orders_with_coupons
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.orders_with_coupons;
CREATE TABLE order_report_sch.orders_with_coupons AS
WITH agg AS (
  SELECT
    oc."OrderItemId" AS order_item_id,
    STRING_AGG(c."CouponCode",',' ORDER BY c."CouponCode") AS coupon_code
  FROM public."OrderCoupons" oc
  JOIN public."Coupons"       c ON c."Id" = oc."CouponId"
  GROUP BY oc."OrderItemId"
)
SELECT
  pay.*,
  COALESCE(agg.coupon_code,'') AS coupon_code
FROM order_report_sch.orders_with_payments pay
LEFT JOIN agg ON agg.order_item_id = pay.order_item_id;

-- CHECKS
SELECT * FROM order_report_sch.orders_with_coupons
 WHERE order_number = 100000004977 ORDER BY order_item_id;


---------------------------------------------------------------------------------------------------
-- STEP 1.5: order_report_raw (format dates, prorate fees)
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.order_report_raw;

CREATE TABLE order_report_sch.order_report_raw AS
SELECT
  ocp.reservation_code,
  ocp.order_id                                AS order_id_original,
  ocp.order_number,
  ocp.order_item_id,
  TO_CHAR(
    (ocp.created_on_items AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago',
    'DD/MM/YYYY'
  )                                           AS created_on_items_ist,

    TO_CHAR(ocp.created_on_items AT TIME ZONE 'America/Chicago','DD/MM/YYYY')  AS created_on_items,
  
  ROUND(ocp.original_amount::numeric, 2)      AS original_amount,
  ROUND(ocp.sum_total_refund_amount::numeric, 2) AS order_level_refund,
  ROUND(ocp.total::numeric, 2)                AS total,
  
  COALESCE(ocp.payment_source, '')            AS payment_source,
  COALESCE(ocp.payment_type, '')              AS payment_type,
  COALESCE(ocp.payment_provider_name, '')     AS payment_provider_name,
  
  ocp.is_refunded,
  
  CASE
    WHEN ocp.payment_source = 'Consumer Web' THEN ''
    ELSE COALESCE(ocp.user_name, '')
  END                                         AS user_name,
  
  COALESCE(ocp.product_name, '')              AS product_name,
 

  TO_CHAR((ocp.start_date AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS start_date,
  TO_CHAR((ocp.end_date   AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS end_date,

  TO_CHAR(ocp.start_date AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS start_date_n,
  TO_CHAR(ocp.end_date   AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS end_date_n,
  
  COALESCE(ocp.location_name, '')             AS location_name,
  COALESCE(ocp.site_name, '')                 AS site_name,
  
  ROUND(ocp.total_items::numeric, 2)          AS total_items,
  COALESCE(ocp.coupon_code, '')               AS coupon_code,
  ROUND(ocp.coupon_discount::numeric, 2)      AS coupon_discount,
  ROUND(ocp.discount::numeric, 2)             AS discount,
  ROUND(ocp.tip::numeric, 2)                  AS tip,
  
  ROUND(
    (ocp.total_items - ocp.coupon_discount - ocp.discount)::numeric, 2
  )                                           AS final_line_item_sub_total,

  ROUND(ocp.line_item_booking_fee::numeric, 2) AS line_item_booking_fee,

COALESCE(
  ROUND(
    (ocp.processing_fee * ocp.actual_amount_items / NULLIF(ocp.original_amount, 0))::numeric,
    2),0.00 ) AS create_line_item_processing_fee,

CASE
  WHEN (ocp.sum_refunded_processing_fee * ocp.refunded_total_item) = 0 THEN 0.00
  ELSE ROUND(
    (ocp.sum_refunded_processing_fee * ocp.refunded_total_item / NULLIF(ocp.sum_total_refund_amount, 0))::numeric,
    2
  )
END AS refund_line_item_processing_fee,

  ROUND(ocp.tax_percentage::numeric, 2)       AS tax_percentage,
  ROUND(ocp.sales_tax::numeric, 2)            AS sales_tax,
  ROUND(ocp.delivery_fee::numeric, 2)         AS delivery_fee,

  

  COALESCE(ocp.partner_name, '')              AS partner_name,

  CASE
    WHEN ocp.partner_id = 0 THEN ''
    ELSE COALESCE(ocp.partner_id::text, '')
  END                                         AS partner_id,

  ROUND(ocp.order_booking_fee::numeric, 2)    AS order_booking_fee,
  ROUND(ocp.processing_fee::numeric, 2)       AS processing_fee,
  ROUND(ocp.sum_refunded_processing_fee::numeric, 2) AS refunded_processing_fee,
  ROUND(ocp.actual_amount_items::numeric, 2)  AS actual_amount_items,
  ROUND(ocp.total::numeric, 2)                AS total_order_value

FROM order_report_sch.orders_with_coupons ocp;


-- CHECK
SELECT * FROM order_report_sch.order_report_raw WHERE reservation_code = 'LDV0014809' ORDER BY order_item_id;
SELECT * FROM order_report_sch.order_report_raw WHERE reservation_code = 'LDV0014980' ORDER BY order_item_id;
SELECT * FROM order_report_sch.order_report_raw WHERE reservation_code = 'LDV0014769' ORDER BY order_item_id;
---------------------------------------------------------------------------------------------------
-- STEP 1.6: order_report_final (round & label, all text blanks)
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.order_report_pre_dc;
CREATE TABLE order_report_sch.order_report_pre_dc AS
SELECT
  COALESCE(reservation_code,'')                        AS "RID",
  COALESCE(order_number::text,'')                      AS "Order Id",
  COALESCE(order_item_id::text,'')                     AS "Line Item ID",
  COALESCE(created_on_items,'')                  	   AS "Order Date",
  COALESCE(original_amount::text,'')                   AS "Original Order Amount",
  COALESCE(order_level_refund::text,'')                AS "Order Refunded Amount",
  COALESCE(ROUND(total::numeric,2)::text,'')           AS "Order Amount",
  COALESCE(payment_source,'')                          AS "Order Type",
  COALESCE(payment_type,'')                            AS "Payment Method",
  COALESCE(payment_provider_name,'')                   AS "Payment Processor",
  UPPER(COALESCE(is_refunded::text,''))                AS "Refunded?",
  COALESCE(user_name,'')                               AS "User",
  COALESCE(product_name,'')                            AS "Product Name",
  COALESCE(start_date,'')                              AS "Rental Start Date",
  COALESCE(end_date,'')                                AS "Rental End Date",
  COALESCE(location_name,'')                           AS "Location",
  COALESCE(site_name,'')                               AS "Subsite Location",
  COALESCE(total_items::text,'')                       AS "Line Item Sub Total",
  COALESCE(coupon_code,'')                             AS "Promo Code ID",
  COALESCE(ROUND(coupon_discount::numeric,2)::text,'') AS "Coupon Amount",
  COALESCE(discount::text,'')                          AS "Line Item Discount",
  COALESCE(tip::text,'')                               AS "Gratuity",
  COALESCE(ROUND(final_line_item_sub_total::numeric,2)::text,'')
                                                      AS "Final Line Item Sub Total",
  COALESCE(ROUND(line_item_booking_fee::numeric,2)::text,'')
                                                      AS "Booking Fee",
  COALESCE(ROUND(create_line_item_processing_fee::numeric,2)::text,'')
                                                      AS "Create Line Item Payment Processor Fee",
  COALESCE(ROUND(refund_line_item_processing_fee::numeric,2)::text,'')
                                                      AS "Refund Line Item Payment Processor Fee",
  COALESCE(ROUND(
    create_line_item_processing_fee - refund_line_item_processing_fee
  ,2)::text,'')                                       AS "Total Line Item Payment Processor Fee",
  COALESCE(ROUND(tax_percentage::numeric,2)::text,'')  AS "Tax %",
  COALESCE(ROUND(sales_tax::numeric,2)::text,'')       AS "Tax",
  COALESCE(delivery_fee::text,'')                     AS "Delivery Fee",
  COALESCE(
  	ROUND(
    	ROUND(tip::numeric, 2)
    	+ ROUND(final_line_item_sub_total::numeric, 2)
    	+ ROUND(line_item_booking_fee::numeric, 2)
    	+ ROUND(sales_tax::numeric, 2)
		+ ROUND(delivery_fee::numeric, 2)
    	- (ROUND(create_line_item_processing_fee::numeric, 2) - ROUND(refund_line_item_processing_fee::numeric, 2)),
  	2),
 	 0.00
			) AS "Total Collected",

  COALESCE(partner_name,'')                            AS "Partner Name",
  COALESCE(partner_id::text,'')                        AS "PartnerID",
  order_id_original::uuid AS order_id_original
  
FROM order_report_sch.order_report_raw
ORDER BY "Line Item ID";

-- final validation
SELECT * FROM order_report_sch.order_report_pre_dc ORDER BY "Line Item ID";
SELECT count(DISTINCT "Order Id") FROM order_report_sch.order_report_pre_dc;

SELECT * FROM order_report_sch.order_report_pre_dc WHERE "Line Item ID" = '59a409f8-a4a3-4451-bc93-68110d0b7bb4';


--------------------------------------------------------------------------------
-- DYNAMIC CONTROLS
--------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS tablefunc;

--------------------------------------------------------------------------------
-- 1) Flatten all 4 control levels
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.dc_orders;
CREATE TABLE order_report_sch.dc_orders AS

  -- 1a) Order‐item–level controls
  SELECT
    odcv."OrderId"::text   AS order_id,
	--odcv."DynamicControlOptionId" AS dc_option_id,
	--odco."DynamicControlId" AS dc_id,
	    odc."DisplayName"           AS control_name,
	odco."Option"               AS control_value,
    
    odc."ShowInExport"			AS show_in_export
	
  FROM public."OrderDynamicControlValues" odcv
  LEFT JOIN public."OrderDynamicControlOptions" odco ON odcv."DynamicControlOptionId"       = odco."Id"
  LEFT JOIN public."OrderDynamicControls"  odc ON odco."DynamicControlId" = odc."Id"
  WHERE odc."ShowInExport" = true;


--Checks
--SELECT * FROM order_report_sch.dc_orders WHERE dc_id = '35502f5d-e48b-474a-b5f6-dcdbbfddc274';
SELECT * FROM order_report_sch.dc_orders ORDER BY order_id;
--------------------------------------------------------------------------------
-- 2) Dynamically pivot every control_name into its own column,
--    coalescing NULL → '' on output
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.order_controls;

DO $do$
DECLARE
  col_defs TEXT;
  cat_list TEXT;
  dyn_sql  TEXT;
  rec_count INT;
BEGIN
  -- Step 1: Aggregate duplicates so multiple control_values merge
  SELECT COUNT(*) INTO rec_count FROM order_report_sch.dc_orders;

  IF rec_count = 0 THEN
    RAISE NOTICE 'No data in dc_orders — creating empty table.';
    CREATE TABLE order_report_sch.order_controls (
      order_id UUID
    );
  ELSE
    DROP TABLE IF EXISTS order_report_sch.dc_orders_agg;
    CREATE TABLE order_report_sch.dc_orders_agg AS
    SELECT
        order_id,
        control_name,
        STRING_AGG(control_value, ', ' ORDER BY control_value) AS control_value
    FROM order_report_sch.dc_orders
    GROUP BY order_id, control_name;

    -- Step 2: Build category list and column definitions
    SELECT string_agg(quote_literal(control_name), ',' ORDER BY control_name),
           string_agg(format('%I TEXT', replace(control_name,'"','')), ', ' ORDER BY control_name)
      INTO cat_list, col_defs
    FROM (
      SELECT DISTINCT control_name
      FROM order_report_sch.dc_orders_agg
    ) sub;

    -- Step 3: Build and run pivot
    dyn_sql := format(
      'CREATE TABLE order_report_sch.order_controls AS
       SELECT *
       FROM crosstab(
         $$SELECT order_id, control_name, control_value
           FROM order_report_sch.dc_orders_agg
           ORDER BY order_id, control_name$$,
         $$SELECT unnest(ARRAY[%s])$$
       ) AS ct(
         order_id UUID,
         %s
       );',
      cat_list,
      col_defs
    );

    EXECUTE dyn_sql;
  END IF;
END
$do$ LANGUAGE plpgsql;


SELECT * FROM order_report_sch.order_controls;


  -- 1b) Product‐level controls

DROP TABLE IF EXISTS order_report_sch.product_controls_src;

CREATE TABLE order_report_sch.product_controls_src AS
WITH item_level AS (
    SELECT
        oi."Id"::text AS order_item_id_p,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
    FROM public."OrderItemDynamicControls" oidc
    JOIN public."OrderItems" oi
        ON oidc."OrderItemId" = oi."Id"
    JOIN public."ProductDynamicControlOptions" pdco
        ON oidc."DynamicControlOptionId" = pdco."Id"
    JOIN public."ProductDynamicControls" pdc
        ON pdco."DynamicControlId" = pdc."Id"
    WHERE oidc."DynamicControlType" = 0 AND   pdc."ShowInExport" = true
),
product_level AS (
    SELECT
        oi."Id"::text AS order_item_id_p,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
    FROM public."ProductDynamicControlValues" pdcv
    JOIN public."ProductDynamicControlOptions" pdco
        ON pdcv."DynamicControlOptionId" = pdco."Id"
    JOIN public."ProductDynamicControls" pdc
        ON pdco."DynamicControlId" = pdc."Id"
    JOIN public."OrderItems" oi
        ON pdcv."ProductId" = oi."ProductId"
    WHERE pdc."ShowInExport" = true
	AND NOT EXISTS (
        SELECT 1
        FROM item_level il
        WHERE il.order_item_id_p = oi."Id"::text
    )
)
SELECT * FROM item_level
UNION ALL
SELECT * FROM product_level;

-- Check output
SELECT *
FROM order_report_sch.product_controls_src
--WHERE control_name = 'Tax Counties'
ORDER BY order_item_id_p, control_name;


SELECT * FROM order_report_sch.product_controls_src Where order_item_id_p= '14620527-b63d-4f46-a23f-16522327fd8b';
--------------------------------------------------------------------------
-- Step 2: Build product category list & column definitions for pivot
--------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.product_controls;

DO $do$
DECLARE
  col_defs TEXT;
  cat_list TEXT;
  dyn_sql  TEXT;
  rec_count INT;
BEGIN
  -- Check if there is any data
  SELECT COUNT(*) INTO rec_count FROM order_report_sch.product_controls_src;

  IF rec_count = 0 THEN
    -- Create empty table with only order_item_id_p column
    CREATE TABLE order_report_sch.product_controls (
      order_item_id_p UUID
    );
  ELSE
    -- Step A: Aggregate duplicates so multiple control_values are combined
    DROP TABLE IF EXISTS order_report_sch.product_controls_agg;
    CREATE TABLE order_report_sch.product_controls_agg AS
    SELECT
        order_item_id_p,
        control_name,
        STRING_AGG(control_value, ', ' ORDER BY control_value) AS control_value
    FROM order_report_sch.product_controls_src
    GROUP BY order_item_id_p, control_name;

    -- Step B: Build category list
    SELECT string_agg(quote_literal(control_name), ',' ORDER BY control_name)
      INTO cat_list
    FROM (
      SELECT DISTINCT control_name
      FROM order_report_sch.product_controls_agg
    ) sub;

    -- Step C: Build column definitions
    SELECT string_agg(format('%I TEXT', control_name), ', ' ORDER BY control_name)
      INTO col_defs
    FROM (
      SELECT DISTINCT control_name
      FROM order_report_sch.product_controls_agg
    ) sub;

    -- Step D: Create pivot table
    dyn_sql := format(
      'CREATE TABLE order_report_sch.product_controls AS
       SELECT *
       FROM crosstab(
         $$SELECT order_item_id_p, control_name, control_value
           FROM order_report_sch.product_controls_agg
           ORDER BY order_item_id_p, control_name$$,
         $$SELECT unnest(ARRAY[%s])$$
       ) AS ct(
         order_item_id_p UUID,
         %s
       );',
      cat_list,
      col_defs
    );

    EXECUTE dyn_sql;
  END IF;
END
$do$ LANGUAGE plpgsql;


-- Quick check
SELECT * 
FROM order_report_sch.product_controls
ORDER BY order_item_id_p;

  -- 1c) Location‐level controls

-- Step 1: Prepare location-level dynamic control details
DROP TABLE IF EXISTS order_report_sch.location_controls_src;

CREATE TABLE order_report_sch.location_controls_src AS
WITH item_level AS (
    SELECT
        oi."Id"::text AS order_item_id_l,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
    FROM public."OrderItemDynamicControls" oidc
    JOIN public."OrderItems" oi
        ON oidc."OrderItemId" = oi."Id"
    JOIN public."LocationDynamicControlOptions" pdco
        ON oidc."DynamicControlOptionId" = pdco."Id"
    JOIN public."LocationDynamicControls" pdc
        ON pdco."DynamicControlId" = pdc."Id"
    WHERE oidc."DynamicControlType" = 1 AND pdc."ShowInExport" = true
),
location_level AS (
    SELECT
        oi."Id"::text AS order_item_id_l,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
    FROM public."LocationDynamicControlValues" pdcv
    JOIN public."LocationDynamicControlOptions" pdco
        ON pdcv."DynamicControlOptionId" = pdco."Id"
    JOIN public."LocationDynamicControls" pdc
        ON pdco."DynamicControlId" = pdc."Id"
    JOIN public."OrderItems" oi
        ON pdcv."LocationId" = oi."LocationId"
    WHERE  pdc."ShowInExport" = true
	AND NOT EXISTS (
        SELECT 1
        FROM item_level il
        WHERE il.order_item_id_l = oi."Id"::text
    )
)
SELECT * FROM item_level
UNION ALL
SELECT * FROM location_level;

-- Check output
SELECT *
FROM order_report_sch.location_controls_src
ORDER BY order_item_id_l, control_name;

SELECT * FROM order_report_sch.location_controls_src Where order_item_id_l= '14620527-b63d-4f46-a23f-16522327fd8b';
SELECT * FROM order_report_sch.location_controls_src Where order_item_id_l= '14620527-b63d-4f46-a23f-16522327fd8b';
SELECT * FROM order_report_sch.location_controls_src Where order_item_id_l= 'c2b94eec-2f78-424c-b65f-9bca23a04c71';
SELECT * FROM order_report_sch.location_controls_src Where order_item_id_l= '3b191b49-b8d4-445d-b69f-4e7c6c6bacb6';
    --------------------------------------------------------------------------
    -- Step 2: Build location category list & column definitions for pivot
    --------------------------------------------------------------------------
-- Step 2: Pivot location-level dynamic controls

DROP TABLE IF EXISTS order_report_sch.location_controls;

DO $do$
DECLARE
  col_defs TEXT;
  cat_list TEXT;
  dyn_sql  TEXT;
  rec_count INT;
BEGIN
  -- Step 0: Check if there is any source data
  SELECT COUNT(*) INTO rec_count FROM order_report_sch.location_controls_src;

  IF rec_count = 0 THEN
    RAISE NOTICE 'No data in location_controls_src — creating empty table.';
    CREATE TABLE order_report_sch.location_controls (
      order_item_id_l UUID
    );
  ELSE
    -- Step A: Aggregate duplicate control values
    DROP TABLE IF EXISTS order_report_sch.location_controls_agg;
    CREATE TABLE order_report_sch.location_controls_agg AS
    SELECT
        order_item_id_l,
        control_name,
        STRING_AGG(control_value, ', ' ORDER BY control_value) AS control_value
    FROM order_report_sch.location_controls_src
    GROUP BY order_item_id_l, control_name;

    -- Step B: Build category list
    SELECT string_agg(quote_literal(control_name), ',' ORDER BY control_name),
           string_agg(format('%I TEXT', control_name), ', ' ORDER BY control_name)
      INTO cat_list, col_defs
    FROM (
      SELECT DISTINCT control_name
      FROM order_report_sch.location_controls_agg
    ) sub;

    -- Step C: Create pivot query
    dyn_sql := format(
      'CREATE TABLE order_report_sch.location_controls AS
       SELECT *
       FROM crosstab(
         $$SELECT order_item_id_l, control_name, control_value
           FROM order_report_sch.location_controls_agg
           ORDER BY order_item_id_l, control_name$$,
         $$SELECT unnest(ARRAY[%s])$$
       ) AS ct(
         order_item_id_l UUID,
         %s
       );',
      cat_list,
      col_defs
    );

    EXECUTE dyn_sql;
  END IF;
END
$do$ LANGUAGE plpgsql;


SELECT * FROM order_report_sch.location_controls Where order_item_id_l= '14620527-b63d-4f46-a23f-16522327fd8b';

SELECT * FROM order_report_sch.location_controls Where order_item_id_l= '3b191b49-b8d4-445d-b69f-4e7c6c6bacb6';
SELECT * FROM order_report_sch.location_controls Where order_item_id_l= '3b191b49-b8d4-445d-b69f-4e7c6c6bacb6';


-- Check output
SELECT *
FROM order_report_sch.location_controls
ORDER BY order_item_id_l;

SELECT * FROM order_report_sch.location_controls Where order_item_id_l= '14620527-b63d-4f46-a23f-16522327fd8b';
SELECT * FROM order_report_sch.location_controls Where order_item_id_l= '3b191b49-b8d4-445d-b69f-4e7c6c6bacb6';
--------------------------------------------------------------------------------
-- 3) Join these dynamic columns onto final report
--    then immediately drop the helper key so it never appears
--------------------------------------------------------------------------------

SELECT * FROM order_report_sch.location_controls;
SELECT * FROM order_report_sch.product_controls;
SELECT * FROM order_report_sch.order_controls;

DROP TABLE IF EXISTS order_report_sch.order_report_dynamic;
CREATE TABLE order_report_sch.order_report_dynamic AS
SELECT
  r.*,
  oc.*,
  -- Dynamic columns from product-level controls
  pc.*,

  -- Dynamic columns from location-level controls
  lc.*

FROM order_report_sch.order_report_pre_dc r
LEFT JOIN order_report_sch.order_controls oc
  ON r.order_id_original = oc.order_id::uuid
LEFT JOIN order_report_sch.product_controls pc
  ON r."Line Item ID"::uuid = pc.order_item_id_p
LEFT JOIN order_report_sch.location_controls lc
  ON r."Line Item ID"::uuid = lc.order_item_id_l
ORDER BY r."Line Item ID";

ALTER TABLE order_report_sch.order_report_dynamic
DROP COLUMN order_item_id_p,
DROP COLUMN order_item_id_l,
DROP COLUMN order_id_original,
DROP COLUMN order_id;

--check

SELECT * FROM order_report_sch.order_report_dynamic WHERE "RID" = 'LDV0014980' ORDER BY "Line Item ID";

--Arranging "Tax Counties" column
DO $$
DECLARE
  col_list TEXT;
  reordered_cols TEXT;
  tax_col TEXT := quote_ident('Tax Counties');
  dyn_sql TEXT;
BEGIN
  -- Step 1: Get all columns from the dynamic table
  SELECT string_agg(quote_ident(column_name), ', ')
  INTO col_list
  FROM information_schema.columns
  WHERE table_schema = 'order_report_sch'
    AND table_name = 'order_report_dynamic'
    AND column_name <> 'Tax Counties';  -- exclude it for now

  -- Step 2: Convert to array and insert "Tax Counties" at position 18
  SELECT string_agg(col, ', ')
  INTO reordered_cols
  FROM (
    SELECT *
    FROM (
      SELECT col, ord
      FROM unnest(string_to_array(col_list, ', ')) WITH ORDINALITY AS t(col, ord)
      UNION ALL
      SELECT tax_col, 18
    ) AS combined
    ORDER BY ord
  ) AS final_order;

  -- Step 3: Create reordered table
  dyn_sql := '
    DROP TABLE IF EXISTS order_report_sch.final;
    CREATE TABLE order_report_sch.final AS
    SELECT ' || reordered_cols || '
    FROM order_report_sch.order_report_dynamic;
  ';

  EXECUTE dyn_sql;
END $$;

--SELECT * FROM order_report_sch.order_report_final WHERE "RID" = 'LDV0014980' ORDER BY "Line Item Id";


DO $$
DECLARE
  col_array TEXT[];
  transformed_cols TEXT;
  dyn_sql TEXT;
BEGIN
  -- Step 1: Get all columns from the 'final' table
  SELECT array_agg(
    'COALESCE(' || quote_ident(column_name) || '::text, '''') AS ' || quote_ident(column_name)
    ORDER BY ordinal_position
  )
  INTO col_array
  FROM information_schema.columns
  WHERE table_schema = 'order_report_sch'
    AND table_name = 'final';

  -- Step 2: Join all transformed columns into a single string
  transformed_cols := array_to_string(col_array, ', ');

  -- Step 3: Create a new table with NULLs replaced by blanks
  dyn_sql := '
    DROP TABLE IF EXISTS order_report_sch.order_report_final;
    CREATE TABLE order_report_sch.order_report_final AS
    SELECT ' || transformed_cols || '
    FROM order_report_sch.final;
  ';

  EXECUTE dyn_sql;
END $$;

SELECT * FROM order_report_sch.order_report_final WHERE "RID" = 'LDV0014980' ORDER BY "Line Item ID";




---------------------------------------------------------------------------------------------------
-- STEP 1.7: Selective order_numbers for testing
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.expected_order_ids;
CREATE TABLE order_report_sch.expected_order_ids (order_number BIGINT);

INSERT INTO order_report_sch.expected_order_ids (order_number)
VALUES
(100000004963),(100000004964),(100000004965),(100000004966),(100000004967),(100000004968),(100000004969),(100000005165),(100000005164),
(100000004970),(100000004971),(100000004972),(100000004973),(100000004974),(100000004975),(100000004976),(100000004977),(100000004978),
(100000004979),(100000004980),(100000004981),(100000004982),(100000004983),(100000004984),(100000004986),(100000004987),(100000004988),
(100000004989),(100000004990),(100000004991),(100000004992),(100000004993),(100000004994),(100000004997),(100000004998),(100000004999),
(100000005000),(100000005001),(100000005002),(100000005003),(100000005004),(100000005005),(100000005006),(100000005007),(100000005008),
(100000005009),(100000005010),(100000005011),(100000005012),(100000005013),(100000005014),(100000005015),(100000005016),(100000005017),
(100000005018),(100000005019),(100000005020),(100000005021),(100000005022),(100000005023),(100000005024),(100000005025),(100000005026),
(100000005027),(100000005028),(100000005029),(100000005030),(100000005031),(100000005032),(100000005033),(100000005034),(100000005035),
(100000005036),(100000005037),(100000005038),(100000005039),(100000005040),(100000005041),(100000005042),(100000005043),(100000005044),
(100000005045),(100000005046),(100000005047),(100000005048),(100000005049),(100000005050),(100000005051),(100000005052),(100000005053),
(100000005054),(100000005055),(100000005059),(100000005057),(100000005058),(100000005060),(100000005061),(100000005062),(100000005063),
(100000005064),(100000005067),(100000005068),(100000005069),(100000005070),(100000005071),(100000005072),(100000005073),(100000005074),
(100000005075),(100000005076),(100000005077),(100000005078),(100000005079),(100000005080),(100000005081),(100000005082),(100000005083),
(100000005084),(100000005085),(100000005086),(100000005087),(100000005088),(100000005089),(100000005090),(100000005091),(100000005092),
(100000005093),(100000005094),(100000005095),(100000005096),(100000005097),(100000005098),(100000005099),(100000005100),(100000005101),
(100000005102),(100000005103),(100000005104),(100000005105),(100000005106),(100000005107),(100000005108),(100000005109),(100000005110),
(100000005111),(100000005112),(100000005113),(100000005114),(100000005115),(100000005116),(100000005117),(100000005118),(100000005119),
(100000005120),(100000005121),(100000005122),(100000005123),(100000005124),(100000005125),(100000005126),(100000005127),(100000005128),
(100000005129),(100000005130),(100000005131),(100000005132),(100000005133),(100000005134),(100000005135),(100000005136),(100000005137),
(100000005138),(100000005139),(100000005140),(100000005141),(100000005142),(100000005143),(100000005144),(100000005145),(100000005146),
(100000005147),(100000005148),(100000005149),(100000005150),(100000005151),(100000005152),(100000005153),(100000005154),(100000005155),
(100000005156),(100000005157),(100000005158),(100000005159),(100000005160),(100000005161),(100000005162),(100000005163),(100000005166),
(100000005167),(100000005168),(100000005169),(100000005170),(100000005171),(100000005172),(100000005173),(100000005178),(100000005174),
(100000005175),(100000005176),(100000005177),(100000005179),(100000005180),(100000005181),(100000005182),(100000005183),(100000005184),
(100000005185),(100000005186);

DROP TABLE IF EXISTS order_report_sch.order_report_g;
CREATE TABLE order_report_sch.order_report_g AS
SELECT f.*
FROM order_report_sch.order_report_final f
JOIN order_report_sch.expected_order_ids e
  ON f."Order Id"::BIGINT = e.order_number;

-- CHECK
SELECT count(DISTINCT "Order Id") FROM order_report_sch.order_report_g;
SELECT count(*) FROM order_report_sch.order_report_g;
SELECT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014809' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014980' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014973' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014919' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014771' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_g WHERE "Order Id" = '100000005027' ORDER BY "Line Item ID";

SELECT * FROM order_report_sch.order_report_g; 

SELECT * FROM public."Orders" WHERE "OrderNumber" = '100000005120';


SELECT 
  "CreatedOn",
  TO_CHAR(
    ("CreatedOn" AT TIME ZONE 'UTC') AT TIME ZONE 'America/Chicago',
    'MM/DD/YYYY'
  ) AS created_on_items,
  (("CreatedOn" AT TIME ZONE 'UTC') AT TIME ZONE 'America/Chicago') AS created_on_utc
FROM public."OrderItems"
WHERE "OrderId" = '400f1676-ea82-443d-882d-65ecf8b21668';
