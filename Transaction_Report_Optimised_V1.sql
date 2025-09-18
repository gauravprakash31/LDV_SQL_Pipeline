-- Optimized Transaction Report Generation
-- Creates transaction_report_pre_dc directly without intermediate tables

CREATE EXTENSION IF NOT EXISTS tablefunc;
DROP SCHEMA IF EXISTS transaction_report_sch CASCADE;
CREATE SCHEMA transaction_report_sch;

DROP TABLE IF EXISTS transaction_report_sch.transaction_report_pre_dc;

CREATE TABLE transaction_report_sch.transaction_report_pre_dc AS
WITH 
-- CTE 1: Refunded items aggregation
refunded_items AS (
    SELECT
        "OrderItemId" AS order_item_id,
        "OrderId" AS order_id,
        "TotalAmount" AS earliest_total_amount,
        "CreatedOn" AS transaction_date_oih,
        "RefundedTotal" AS refunded_total,
        "RefundedTotalAmount" AS refunded_total_item,
        "RefundedCouponDiscount" AS refunded_coupon,
        "RefundedTip" AS refunded_tip,
        "RefundedDiscount" AS refunded_discount,
        "RefundedBookingFee" AS refunded_booking_fee,
        "RefundedSalesTax" AS refunded_sales_tax,
		"RefundedDeliveryFee" AS refunded_delivery_fee,
        "Discount" AS discount_oih,
        "Total" AS total_oih,
        "SalesTax" AS sales_tax_oih,
        "BookingFee" AS booking_fee_oih,
        "DeliveryFee" AS delivery_fee_oih,
        "Tip" AS tip_oih,
        "CouponDiscount" AS coupon_discount_oih,
        SUM("RefundedTotalAmount") OVER (PARTITION BY "OrderItemId") AS sum_refunded_total_item,
        ROW_NUMBER() OVER (PARTITION BY "OrderItemId" ORDER BY "CreatedOn" ASC) AS rn
    FROM public."OrderItemsHistory"
    WHERE "RefundedTotalAmount" > 0
),

-- CTE 2: Payment refund aggregation
payment_refunds AS (
    SELECT
        pt."Id" AS payment_transaction_id,
        SUM(pr."Amount")::numeric AS sum_total_refund_amount,
        SUM(pr."RefundedProcessingFee")::numeric AS sum_refunded_processing_fee
    FROM public."PaymentTransactions" pt
    JOIN public."PaymentRefund" pr ON pr."PaymentTransactionId" = pt."Id"
    GROUP BY pt."Id"
),

-- CTE 3: Order coupons aggregation
order_coupons AS (
    SELECT
        oc."OrderItemId" AS order_item_id,
        STRING_AGG(c."CouponCode", ',' ORDER BY c."CouponCode") AS coupon_code
    FROM public."OrderCoupons" oc
    JOIN public."Coupons" c ON c."Id" = oc."CouponId"
    GROUP BY oc."OrderItemId"
),

-- CTE 4: Core order data with all joins
core_data AS (
    SELECT
        -- Core identifiers
        o."Id" AS order_id,
        oi."Id" AS order_item_id,
        o."ReservationId" AS reservation_id,
        o."PaymentTransactionId" AS payment_transaction_id,
        o."CreatedBy" AS created_by,
        o."OrderNumber" AS order_number,
        r."ReservationCode" AS reservation_code,
        
        -- Financial data
        oi."TotalAmount" AS original_line_item_amount,
        o."BookingFee" AS order_booking_fee,
        oi."DeliveryFee" AS delivery_fee,
        o."Total" AS total,
        oi."CouponDiscount" AS coupon_discount,
        oi."Tip" AS tip,
        oi."Discount" AS discount,
        oi."SalesTax" AS sales_tax,
        oi."Total" AS total_items,
        oi."BookingFee" AS line_item_booking_fee,
        
        -- Product and location data
        oi."ProductId" AS product_id,
        oi."LocationId" AS location_id,
        oi."SiteId" AS site_id,
        oi."RentalTypeId" AS rental_type_id,
        oi."PartnerId" AS partner_id,
        
        -- Dates
        oi."CreatedOn" AS created_on_items,
        oi."StartDate" AS start_date,
        oi."EndDate" AS end_date,
        
        -- Refund status
        CASE
            WHEN COALESCE(ri.sum_refunded_total_item, 0.00) > 0 THEN TRUE
            ELSE oi."IsRefunded"
        END AS is_refunded,
        
        -- Actual amount calculation
        CASE
            WHEN COALESCE(ri.sum_refunded_total_item, 0.00) > 0 THEN ri.earliest_total_amount
            ELSE oi."TotalAmount"
        END AS actual_amount_items,
        
        -- Enriched data
        p."Name" AS product_name,
        l."Name" AS location_name,
        site."Name" AS site_name,
        CONCAT(u."FirstName", ' ', u."LastName") AS user_name,
        pa."Name" AS partner_name,
        rt."Name" AS rental_type,
        COALESCE(site."TaxRate", l."TaxRate")::numeric AS tax_percentage,
        
        -- Payment data
        pt."Amount" AS original_amount,
        pt."ProcessingFee" AS processing_fee,
        pt."Source" AS payment_source,
        pt."PaymentType" AS payment_type,
        COALESCE(pt."PaymentProviderName", '') AS payment_provider_name,
        
        -- Refund aggregations
        COALESCE(prf.sum_total_refund_amount, 0.00) AS sum_total_refund_amount,
        COALESCE(prf.sum_refunded_processing_fee, 0.00) AS sum_refunded_processing_fee,
        COALESCE(ri.sum_refunded_total_item, 0.00) AS sum_refunded_total_item,
        
        -- Coupon data
        COALESCE(oc.coupon_code, '') AS coupon_code,
        
        -- Refund item history data (for refund rows)
        ri.transaction_date_oih,
        ri.earliest_total_amount,
        ri.refunded_total,
        ri.refunded_total_item,
        ri.refunded_coupon,
        ri.refunded_tip,
        ri.refunded_discount,
        ri.refunded_booking_fee,
        ri.refunded_sales_tax,
        ri.discount_oih,
        ri.total_oih,
        ri.sales_tax_oih,
        ri.booking_fee_oih,
        ri.delivery_fee_oih,
        ri.tip_oih,
        ri.coupon_discount_oih,
        
        -- Order history for refund order number
        oh."RefundOrderNumber" AS refund_order_number
        
    FROM public."Orders" o
    LEFT JOIN public."Reservations" r ON r."Id" = o."ReservationId"
    LEFT JOIN public."OrderItems" oi ON oi."OrderId" = o."Id"
    LEFT JOIN refunded_items ri ON ri.order_item_id = oi."Id" AND ri.rn = 1
    LEFT JOIN public."RentalTypes" rt ON rt."Id" = oi."RentalTypeId"
    LEFT JOIN public."Products" p ON p."Id" = oi."ProductId"
    LEFT JOIN public."Locations" l ON l."Id" = oi."LocationId"
    LEFT JOIN public."Locations" site ON site."Id" = oi."SiteId"
    LEFT JOIN public."Users" u ON u."Id" = o."CreatedBy"
    LEFT JOIN public."Partners" pa ON pa."Id" = oi."PartnerId"
    LEFT JOIN public."PaymentTransactions" pt ON pt."Id" = o."PaymentTransactionId"
    LEFT JOIN payment_refunds prf ON prf.payment_transaction_id = pt."Id"
    LEFT JOIN order_coupons oc ON oc.order_item_id = oi."Id"
    LEFT JOIN public."OrderHistory" oh ON oh."OrderId" = o."Id"
    
    WHERE NOT (oi."ParentOrderItemId" IS NULL AND oi."IsALaCarte" = true)
),

-- CTE 5: Payment rows
payment_rows AS (
    SELECT DISTINCT
        reservation_code,
        order_number,
        order_item_id,
        TO_CHAR(created_on_items AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS original_order_date,
        TO_CHAR(created_on_items AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS transaction_date,
        TO_CHAR(created_on_items AT TIME ZONE 'America/Chicago', 'HH12:MI:SS AM') AS timestamp,
        ROUND(actual_amount_items::numeric, 2) AS original_line_item_amount,
        COALESCE(payment_source, '') AS payment_source,
        'Payment' AS transaction_type,
        COALESCE(payment_type, '') AS payment_type,
        COALESCE(payment_provider_name, '') AS payment_provider_name,
        0::numeric AS refund_order_number_actual,
        CASE
            WHEN payment_source = 'Consumer Web' THEN ''
            ELSE COALESCE(user_name, '')
        END AS user_name,
        COALESCE(product_name, '') AS product_name,
        rental_type,
        TO_CHAR((start_date AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS start_date,
        TO_CHAR((end_date AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS end_date,
        COALESCE(location_name, '') AS location_name,
        COALESCE(site_name, '') AS site_name,
        
        -- Financial calculations for payments
        CASE
            WHEN sum_refunded_total_item = 0 THEN total_items
            ELSE total_oih
        END AS line_item_sub_total,
        
        COALESCE(coupon_code, '') AS coupon_code,
        
        CASE
            WHEN sum_refunded_total_item = 0 THEN coupon_discount
            ELSE coupon_discount_oih
        END AS coupon_discount,
        
        CASE
            WHEN sum_refunded_total_item = 0 THEN discount
            ELSE discount_oih
        END AS discount,
        
        CASE
            WHEN sum_refunded_total_item = 0 THEN tip
            ELSE tip_oih
        END AS tip,
        
        CASE
            WHEN sum_refunded_total_item = 0 THEN line_item_booking_fee
            ELSE booking_fee_oih
        END AS line_item_booking_fee,
        
        COALESCE(
            ROUND((processing_fee * actual_amount_items / NULLIF(original_amount, 0))::numeric, 2),
            0.00
        ) AS create_line_item_processing_fee,
        
        ROUND(tax_percentage::numeric, 2) AS tax_percentage,
        
        CASE
            WHEN sum_refunded_total_item = 0 THEN sales_tax
            ELSE sales_tax_oih
        END AS sales_tax,
        
        CASE
            WHEN sum_refunded_total_item = 0 THEN delivery_fee
            ELSE delivery_fee_oih
        END AS delivery_fee,
        
        COALESCE(partner_name, '') AS partner_name,
        CASE
            WHEN partner_id = 0 THEN ''
            ELSE COALESCE(partner_id::text, '')
        END AS partner_id,
        
        order_id AS order_id_original
        
    FROM core_data
    WHERE payment_transaction_id IS NOT NULL
),

-- CTE 6: Payment rows with final calculations
payment_rows_final AS (
    SELECT 
        reservation_code,
        order_number,
        order_item_id,
        original_order_date,
        transaction_date,
        timestamp,
        original_line_item_amount,
        payment_source,
        transaction_type,
        payment_type,
        payment_provider_name,
        refund_order_number_actual,
        user_name,
        product_name,
        rental_type,
        start_date,
        end_date,
        location_name,
        site_name,
        line_item_sub_total,
        coupon_code,
        coupon_discount,
        discount,
        tip,
        ROUND((line_item_sub_total + (coupon_discount * -1) + (discount * -1))::numeric, 2) AS final_line_item_sub_total,
        line_item_booking_fee,
        create_line_item_processing_fee,
        tax_percentage,
        sales_tax,
        delivery_fee,
        partner_name,
        partner_id,
        order_id_original,
        COALESCE(
            ROUND(
                COALESCE(tip, 0.00)::numeric +
                (line_item_sub_total + (coupon_discount * -1) + (discount * -1))::numeric +
                COALESCE(line_item_booking_fee, 0.00)::numeric +
                COALESCE(sales_tax, 0.00)::numeric +
                COALESCE(delivery_fee, 0.00)::numeric -
                COALESCE(create_line_item_processing_fee, 0.00)::numeric,
                2
            ),
            0.00
        ) AS total_collected
    FROM payment_rows
),

-- CTE 7: Refund rows
refund_rows AS (
    SELECT DISTINCT
        cd.reservation_code,
        cd.order_number,
        cd.order_item_id,
        TO_CHAR(cd.created_on_items AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS original_order_date,
        TO_CHAR(ri2.transaction_date_oih AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS transaction_date,
        TO_CHAR(ri2.transaction_date_oih AT TIME ZONE 'America/Chicago', 'HH12:MI:SS AM') AS timestamp,
        ROUND(ri2.earliest_total_amount::numeric, 2) AS original_line_item_amount,
        COALESCE(cd.payment_source, '') AS payment_source,
        'Refund' AS transaction_type,
        COALESCE(cd.payment_type, '') AS payment_type,
        COALESCE(cd.payment_provider_name, '') AS payment_provider_name,
        COALESCE(cd.refund_order_number, 0)::numeric AS refund_order_number_actual,
        CASE
            WHEN cd.payment_source = 'Consumer Web' THEN ''
            ELSE COALESCE(cd.user_name, '')
        END AS user_name,
        COALESCE(cd.product_name, '') AS product_name,
        cd.rental_type,
        TO_CHAR((cd.start_date AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS start_date,
        TO_CHAR((cd.end_date AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS end_date,
        COALESCE(cd.location_name, '') AS location_name,
        COALESCE(cd.site_name, '') AS site_name,
        
        -- Refund financial calculations
        ROUND(ri2.refunded_total::numeric * -1, 2) AS line_item_sub_total,
        COALESCE(cd.coupon_code, '') AS coupon_code,
        ROUND(ri2.refunded_coupon::numeric, 2) AS coupon_discount,
        ROUND(ri2.refunded_discount::numeric, 2) AS discount,
        ROUND(ri2.refunded_tip::numeric * -1, 2) AS tip,
        ROUND((ri2.refunded_total - ri2.refunded_coupon - ri2.refunded_discount)::numeric * -1, 2) AS final_line_item_sub_total,
        ROUND(ri2.refunded_booking_fee::numeric * -1, 2) AS line_item_booking_fee,
        ROUND(
            COALESCE(
                (cd.sum_refunded_processing_fee * ri2.refunded_total_item / NULLIF(cd.sum_total_refund_amount, 0))::numeric * -1,
                0.00
            ), 2
        ) AS create_line_item_processing_fee,
        ROUND(cd.tax_percentage::numeric, 2) AS tax_percentage,
        ROUND(ri2.refunded_sales_tax::numeric * -1, 2) AS sales_tax,
        COALESCE(ri2.refunded_delivery_fee, 0.00) AS delivery_fee,
        COALESCE(cd.partner_name, '') AS partner_name,
        CASE
            WHEN cd.partner_id = 0 THEN ''
            ELSE COALESCE(cd.partner_id::text, '')
        END AS partner_id,
        cd.order_id AS order_id_original,
        
        -- Total collected calculation for refunds
        COALESCE(
            ROUND(
                COALESCE(ri2.refunded_tip * -1, 0.00)::numeric +
                ((ri2.refunded_total - ri2.refunded_coupon - ri2.refunded_discount)::numeric * -1) +
                COALESCE(ri2.refunded_booking_fee * -1, 0.00)::numeric +
                COALESCE(ri2.refunded_sales_tax * -1, 0.00)::numeric +
                COALESCE(ri2.refunded_delivery_fee, 0.00)::numeric -
                COALESCE(
                    (cd.sum_refunded_processing_fee * ri2.refunded_total_item / NULLIF(cd.sum_total_refund_amount, 0)) * -1,
                    0
                )::numeric,
                2
            ),
            0.00
        ) AS total_collected
        
    FROM core_data cd
    INNER JOIN refunded_items ri2 ON ri2.order_item_id = cd.order_item_id
    WHERE cd.sum_refunded_total_item > 0
),

-- CTE 8: Union all transactions
all_transactions AS (
    SELECT * FROM payment_rows_final
    UNION ALL
    SELECT * FROM refund_rows
)

-- Final SELECT with proper column naming
SELECT
    COALESCE(reservation_code, '') AS "RID",
    COALESCE(order_number::text, '') AS "Order Id",
    COALESCE(order_item_id::text, '') AS "Line Item ID",
    COALESCE(original_order_date, '') AS "Original Order Date",
    COALESCE(transaction_date, '') AS "Transaction Date",
    COALESCE(timestamp, '') AS "Time Stamp",
    ROUND(COALESCE(original_line_item_amount, 0.00)::numeric, 2) AS "Original Line Item Amount",
    COALESCE(payment_source, '') AS "Order Type",
    transaction_type AS "Transaction Type",
    COALESCE(payment_type, '') AS "Payment Method",
    COALESCE(payment_provider_name, '') AS "Payment Processer",
    COALESCE(refund_order_number_actual, 0) AS "Refund Order ID",
    COALESCE(user_name, '') AS "User",
    COALESCE(product_name, '') AS "Product Name",
    COALESCE(rental_type, '') AS "Rental Type",
    COALESCE(start_date, '') AS "Rental Start Date",
    COALESCE(end_date, '') AS "Rental End Date",
    COALESCE(location_name, '') AS "Location",
    COALESCE(site_name, '') AS "Subsite Location",
    ROUND(COALESCE(line_item_sub_total, 0.00)::numeric, 2) AS "Line Item Sub Total",
    COALESCE(coupon_code, '') AS "Promo Code ID",
    ROUND(COALESCE(coupon_discount * -1, 0.00)::numeric, 2) AS "Coupon Amount",
    ROUND(COALESCE(discount * -1, 0.00)::numeric, 2) AS "Line Item Discount",
    ROUND(COALESCE(tip, 0.00)::numeric, 2) AS "Gratuity",
    ROUND(COALESCE(final_line_item_sub_total, 0.00)::numeric, 2) AS "Final Line Item Sub Total",
    ROUND(COALESCE(line_item_booking_fee, 0.00)::numeric, 2) AS "Booking Fee",
    ROUND(COALESCE(create_line_item_processing_fee, 0.00)::numeric, 2) AS "Processing Fees",
    ROUND(COALESCE(tax_percentage, 0.00)::numeric, 2) AS "Tax %",
    ROUND(COALESCE(sales_tax, 0.00)::numeric, 2) AS "Tax",
    ROUND(COALESCE(delivery_fee, 0.00)::numeric, 2) AS "Delivery Fee",
    ROUND(COALESCE(total_collected, 0.00)::numeric, 2) AS "Total Collected",
    COALESCE(partner_name, '') AS "Partner Name",
    COALESCE(partner_id, '') AS "Partner ID",
    order_id_original::uuid AS order_id_original

FROM all_transactions;

SELECT * FROM transaction_report_sch.transaction_report_pre_dc WHERE "RID" = 'LDV0014976' and "Refund Order ID" =0 ORDER BY "Line Item ID";
SELECT * FROM transaction_report_sch.transaction_report_pre_dc WHERE "RID" = 'LDV0014976' and "Refund Order ID" !=0 ORDER BY "Line Item ID";

SELECT DISTINCT * FROM transaction_report_sch.transaction_report_pre_dc WHERE "RID" = 'LDV0014809' and "Refund Order ID" =0 ORDER BY "Line Item ID";
SELECT DISTINCT * FROM transaction_report_sch.transaction_report_pre_dc WHERE "RID" = 'LDV0014809' and "Refund Order ID" != 0 ORDER BY "Line Item ID";

SELECT DISTINCT * FROM transaction_report_sch.transaction_report_pre_dc WHERE "RID" = 'LDV0014809' ORDER BY "Line Item ID";
SELECT * FROM transaction_report_sch.transaction_report_pre_dc WHERE "RID" = 'LDV0014980' ORDER BY "Line Item ID";

SELECT * FROM transaction_report_sch.transaction_report_pre_dc ORDER BY "Line Item ID";
SELECT count(DISTINCT "Order Id") FROM transaction_report_sch.transaction_report_pre_dc;



--------------------------------------------------------------------------------
-- DYNAMIC CONTROLS - SIMPLIFIED VERSION
--------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS tablefunc;

--------------------------------------------------------------------------------
-- 1) Create Order Controls (Dynamic Pivot)
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.order_controls;

DO $do$
DECLARE
  col_defs TEXT;
  cat_list TEXT;
  dyn_sql  TEXT;
  rec_count INT;
BEGIN
  -- Check if there's data for order controls
  WITH dc_orders AS (
    SELECT
      odcv."OrderId"::text AS order_id,
      odc."DisplayName" AS control_name,
      odco."Option" AS control_value,
      odc."ShowInExport" AS show_in_export
    FROM public."OrderDynamicControlValues" odcv
    LEFT JOIN public."OrderDynamicControlOptions" odco ON odcv."DynamicControlOptionId" = odco."Id"
    LEFT JOIN public."OrderDynamicControls" odc ON odco."DynamicControlId" = odc."Id"
    WHERE odc."ShowInExport" = true
  )
  SELECT COUNT(*) INTO rec_count FROM dc_orders;

  IF rec_count = 0 THEN
    RAISE NOTICE 'No data in order controls — creating empty table.';
    CREATE TABLE order_report_sch.order_controls (
      order_id UUID
    );
  ELSE
    -- Build category list and column definitions from aggregated data
    WITH dc_orders AS (
      SELECT
        odcv."OrderId"::text AS order_id,
        odc."DisplayName" AS control_name,
        odco."Option" AS control_value
      FROM public."OrderDynamicControlValues" odcv
      LEFT JOIN public."OrderDynamicControlOptions" odco ON odcv."DynamicControlOptionId" = odco."Id"
      LEFT JOIN public."OrderDynamicControls" odc ON odco."DynamicControlId" = odc."Id"
      WHERE odc."ShowInExport" = true
    ),
    dc_orders_agg AS (
      SELECT
        order_id,
        control_name,
        STRING_AGG(control_value, ', ' ORDER BY control_value) AS control_value
      FROM dc_orders
      GROUP BY order_id, control_name
    ),
    distinct_controls AS (
      SELECT DISTINCT control_name
      FROM dc_orders_agg
    )
    SELECT 
      string_agg(quote_literal(control_name), ',' ORDER BY control_name),
      string_agg(format('%I TEXT', replace(control_name,'"','')), ', ' ORDER BY control_name)
    INTO cat_list, col_defs
    FROM distinct_controls;

    -- Create temporary table for crosstab source
    CREATE TEMP TABLE temp_dc_orders_agg AS
    WITH dc_orders AS (
      SELECT
        odcv."OrderId"::text AS order_id,
        odc."DisplayName" AS control_name,
        odco."Option" AS control_value
      FROM public."OrderDynamicControlValues" odcv
      LEFT JOIN public."OrderDynamicControlOptions" odco ON odcv."DynamicControlOptionId" = odco."Id"
      LEFT JOIN public."OrderDynamicControls" odc ON odco."DynamicControlId" = odc."Id"
      WHERE odc."ShowInExport" = true
    )
    SELECT
      order_id,
      control_name,
      STRING_AGG(control_value, ', ' ORDER BY control_value) AS control_value
    FROM dc_orders
    GROUP BY order_id, control_name;

    -- Build and execute pivot
    dyn_sql := format(
      'CREATE TABLE order_report_sch.order_controls AS
       SELECT *
       FROM crosstab(
         $$SELECT order_id, control_name, control_value
           FROM temp_dc_orders_agg
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
    DROP TABLE temp_dc_orders_agg;
  END IF;
END
$do$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- 2) Create Product Controls (Dynamic Pivot)
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.product_controls;

DO $do$
DECLARE
  col_defs TEXT;
  cat_list TEXT;
  dyn_sql  TEXT;
  rec_count INT;
BEGIN
  -- Check if there's data for product controls
  WITH product_controls_src AS (
    -- Item level controls
    SELECT
      oi."Id"::text AS order_item_id_p,
      pdc."DisplayName" AS control_name,
      pdco."Option" AS control_value
    FROM public."OrderItemDynamicControls" oidc
    JOIN public."OrderItems" oi ON oidc."OrderItemId" = oi."Id"
    JOIN public."ProductDynamicControlOptions" pdco ON oidc."DynamicControlOptionId" = pdco."Id"
    JOIN public."ProductDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
    WHERE oidc."DynamicControlType" = 0 AND pdc."ShowInExport" = true
    
    UNION ALL
    
    -- Product level controls (only if no item level exists)
    SELECT
      oi."Id"::text AS order_item_id_p,
      pdc."DisplayName" AS control_name,
      pdco."Option" AS control_value
    FROM public."ProductDynamicControlValues" pdcv
    JOIN public."ProductDynamicControlOptions" pdco ON pdcv."DynamicControlOptionId" = pdco."Id"
    JOIN public."ProductDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
    JOIN public."OrderItems" oi ON pdcv."ProductId" = oi."ProductId"
    WHERE pdc."ShowInExport" = true AND pdcv."IsDeleted" = false
    AND NOT EXISTS (
      SELECT 1
      FROM public."OrderItemDynamicControls" oidc2
      JOIN public."ProductDynamicControlOptions" pdco2 ON oidc2."DynamicControlOptionId" = pdco2."Id"
      JOIN public."ProductDynamicControls" pdc2 ON pdco2."DynamicControlId" = pdc2."Id"
      WHERE oidc2."OrderItemId" = oi."Id" AND oidc2."DynamicControlType" = 0 AND pdc2."ShowInExport" = true
    )
  )
  SELECT COUNT(*) INTO rec_count FROM product_controls_src;

  IF rec_count = 0 THEN
    CREATE TABLE order_report_sch.product_controls (
      order_item_id_p UUID
    );
  ELSE
    -- Build category list and column definitions
    WITH product_controls_src AS (
      SELECT
        oi."Id"::text AS order_item_id_p,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
      FROM public."OrderItemDynamicControls" oidc
      JOIN public."OrderItems" oi ON oidc."OrderItemId" = oi."Id"
      JOIN public."ProductDynamicControlOptions" pdco ON oidc."DynamicControlOptionId" = pdco."Id"
      JOIN public."ProductDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
      WHERE oidc."DynamicControlType" = 0 AND pdc."ShowInExport" = true
      
      UNION ALL
      
      SELECT
        oi."Id"::text AS order_item_id_p,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
      FROM public."ProductDynamicControlValues" pdcv
      JOIN public."ProductDynamicControlOptions" pdco ON pdcv."DynamicControlOptionId" = pdco."Id"
      JOIN public."ProductDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
      JOIN public."OrderItems" oi ON pdcv."ProductId" = oi."ProductId"
      WHERE pdc."ShowInExport" = true AND pdcv."IsDeleted" = false
      AND NOT EXISTS (
        SELECT 1
        FROM public."OrderItemDynamicControls" oidc2
        JOIN public."ProductDynamicControlOptions" pdco2 ON oidc2."DynamicControlOptionId" = pdco2."Id"
        JOIN public."ProductDynamicControls" pdc2 ON pdco2."DynamicControlId" = pdc2."Id"
        WHERE oidc2."OrderItemId" = oi."Id" AND oidc2."DynamicControlType" = 0 AND pdc2."ShowInExport" = true
      )
    ),
    product_controls_agg AS (
      SELECT
        order_item_id_p,
        control_name,
        STRING_AGG(control_value, ', ' ORDER BY control_value) AS control_value
      FROM product_controls_src
      GROUP BY order_item_id_p, control_name
    ),
    distinct_controls AS (
      SELECT DISTINCT control_name
      FROM product_controls_agg
    )
    SELECT 
      string_agg(quote_literal(control_name), ',' ORDER BY control_name),
      string_agg(format('%I TEXT', control_name), ', ' ORDER BY control_name)
    INTO cat_list, col_defs
    FROM distinct_controls;

    -- Create temporary table for crosstab source
    CREATE TEMP TABLE temp_product_controls_agg AS
    WITH product_controls_src AS (
      SELECT
        oi."Id"::text AS order_item_id_p,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
      FROM public."OrderItemDynamicControls" oidc
      JOIN public."OrderItems" oi ON oidc."OrderItemId" = oi."Id"
      JOIN public."ProductDynamicControlOptions" pdco ON oidc."DynamicControlOptionId" = pdco."Id"
      JOIN public."ProductDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
      WHERE oidc."DynamicControlType" = 0 AND pdc."ShowInExport" = true
      
      UNION ALL
      
      SELECT
        oi."Id"::text AS order_item_id_p,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
      FROM public."ProductDynamicControlValues" pdcv
      JOIN public."ProductDynamicControlOptions" pdco ON pdcv."DynamicControlOptionId" = pdco."Id"
      JOIN public."ProductDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
      JOIN public."OrderItems" oi ON pdcv."ProductId" = oi."ProductId"
      WHERE pdc."ShowInExport" = true AND pdcv."IsDeleted" = false
      AND NOT EXISTS (
        SELECT 1
        FROM public."OrderItemDynamicControls" oidc2
        JOIN public."ProductDynamicControlOptions" pdco2 ON oidc2."DynamicControlOptionId" = pdco2."Id"
        JOIN public."ProductDynamicControls" pdc2 ON pdco2."DynamicControlId" = pdc2."Id"
        WHERE oidc2."OrderItemId" = oi."Id" AND oidc2."DynamicControlType" = 0 AND pdc2."ShowInExport" = true
      )
    )
    SELECT
      order_item_id_p,
      control_name,
      STRING_AGG(control_value, ', ' ORDER BY control_value) AS control_value
    FROM product_controls_src
    GROUP BY order_item_id_p, control_name;

    -- Build and execute pivot
    dyn_sql := format(
      'CREATE TABLE order_report_sch.product_controls AS
       SELECT *
       FROM crosstab(
         $$SELECT order_item_id_p, control_name, control_value
           FROM temp_product_controls_agg
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
    DROP TABLE temp_product_controls_agg;
  END IF;
END
$do$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- 3) Create Location Controls (Dynamic Pivot)
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS order_report_sch.location_controls;

DO $do$
DECLARE
  col_defs TEXT;
  cat_list TEXT;
  dyn_sql  TEXT;
  rec_count INT;
BEGIN
  -- Check if there's data for location controls
  WITH location_controls_src AS (
    -- Item level controls
    SELECT
      oi."Id"::text AS order_item_id_l,
      pdc."DisplayName" AS control_name,
      pdco."Option" AS control_value
    FROM public."OrderItemDynamicControls" oidc
    JOIN public."OrderItems" oi ON oidc."OrderItemId" = oi."Id"
    JOIN public."LocationDynamicControlOptions" pdco ON oidc."DynamicControlOptionId" = pdco."Id"
    JOIN public."LocationDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
    WHERE oidc."DynamicControlType" = 1 AND pdc."ShowInExport" = true
    
    UNION ALL
    
    -- Location level controls (only if no item level exists)
    SELECT
      oi."Id"::text AS order_item_id_l,
      pdc."DisplayName" AS control_name,
      pdco."Option" AS control_value
    FROM public."LocationDynamicControlValues" pdcv
    JOIN public."LocationDynamicControlOptions" pdco ON pdcv."DynamicControlOptionId" = pdco."Id"
    JOIN public."LocationDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
    JOIN public."OrderItems" oi ON pdcv."LocationId" = oi."LocationId"
    WHERE pdc."ShowInExport" = true AND pdcv."IsDeleted" = false
    AND NOT EXISTS (
      SELECT 1
      FROM public."OrderItemDynamicControls" oidc2
      JOIN public."LocationDynamicControlOptions" pdco2 ON oidc2."DynamicControlOptionId" = pdco2."Id"
      JOIN public."LocationDynamicControls" pdc2 ON pdco2."DynamicControlId" = pdc2."Id"
      WHERE oidc2."OrderItemId" = oi."Id" AND oidc2."DynamicControlType" = 1 AND pdc2."ShowInExport" = true
    )
  )
  SELECT COUNT(*) INTO rec_count FROM location_controls_src;

  IF rec_count = 0 THEN
    RAISE NOTICE 'No data in location_controls_src — creating empty table.';
    CREATE TABLE order_report_sch.location_controls (
      order_item_id_l UUID
    );
  ELSE
    -- Build category list and column definitions
    WITH location_controls_src AS (
      SELECT
        oi."Id"::text AS order_item_id_l,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
      FROM public."OrderItemDynamicControls" oidc
      JOIN public."OrderItems" oi ON oidc."OrderItemId" = oi."Id"
      JOIN public."LocationDynamicControlOptions" pdco ON oidc."DynamicControlOptionId" = pdco."Id"
      JOIN public."LocationDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
      WHERE oidc."DynamicControlType" = 1 AND pdc."ShowInExport" = true
      
      UNION ALL
      
      SELECT
        oi."Id"::text AS order_item_id_l,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
      FROM public."LocationDynamicControlValues" pdcv
      JOIN public."LocationDynamicControlOptions" pdco ON pdcv."DynamicControlOptionId" = pdco."Id"
      JOIN public."LocationDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
      JOIN public."OrderItems" oi ON pdcv."LocationId" = oi."LocationId"
      WHERE pdc."ShowInExport" = true AND pdcv."IsDeleted" = false
      AND NOT EXISTS (
        SELECT 1
        FROM public."OrderItemDynamicControls" oidc2
        JOIN public."LocationDynamicControlOptions" pdco2 ON oidc2."DynamicControlOptionId" = pdco2."Id"
        JOIN public."LocationDynamicControls" pdc2 ON pdco2."DynamicControlId" = pdc2."Id"
        WHERE oidc2."OrderItemId" = oi."Id" AND oidc2."DynamicControlType" = 1 AND pdc2."ShowInExport" = true
      )
    ),
    location_controls_agg AS (
      SELECT
        order_item_id_l,
        control_name,
        STRING_AGG(control_value, ', ' ORDER BY control_value) AS control_value
      FROM location_controls_src
      GROUP BY order_item_id_l, control_name
    ),
    distinct_controls AS (
      SELECT DISTINCT control_name
      FROM location_controls_agg
    )
    SELECT 
      string_agg(quote_literal(control_name), ',' ORDER BY control_name),
      string_agg(format('%I TEXT', control_name), ', ' ORDER BY control_name)
    INTO cat_list, col_defs
    FROM distinct_controls;

    -- Create temporary table for crosstab source
    CREATE TEMP TABLE temp_location_controls_agg AS
    WITH location_controls_src AS (
      SELECT
        oi."Id"::text AS order_item_id_l,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
      FROM public."OrderItemDynamicControls" oidc
      JOIN public."OrderItems" oi ON oidc."OrderItemId" = oi."Id"
      JOIN public."LocationDynamicControlOptions" pdco ON oidc."DynamicControlOptionId" = pdco."Id"
      JOIN public."LocationDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
      WHERE oidc."DynamicControlType" = 1 AND pdc."ShowInExport" = true
      
      UNION ALL
      
      SELECT
        oi."Id"::text AS order_item_id_l,
        pdc."DisplayName" AS control_name,
        pdco."Option" AS control_value
      FROM public."LocationDynamicControlValues" pdcv
      JOIN public."LocationDynamicControlOptions" pdco ON pdcv."DynamicControlOptionId" = pdco."Id"
      JOIN public."LocationDynamicControls" pdc ON pdco."DynamicControlId" = pdc."Id"
      JOIN public."OrderItems" oi ON pdcv."LocationId" = oi."LocationId"
      WHERE pdc."ShowInExport" = true AND pdcv."IsDeleted" = false
      AND NOT EXISTS (
        SELECT 1
        FROM public."OrderItemDynamicControls" oidc2
        JOIN public."LocationDynamicControlOptions" pdco2 ON oidc2."DynamicControlOptionId" = pdco2."Id"
        JOIN public."LocationDynamicControls" pdc2 ON pdco2."DynamicControlId" = pdc2."Id"
        WHERE oidc2."OrderItemId" = oi."Id" AND oidc2."DynamicControlType" = 1 AND pdc2."ShowInExport" = true
      )
    )
    SELECT
      order_item_id_l,
      control_name,
      STRING_AGG(control_value, ', ' ORDER BY control_value) AS control_value
    FROM location_controls_src
    GROUP BY order_item_id_l, control_name;

    -- Build and execute pivot
    dyn_sql := format(
      'CREATE TABLE order_report_sch.location_controls AS
       SELECT *
       FROM crosstab(
         $$SELECT order_item_id_l, control_name, control_value
           FROM temp_location_controls_agg
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
    DROP TABLE temp_location_controls_agg;
  END IF;
END
$do$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- 4) Create Final Report with Dynamic Controls
--------------------------------------------------------------------------------

DROP TABLE IF EXISTS order_report_sch.order_report_dynamic;
CREATE TABLE order_report_sch.order_report_dynamic AS
SELECT
  r.*,
  oc.*,
  -- Dynamic columns from product-level controls
  pc.*,

  -- Dynamic columns from location-level controls
  lc.*

FROM transaction_report_sch.transaction_report_pre_dc r
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
      SELECT tax_col, 19
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
    DROP TABLE IF EXISTS order_report_sch.transaction_report_final;
    CREATE TABLE order_report_sch.transaction_report_final AS
    SELECT ' || transformed_cols || '
    FROM order_report_sch.final;
  ';

  EXECUTE dyn_sql;
END $$;

SELECT DISTINCT * FROM order_report_sch.transaction_report_final WHERE "RID" = 'LDV0011671' and "Refund Order ID" = '0' ORDER BY "Line Item ID";
SELECT DISTINCT * FROM order_report_sch.transaction_report_final WHERE "RID" = 'LDV0011667' and "Refund Order ID" != '0' ORDER BY "Line Item ID";

SELECT  * FROM order_report_sch.transaction_report_final WHERE "RID" = 'LDV0015277' ORDER BY "Line Item ID" ;
SELECT  * FROM order_report_sch.transaction_report_final WHERE "RID" = 'LDV0015277' and "Refund Order ID" = '0' ORDER BY "Line Item ID";
SELECT  * FROM order_report_sch.transaction_report_final WHERE "RID" = 'LDV0015277' and "Refund Order ID" != '0' ORDER BY "Line Item ID";

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
FROM order_report_sch.transaction_report_final f
JOIN transaction_report_sch.expected_order_ids e
  ON f."Order Id"::BIGINT = e.order_number;

-- CHECK
SELECT count(DISTINCT "Order Id") FROM transaction_report_sch.transaction_report_g;
SELECT count(*) FROM transaction_report_sch.transaction_report_g;

SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014980' ORDER BY "Line Item ID" ;
SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014809' and "Refund Order ID" = '0' ORDER BY "Line Item ID";
SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014809' and "Refund Order ID" != '0' ORDER BY "Line Item ID";


SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014980' and "Refund Order ID" = '0' ORDER BY "Line Item ID";
SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014980' and "Refund Order ID" != '0' ORDER BY "Line Item ID";

SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014977' and "Refund Order ID" = '0' ORDER BY "Line Item ID";
SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014977' and "Refund Order ID" != '0' ORDER BY "Line Item ID";

SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014828' and "Refund Order ID" = '0' ORDER BY "Line Item ID";
SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014828' and "Refund Order ID" != '0' ORDER BY "Line Item ID";

SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014977' and "Refund Order ID" = '0' ORDER BY "Line Item ID";
SELECT  * FROM transaction_report_sch.transaction_report_g WHERE "RID" = 'LDV0014977' and "Refund Order ID" != '0' ORDER BY "Line Item ID";

SELECT  * FROM transaction_report_sch.transaction_report_g;
SELECT  "RID", "Line Item ID", "Refund Order ID" FROM transaction_report_sch.transaction_report_g;
SELECT  "Line Item ID", "Refund Order ID" FROM transaction_report_sch.transaction_report_g;

