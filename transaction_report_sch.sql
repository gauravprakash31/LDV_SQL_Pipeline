--===============================================================
-- Transaction_report_sch.sql
-- Build static order_report_final with NULLs → blanks
--==============================================================

CREATE EXTENSION IF NOT EXISTS tablefunc;
DROP SCHEMA IF EXISTS transaction_report_sch CASCADE;
CREATE SCHEMA transaction_report_sch;

---------------------------------------------------------------------------------------------------
-- STEP 1.1: orders_with_items (include refunded‐item history)
---------------------------------------------------------------------------------------------------
---Processing Order_item_history table

DROP TABLE IF EXISTS transaction_report_sch.orders_item_history_agg;

CREATE TABLE transaction_report_sch.orders_item_history_agg AS
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
    "PaymentProcessingFee"                     AS refunded_processing_fee,
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

SELECT * FROM transaction_report_sch.orders_item_history_agg WHERE order_id= 'b9aa1928-4acf-4f6e-994a-5f9b4c303404' ORDER BY order_item_id;

DROP TABLE IF EXISTS transaction_report_sch.orders_with_items;
CREATE TABLE transaction_report_sch.orders_with_items AS
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
  oi."TotalAmount"			AS original_line_item_amount,
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
    ELSE oi."IsRefunded"
  END                       AS is_refunded,
  oi."StartDate"            AS start_date,
  oi."EndDate"              AS end_date,
  oi."PartnerId"            AS partner_id,
  oi."BookingFee"           AS line_item_booking_fee,
  oi."ParentOrderItemId",
  oi."IsALaCarte",
  oi."TotalAmount"          AS total_amount_items,
  rt."Name"					AS rental_type,
  ih_agg.transaction_date_oih,
  COALESCE(ih_agg.refunded_total_item,0.00)   AS refunded_total_item,
  COALESCE(ih_agg.earliest_total_amount,0.00)   AS earliest_total_amount,

    CASE
    WHEN COALESCE(ih_agg.refunded_total_item,0.00) >0 THEN ih_agg.earliest_total_amount
    ELSE oi."TotalAmount"
  END  AS actual_amount_items
  
FROM public."Orders"       o
LEFT JOIN public."Reservations"        r  ON r."Id"              = o."ReservationId"
LEFT JOIN public."OrderItems"         oi  ON oi."OrderId"         = o."Id"
LEFT JOIN transaction_report_sch.orders_item_history_agg AS ih_agg ON ih_agg.order_item_id = oi."Id"
LEFT JOIN public."RentalTypes"         rt  ON rt."Id"     = oi."RentalTypeId"

WHERE NOT (oi."ParentOrderItemId" IS NULL AND oi."IsALaCarte" = true);



-- CHECKS
SELECT * FROM transaction_report_sch.orders_with_items WHERE order_number = 100000005009 ORDER BY order_item_id;
SELECT * FROM public."OrderItems" WHERE "OrderId" = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404';
SELECT count(DISTINCT order_id) FROM order_report_sch.orders_with_items;
SELECT * FROM transaction_report_sch.orders_with_items WHERE order_number = 100000005009;

SELECT * FROM public."OrderItems"   WHERE  "Id"  = 'b18f25b5-8985-4ec2-b4fb-17275107b82b';

---------------------------------------------------------------------------------------------------
-- STEP 1.2: orders_with_p_l_u (enrich with product, location, site, user, partner, tax%)
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS transaction_report_sch.orders_with_p_l_u;
CREATE TABLE transaction_report_sch.orders_with_p_l_u AS
SELECT
  base.*,
  p."Name"               AS product_name,
  l."Name"               AS location_name,
  site."Name"            AS site_name,
  CONCAT(u."FirstName",' ',u."LastName") AS user_name,
  pa."Name"              AS partner_name,
  COALESCE(site."TaxRate",l."TaxRate")::numeric AS tax_percentage
FROM transaction_report_sch.orders_with_items AS base
LEFT JOIN public."Products"   p   ON p."Id"           = base.product_id
LEFT JOIN public."Locations"  l   ON l."Id"           = base.location_id
LEFT JOIN public."Locations"  site ON site."Id"       = base.site_id
LEFT JOIN public."Users"      u   ON u."Id"           = base.created_by
LEFT JOIN public."Partners"   pa  ON pa."Id"          = base.partner_id;

-- CHECKS
SELECT * FROM transaction_report_sch.orders_with_p_l_u 
 WHERE order_number = 100000005184 ORDER BY order_item_id;
SELECT count(DISTINCT order_id) FROM transaction_report_sch.orders_with_p_l_u;


---------------------------------------------------------------------------------------------------
-- STEP 1.3: orders_with_payments (attach txn + refund sums)
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS transaction_report_sch.orders_with_payments;

CREATE TABLE transaction_report_sch.orders_with_payments AS
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

FROM transaction_report_sch.orders_with_p_l_u AS plu

LEFT JOIN public."PaymentTransactions" pt
  ON pt."OrderId" = plu.order_id

LEFT JOIN (
  SELECT
    "PaymentTransactionId" AS payment_transaction_id,
    SUM("Amount")::numeric               AS sum_total_refund_amount,
    SUM("RefundedProcessingFee")::numeric AS sum_refunded_processing_fee
  FROM public."PaymentRefund"
  GROUP BY "PaymentTransactionId"
) rf
  ON rf.payment_transaction_id = pt."Id";


-- CHECKS
SELECT * FROM transaction_report_sch.orders_with_payments
 WHERE order_number = 100000005184 ORDER BY order_item_id;

SELECT * FROM public."PaymentRefund"
 WHERE "PaymentTransactionId" = '801bea46-e53b-4cdd-a52e-a201fab97133';
 
---------------------------------------------------------------------------------------------------
-- STEP 1.4: orders_with_coupons
---------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS transaction_report_sch.orders_with_coupons;
CREATE TABLE transaction_report_sch.orders_with_coupons AS
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
FROM transaction_report_sch.orders_with_payments pay
LEFT JOIN agg ON agg.order_item_id = pay.order_item_id;

-- CHECKS
SELECT * FROM transaction_report_sch.orders_with_coupons
WHERE order_number = 100000005184 ORDER BY order_item_id;



---------------------------------------------------------------------------------------------------
-- STEP 1.5: payment_report_raw (format dates, prorate fees)
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS transaction_report_sch.payment_rows_temp;

CREATE TABLE transaction_report_sch.payment_rows_temp AS

SELECT

  ocp.reservation_code,
  ocp.order_number,
  ocp.order_item_id,
  ocp.created_on_items,	
  TO_CHAR(ocp.created_on_items AT TIME ZONE 'America/Chicago', 'MM/DD/YYYY') AS original_order_date,	
  
  TO_CHAR(ocp.created_on_items AT TIME ZONE 'America/Chicago','MM/DD/YYYY')  AS transaction_date,
  TO_CHAR(ocp.created_on_items  AT TIME ZONE 'America/Chicago','HH12:MI:SS AM') AS timestamp,

  TO_CHAR((ocp.created_on_items AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'MM/DD/YYYY') AS original_order_date_ist,
  TO_CHAR((ocp.created_on_items   AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'MM/DD/YYYY') AS transaction_date_ist,
  
  TO_CHAR((ocp.created_on_items   AT TIME ZONE 'IST')  AT TIME ZONE 'America/Chicago','HH12:MI:SS AM') AS timestamp_ist,
  
  ROUND(ocp.actual_amount_items::numeric, 2)      AS original_line_item_amount,
  COALESCE(ocp.payment_source, '')            AS payment_source,
	
  'Payment' AS transaction_type, 

  COALESCE(ocp.payment_type, '')              AS payment_type,
  COALESCE(ocp.payment_provider_name, '')     AS payment_provider_name,
  NULL::text AS refund_order_number_actual,
  
  CASE
    WHEN ocp.payment_source = 'Consumer Web' THEN ''
    ELSE COALESCE(ocp.user_name, '')
  END                                         AS user_name,
  
  COALESCE(ocp.product_name, '')              AS product_name,
  ocp.rental_type							  AS rental_type,
  ocp.start_date AS start_date_original,
  ocp.end_date  AS end_date_original,
  TO_CHAR(ocp.start_date AT TIME ZONE 'America/Chicago', 'MM/DD/YYYY') AS start_date_n,
  TO_CHAR(ocp.end_date   AT TIME ZONE 'America/Chicago', 'MM/DD/YYYY') AS end_date_n,

  TO_CHAR((ocp.start_date AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'MM/DD/YYYY') AS start_date,
  TO_CHAR((ocp.end_date   AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'MM/DD/YYYY') AS end_date,
  
  COALESCE(ocp.location_name, '')             AS location_name,
  COALESCE(ocp.site_name, '')                 AS site_name,
   ''										  AS tax_counties,
  CASE
    WHEN (ocp.refunded_total_item) = 0 THEN ocp.total_items
    ELSE oih.total_oih
  END 						                  AS line_item_sub_total,
 
  COALESCE(ocp.coupon_code, '')               AS coupon_code,

  CASE
    WHEN (ocp.refunded_total_item) = 0 THEN ocp.coupon_discount
    ELSE oih.coupon_discount_oih
  END                       AS coupon_discount,

  CASE
    WHEN (ocp.refunded_total_item) = 0 THEN ocp.discount
    ELSE oih.discount_oih
  END                       AS discount,

  CASE
    WHEN (ocp.refunded_total_item) = 0 THEN ocp.tip
    ELSE oih.tip_oih
  END                       AS tip,
  
  
  ROUND(
    ((ocp.total_items + COALESCE(oih.refunded_total,0.00))
	- (ocp.coupon_discount + COALESCE(oih.refunded_coupon,0.00))
	- (ocp.discount + COALESCE(oih.refunded_discount,0.00)))::numeric, 2)      				AS final_line_item_sub_total,


  ROUND(ocp.line_item_booking_fee::numeric, 2) AS line_item_booking_fee,

  ROUND((ocp.processing_fee * ocp.actual_amount_items / NULLIF(ocp.original_amount, 0))::numeric,2
  )                                           AS create_line_item_processing_fee,


  ROUND(ocp.tax_percentage::numeric, 2)       AS tax_percentage,

  ROUND((ocp.sales_tax + COALESCE(oih.refunded_sales_tax,0.00))::numeric, 2)      AS sales_tax,
  ROUND(ocp.delivery_fee::numeric, 2)         AS delivery_fee,
  
  COALESCE(ocp.partner_name, '')              AS partner_name,
  
  CASE
    WHEN (ocp.partner_id) = 0 THEN NULL
    ELSE ocp.partner_id
  END                       				  AS partner_id,

  ROUND(ocp.order_booking_fee::numeric, 2)    AS order_booking_fee,
  ROUND(ocp.processing_fee::numeric, 2)       AS processing_fee,
  ROUND(ocp.sum_refunded_processing_fee::numeric, 2) AS refunded_processing_fee,
  ROUND(ocp.actual_amount_items::numeric, 2)  AS actual_amount_items,
  ROUND(ocp.total::numeric, 2)                AS total_order_value,
  ocp.order_id                                AS order_id_original,
  
  sum_total_refund_amount,
  sum_refunded_processing_fee,
  ocp.refunded_total_item,
  ocp.coupon_discount  AS coupon_discount_original,
  oih.refunded_coupon,
  ocp.total_items,
  
  
  COALESCE(oih.refunded_total,0.00)			  AS refunded_total


FROM transaction_report_sch.orders_with_coupons ocp
LEFT JOIN public."OrderHistory" oh ON oh."OrderId" = ocp.order_id
LEFT JOIN transaction_report_sch.orders_item_history_agg oih ON oih.order_item_id = ocp.order_item_id;

-- CHECK

SELECT * FROM transaction_report_sch.payment_rows_temp WHERE order_item_id = '56826b3c-a00c-42f5-a86e-4790b494dd2a';
SELECT * FROM transaction_report_sch.payment_rows_temp WHERE reservation_code = 'LDV0014809' ORDER BY order_item_id;
SELECT * FROM transaction_report_sch.payment_rows_temp WHERE reservation_code = 'LDV0014980' ORDER BY order_item_id;


-- Final Calculation step 

DROP TABLE IF EXISTS transaction_report_sch.payment_rows;

CREATE TABLE transaction_report_sch.payment_rows AS
SELECT 
  reservation_code,
  order_number,
  order_item_id,
  created_on_items,
  original_order_date,
  transaction_date,
  timestamp,
  original_order_date_ist,
  transaction_date_ist,
  timestamp_ist,
  original_line_item_amount,
  payment_source,
  transaction_type,
  payment_type,
  payment_provider_name,
  refund_order_number_actual,
  user_name,
  product_name,
  rental_type,
  start_date_original,
  end_date_original,
  start_date_n,
  end_date_n,
  start_date,
  end_date,
  location_name,
  site_name,
  tax_counties,
  ROUND(COALESCE(line_item_sub_total,0.00)::numeric, 2) AS line_item_sub_total,
  coupon_code,
  ROUND(COALESCE(coupon_discount,0.00)::numeric*-1, 2) AS coupon_discount,
  ROUND(COALESCE(discount,0.00)::numeric*-1, 2) AS discount,
  ROUND(COALESCE(tip,0.00)::numeric, 2) AS tip,

  ROUND((
  		(COALESCE(line_item_sub_total,0.00))
		+ (COALESCE(coupon_discount,0.00)::numeric*-1)
		+ (COALESCE(discount,0.00)::numeric*-1))::numeric,2)  AS final_line_item_sub_total,

  line_item_booking_fee,
  create_line_item_processing_fee,
  tax_percentage,
  sales_tax,
  delivery_fee,
  partner_name,
  
  COALESCE(
    ROUND(
        tip::numeric
        + ((COALESCE(line_item_sub_total,0.00))
			+ (COALESCE(coupon_discount,0.00)::numeric*-1)
			+ (COALESCE(discount,0.00)::numeric*-1))::numeric
		
        + line_item_booking_fee::numeric
        + sales_tax::numeric
        + delivery_fee::numeric
        - (create_line_item_processing_fee)::numeric,
    2), 0.00) AS total_collected,
  
  COALESCE(partner_id::text, '') AS partner_id,
  order_id_original,
  sum_total_refund_amount,
  sum_refunded_processing_fee,
  refunded_total_item,
  order_booking_fee,
  processing_fee,
  refunded_processing_fee,
  actual_amount_items,
  total_order_value

FROM transaction_report_sch.payment_rows_temp;

-- CHECK

SELECT * FROM transaction_report_sch.payment_rows WHERE order_item_id = '56826b3c-a00c-42f5-a86e-4790b494dd2a';
SELECT DISTINCT  * FROM transaction_report_sch.payment_rows WHERE reservation_code = 'LDV0014809' ORDER BY order_item_id;
SELECT * FROM transaction_report_sch.payment_rows WHERE reservation_code = 'LDV0014980' ORDER BY order_item_id;
SELECT * FROM transaction_report_sch.payment_rows WHERE reservation_code = 'LDV0014977' ORDER BY order_item_id;

---------------------------------------------------------------------------------------------------
-- STEP 1.6: Refund_report_raw (round & label, all text blanks)
---------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS transaction_report_sch.orders_item_history_agg;

CREATE TABLE transaction_report_sch.orders_item_history_agg AS
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
    "PaymentProcessingFee"                     AS refunded_processing_fee,
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

SELECT * FROM transaction_report_sch.orders_item_history_s
 WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404' ORDER BY order_item_id;

--Final Refund Table

DROP TABLE IF EXISTS transaction_report_sch.refund_rows;

CREATE TABLE transaction_report_sch.refund_rows AS
SELECT
  p.reservation_code,
  p.order_number,
  p.order_item_id,

  p.original_order_date,
  
  TO_CHAR(oih.transaction_date_oih   AT TIME ZONE 'America/Chicago', 'MM/DD/YYYY') AS transaction_date,
  TO_CHAR(oih.transaction_date_oih   AT TIME ZONE 'America/Chicago','HH12:MI:SS AM') AS timestamp,
  
  TO_CHAR((oih.transaction_date_oih   AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'MM/DD/YYYY') AS transaction_date_ist,
  TO_CHAR((oih.transaction_date_oih   AT TIME ZONE 'IST')  AT TIME ZONE 'America/Chicago','HH12:MI:SS AM') AS timestamp_ist,
  
  p.original_line_item_amount,
  p.payment_source,
  'Refund' AS transaction_type, 

  p.payment_type,
  p.payment_provider_name,
  oh."RefundOrderNumber" AS refund_order_number_actual,
  
  p.user_name,
  
  p.product_name,
  p.rental_type,
  
  p.start_date,
  p.end_date,
  
  p.location_name,
  p.site_name,
   ''												   AS tax_counties,
  ROUND(oih.refunded_total::numeric*-1, 2)             AS line_item_sub_total,
  p.coupon_code,
  ROUND(oih.refunded_coupon::numeric, 2)               AS coupon_discount,
  ROUND(oih.refunded_discount::numeric, 2)             AS discount,
  ROUND(oih.refunded_tip::numeric, 2)             AS tip,
  
  ROUND(
    (oih.refunded_total - oih.refunded_coupon - oih.refunded_discount)::numeric * -1, 2
  )                                           AS final_line_item_sub_total,

  oih.refunded_booking_fee AS line_item_booking_fee,

  ROUND(
    (p.sum_refunded_processing_fee * p.refunded_total_item / NULLIF(p.sum_total_refund_amount, 0))::numeric *-1,
    2
  )                                           AS create_line_item_processing_fee,

  p.tax_percentage,
  oih.refunded_sales_tax *-1 AS sales_tax,
  p.delivery_fee,

COALESCE(
    ROUND(
        COALESCE(oih.refunded_tip * -1, 0)::numeric
      + ((oih.refunded_total - oih.refunded_coupon - oih.refunded_discount)::numeric * -1)::numeric
      + COALESCE(oih.refunded_booking_fee, 0)::numeric
      + COALESCE(oih.refunded_sales_tax * -1, 0)::numeric
      + COALESCE(delivery_fee, 0)::numeric
      - COALESCE(
          (p.sum_refunded_processing_fee * p.refunded_total_item / NULLIF(p.sum_total_refund_amount, 0)) * -1,
          0
        )::numeric
    , 2)
, 0.00) AS total_collected,


  p.partner_name,
  p.partner_id,

  p.order_booking_fee,
  p.processing_fee,
  p.refunded_processing_fee,
  p.actual_amount_items,
  p.total_order_value,
  p.order_id_original,
  sum_total_refund_amount,
  sum_refunded_processing_fee,
  p.refunded_total_item

FROM transaction_report_sch.payment_rows p
LEFT JOIN public."OrderHistory" oh ON oh."OrderId" = p.order_id_original
INNER JOIN transaction_report_sch.orders_item_history_agg oih ON oih.order_item_id = p.order_item_id;


 SELECT DISTINCT * FROM transaction_report_sch.refund_rows
 WHERE order_number = 100000005009 ORDER BY order_item_id;

/* Union of payments and refunds */
DROP TABLE IF EXISTS transaction_report_sch.transaction_report_raw;
CREATE TABLE transaction_report_sch.transaction_report_raw AS

-- 1) payment rows
SELECT
  reservation_code::text,
  order_number::text,
  order_item_id::text,
  original_order_date,
  transaction_date,
  timestamp,
  original_line_item_amount,
  payment_source::text,
  transaction_type::text,
  --refund_amount::numeric,
  payment_type::text,
  payment_provider_name::text,
  refund_order_number_actual::text,
  user_name::text,
  product_name::text,
  rental_type::text,
  start_date,
  end_date,
  location_name::text,
  site_name::text,
  line_item_sub_total::numeric,
  coupon_code::text,
  coupon_discount::numeric,
  discount::numeric,
  tip::numeric,
  final_line_item_sub_total::numeric,
  line_item_booking_fee::numeric,
  create_line_item_processing_fee::numeric,
  tax_percentage::numeric,
  sales_tax::numeric,
  delivery_fee::numeric,
  total_collected::numeric,
  partner_name::text,
  partner_id::text,
  order_id_original::text

FROM transaction_report_sch.payment_rows

UNION ALL

-- 2) refund rows
SELECT
   reservation_code::text,
  order_number::text,
  order_item_id::text,
  original_order_date,
  transaction_date,
  timestamp,
  original_line_item_amount,
  payment_source::text,
  transaction_type::text,
  --refund_amount::numeric,
  payment_type::text,
  payment_provider_name::text,
  refund_order_number_actual::text,
  user_name::text,
  product_name::text,
  rental_type::text,
  start_date,
  end_date,
  location_name::text,
  site_name::text,
  line_item_sub_total::numeric,
  coupon_code::text,
  coupon_discount::numeric,
  discount::numeric,
  tip::numeric,
  final_line_item_sub_total::numeric,
  line_item_booking_fee::numeric,
  create_line_item_processing_fee::numeric,
  tax_percentage::numeric,
  sales_tax::numeric,
  delivery_fee::numeric,
  total_collected::numeric,
  partner_name::text,
  partner_id::text,
  order_id_original::text

FROM transaction_report_sch.refund_rows;

---------------------------------------------------------------------------------------------------
-- STEP 1.6: transaction_report_final (round & label, blanks for NULLs)
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS transaction_report_sch.transaction_report_final;
CREATE TABLE transaction_report_sch.transaction_report_final AS
SELECT
  COALESCE(reservation_code,     '')                             AS "RID",
  COALESCE(order_number::text,   '')                             AS "Order Id",
  COALESCE(order_item_id,        '')                             AS "Line Item Id",
  COALESCE(original_order_date,  '')                             AS "Original Order Date",
  COALESCE(transaction_date,     '')                             AS "Transaction Date",
  COALESCE(timestamp,     '')                             		 AS "Time Stamp",
  COALESCE(original_line_item_amount::text, '') 				 AS "Original Line Item Amount",
  COALESCE(payment_source,       '')                             AS "Order Type",
  transaction_type												 AS "Transaction Type",
  COALESCE(payment_type,         '')                             AS "Payment Method",
  COALESCE(payment_provider_name,'')                             AS "Payment Processor",
  refund_order_number_actual									 AS "Refund Order ID",
  COALESCE(user_name,            '')                             AS "User",
  COALESCE(product_name,         '')                             AS "Product Name",
  COALESCE(rental_type,          '')                             AS "Rental Type",
  COALESCE(start_date,           '')                             AS "Rental Start Date",
  COALESCE(end_date,             '')                             AS "Rental End Date",
  COALESCE(location_name,        '')                             AS "Location",
  COALESCE(site_name,            '')                             AS "Subsite Location",
    ''												   			 AS "Tax Counties",
  COALESCE(line_item_sub_total::text, '')                        AS "Line Item Sub Amount",
  COALESCE(coupon_code,          '')                             AS "Promo Code ID",
  COALESCE(coupon_discount::text,'')                             AS "Coupon Amount",
  COALESCE(discount::text,       '')                             AS "Line Item Discount",
  COALESCE(tip::text,            '')                             AS "Gratuity",
  COALESCE(final_line_item_sub_total::text,'')                   AS "Final Line Item Sub Total",
  COALESCE(line_item_booking_fee::text, '')                      AS "Booking Fee",
  COALESCE(create_line_item_processing_fee::text, '')                             AS "Processing Fees",
    tax_percentage										 AS "Tax %",
  COALESCE(sales_tax::text,      '')                             AS "Tax",
											
  COALESCE(delivery_fee::text,   '')                             AS "Delivery Fee",
  COALESCE(total_collected::text,'')                             AS "Total Collected",
  --COALESCE(refund_amount::text,  '')                             AS "Refund Amount",
  COALESCE(partner_name,         '')                             AS "Partner Name",
  COALESCE(partner_id,           '')                             AS "Partner ID"
FROM transaction_report_sch.transaction_report_raw;


-- final validation

SELECT DISTINCT * FROM transaction_report_sch.transaction_report_final WHERE "RID" = 'LDV0014976' ORDER BY "Line Item Id";
SELECT * FROM transaction_report_sch.transaction_report_final WHERE "RID" = 'LDV0014980' ORDER BY "Line Item Id";


SELECT DISTINCT * FROM transaction_report_sch.transaction_report_final WHERE "RID" = 'LDV0014809' ORDER BY "Line Item Id";
SELECT * FROM transaction_report_sch.transaction_report_final WHERE "RID" = 'LDV0014980' ORDER BY "Line Item Id";

SELECT * FROM transaction_report_sch.transaction_report_final ORDER BY "Line Item Id";
SELECT count(DISTINCT "Order Id") FROM transaction_report_sch.transaction_report_final;

---------------------------------------------------------------------------------------------------
-- STEP 1.7: Selective order_numbers for testing
---------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS transaction_report_sch.expected_order_ids;
CREATE TABLE transaction_report_sch.expected_order_ids (order_number BIGINT);

INSERT INTO transaction_report_sch.expected_order_ids (order_number)
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

DROP TABLE IF EXISTS transaction_report_sch.transaction_report_g;
CREATE TABLE transaction_report_sch.transaction_report_g AS
SELECT f.*
FROM transaction_report_sch.transaction_report_final f
JOIN transaction_report_sch.expected_order_ids e
  ON f."Order Id"::BIGINT = e.order_number;

-- CHECK
SELECT count(DISTINCT "Order Id") FROM transaction_report_sch.transaction_report_g;
SELECT count(*) FROM transaction_report_sch.transaction_report_g;

SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014809' ORDER BY "Line Item Id";
SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014809' and "Refund Order ID" IS NOT NULL ORDER BY "Line Item Id";
SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014809' and "Refund Order ID" IS NULL ORDER BY "Line Item Id";


SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014980' and "Refund Order ID" IS NOT NULL ORDER BY "Line Item Id";
SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014980' and "Refund Order ID" IS NULL ORDER BY "Line Item Id";

SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014977' and "Refund Order ID" IS NOT NULL ORDER BY "Line Item Id";
SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014977' and "Refund Order ID" IS NULL ORDER BY "Line Item Id";

SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014828' and "Refund Order ID" IS NOT NULL ORDER BY "Line Item Id";
SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014828' and "Refund Order ID" IS NULL ORDER BY "Line Item Id";

SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014966' and "Refund Order ID" IS NOT NULL ORDER BY "Line Item Id";
SELECT DISTINCT * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014966' and "Refund Order ID" IS NULL ORDER BY "Line Item Id";


SELECT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014919' ORDER BY "Line Item Id";
SELECT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014976' ORDER BY "Line Item Id";

--Other Tests

SELECT * FROM public."Orders" WHERE "OrderNumber" = 100000005181;
SELECT * FROM public."Users" WHERE "Id" = 'e9b660a7-806b-4725-93ab-4367a083ec0b';
SELECT * FROM public."OrderItemsHistory" WHERE "OrderId" = 'f69d3ce4-aec3-4c3a-bcc7-3876f4443d6c' ORDER BY "OrderItemId";

SELECT * FROM public."OrderItems" WHERE "OrderId" = '977f485c-02c8-4f59-a03d-ad1feb371889' ORDER BY "Id";
