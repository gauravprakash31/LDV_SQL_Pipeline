--===============================================================
-- Optimized Order Report - Single Query Approach
-- Eliminates intermediate tables for better performance and storage efficiency
-- Final output: unique order_item_id with all required fields
--===============================================================

CREATE EXTENSION IF NOT EXISTS tablefunc;

DROP SCHEMA IF EXISTS order_report_sch CASCADE;
CREATE SCHEMA order_report_sch;

-- Create final optimized report table in a single query
DROP TABLE IF EXISTS order_report_sch.order_report_pre_dc;
CREATE TABLE order_report_sch.order_report_pre_dc AS

WITH 
-- CTE 1: Aggregate refund data from OrderItemsHistory
refund_aggregates AS (
    SELECT
        "OrderItemId",
        -- Sum of all refunded amounts for this order item
        SUM("RefundedTotalAmount") AS sum_refunded_total_item,
        -- Get earliest transaction details (first refund record)
        (array_agg("TotalAmount" ORDER BY "CreatedOn" ASC))[1] AS earliest_total_amount
    FROM public."OrderItemsHistory"
    WHERE "RefundedTotalAmount" > 0
    GROUP BY "OrderItemId"
),

-- CTE 2: Aggregate payment refund data by payment transaction
payment_refunds AS (
    SELECT
        "PaymentTransactionId",
        ROUND(SUM("Amount")::numeric, 2) AS sum_total_refund_amount,
        ROUND(SUM("RefundedProcessingFee")::numeric, 2) AS sum_refunded_processing_fee
    FROM public."PaymentRefund"
    GROUP BY "PaymentTransactionId"
),

-- CTE 3: Aggregate coupon codes by order item
coupon_aggregates AS (
    SELECT
        oc."OrderItemId",
        STRING_AGG(c."CouponCode", ',' ORDER BY c."CouponCode") AS coupon_codes
    FROM public."OrderCoupons" oc
    JOIN public."Coupons" c ON c."Id" = oc."CouponId"
    GROUP BY oc."OrderItemId"
),

-- CTE 4: Main data aggregation - join all tables and calculate derived fields
main_data AS (
    SELECT
        -- Basic identifiers
        o."Id" AS order_id_original,
        oi."Id" AS order_item_id,
        o."OrderNumber" AS order_number,
        r."ReservationCode" AS reservation_code,
        
        -- Date formatting with timezone conversion (IST to Chicago)
        TO_CHAR(oi."CreatedOn" AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS created_on_items,
        TO_CHAR((oi."StartDate" AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS start_date,
        TO_CHAR((oi."EndDate" AT TIME ZONE 'IST') AT TIME ZONE 'America/Chicago', 'DD/MM/YYYY') AS end_date,
        
        -- Financial data with proper COALESCE handling
        ROUND(COALESCE(pt."Amount", 0.00)::numeric, 2) AS original_amount,
        ROUND(COALESCE(prf.sum_total_refund_amount, 0.00)::numeric, 2) AS order_level_refund,
        ROUND(COALESCE(o."Total", 0.00)::numeric, 2) AS total_order_value,
        
        -- Payment information
        COALESCE(pt."Source", '') AS payment_source,
        COALESCE(pt."PaymentType", '') AS payment_type,
        COALESCE(pt."PaymentProviderName", '') AS payment_provider_name,
        
        -- Refund status calculation
        CASE 
            WHEN COALESCE(ra.sum_refunded_total_item, 0.00) > 0 THEN 'TRUE'
            ELSE 'FALSE'
        END AS is_refunded,
        
        -- User information with conditional logic
        CASE
            WHEN COALESCE(pt."Source", '') = 'Consumer Web' THEN ''
            ELSE COALESCE(CONCAT(u."FirstName", ' ', u."LastName"), '')
        END AS user_name,
        
        -- Product and location information
        COALESCE(p."Name", '') AS product_name,
        COALESCE(l."Name", '') AS location_name,
        COALESCE(site."Name", '') AS site_name,
        
        -- Line item financial calculations
        ROUND(COALESCE(oi."Total", 0.00)::numeric, 2) AS total_items,
        COALESCE(ca.coupon_codes, '') AS coupon_code,
        ROUND(COALESCE(oi."CouponDiscount", 0.00)::numeric, 2) AS coupon_discount,
        ROUND(COALESCE(oi."Discount", 0.00)::numeric, 2) AS discount,
        ROUND(COALESCE(oi."Tip", 0.00)::numeric, 2) AS tip,
        
        -- Calculate final line item subtotal
        ROUND((COALESCE(oi."Total", 0.00) - COALESCE(oi."CouponDiscount", 0.00) - COALESCE(oi."Discount", 0.00))::numeric, 2) AS final_line_item_sub_total,
        
        -- Fees and taxes
        ROUND(COALESCE(oi."BookingFee", 0.00)::numeric, 2) AS line_item_booking_fee,
        ROUND(COALESCE(oi."DeliveryFee", 0.00)::numeric, 2) AS delivery_fee,
        ROUND(COALESCE(oi."SalesTax", 0.00)::numeric, 2) AS sales_tax,
        ROUND(COALESCE(COALESCE(site."TaxRate", l."TaxRate"), 0.00)::numeric, 2) AS tax_percentage,
        
        -- Processing fees with proration logic
        ROUND(COALESCE(pt."ProcessingFee", 0.00)::numeric, 2) AS processing_fee,
        ROUND(COALESCE(prf.sum_refunded_processing_fee, 0.00)::numeric, 2) AS refunded_processing_fee,
        
        -- Calculate actual amount (refunded vs original)
        CASE
            WHEN COALESCE(ra.sum_refunded_total_item, 0.00) > 0 THEN COALESCE(ra.earliest_total_amount, 0.00)
            ELSE COALESCE(oi."TotalAmount", 0.00)
        END AS actual_amount_items,
        
        -- Refund amounts
        COALESCE(ra.sum_refunded_total_item, 0.00) AS sum_refunded_total_item,
        
        -- Partner information
        COALESCE(pa."Name", '') AS partner_name,
        CASE
            WHEN COALESCE(oi."PartnerId", 0) = 0 THEN ''
            ELSE COALESCE(oi."PartnerId"::text, '')
        END AS partner_id,
        
        -- Store raw values for calculations
        pt."Amount" AS pt_amount,
        prf.sum_total_refund_amount AS prf_sum_total_refund_amount
        
    FROM public."OrderItems" oi
    
    -- Core joins
    INNER JOIN public."Orders" o ON o."Id" = oi."OrderId"
    LEFT JOIN public."Reservations" r ON r."Id" = o."ReservationId"
    LEFT JOIN public."PaymentTransactions" pt ON pt."OrderId" = o."PaymentTransactionId"
    
    -- Lookup tables
    LEFT JOIN public."Products" p ON p."Id" = oi."ProductId"
    LEFT JOIN public."Locations" l ON l."Id" = oi."LocationId"
    LEFT JOIN public."Locations" site ON site."Id" = oi."SiteId"
    LEFT JOIN public."Users" u ON u."Id" = o."CreatedBy"
    LEFT JOIN public."Partners" pa ON pa."Id" = oi."PartnerId"
    
    -- Aggregated data CTEs
    LEFT JOIN refund_aggregates ra ON ra."OrderItemId" = oi."Id"
    LEFT JOIN payment_refunds prf ON prf."PaymentTransactionId" = pt."Id"
    LEFT JOIN coupon_aggregates ca ON ca."OrderItemId" = oi."Id"
    
    -- Filter out parent items that are a la carte (as in original logic)
    WHERE NOT (oi."ParentOrderItemId" IS NULL AND oi."IsALaCarte" = true)
)

-- Final SELECT with all calculated fields and proper formatting
SELECT
    COALESCE(reservation_code, '') AS "RID",
    COALESCE(order_number::text, '') AS "Order Id",
    COALESCE(order_item_id::text, '') AS "Line Item ID",
    created_on_items AS "Order Date",
    COALESCE(original_amount::text, '') AS "Original Order Amount",
    COALESCE(order_level_refund::text, '') AS "Order Refunded Amount",
    COALESCE(total_order_value::text, '') AS "Order Amount",
    payment_source AS "Order Type",
    payment_type AS "Payment Method",
    payment_provider_name AS "Payment Processor",
    is_refunded AS "Refunded?",
    user_name AS "User",
    product_name AS "Product Name",
    start_date AS "Rental Start Date",
    end_date AS "Rental End Date",
    location_name AS "Location",
    site_name AS "Subsite Location",
    COALESCE(total_items::text, '') AS "Line Item Sub Total",
    coupon_code AS "Promo Code ID",
    COALESCE(coupon_discount::text, '') AS "Coupon Amount",
    COALESCE(discount::text, '') AS "Line Item Discount",
    COALESCE(tip::text, '') AS "Gratuity",
    COALESCE(final_line_item_sub_total::text, '') AS "Final Line Item Sub Total",
    COALESCE(line_item_booking_fee::text, '') AS "Booking Fee",
    
    -- Calculate prorated processing fees
    COALESCE(
        ROUND(
            (processing_fee * actual_amount_items / NULLIF(pt_amount, 0))::numeric, 2
        )::text, 
        '0.00'
    ) AS "Create Line Item Payment Processor Fee",
    
    -- Calculate refund processing fees
    COALESCE(
        CASE
            WHEN (refunded_processing_fee * sum_refunded_total_item) = 0 THEN '0.00'
            ELSE ROUND(
                (refunded_processing_fee * sum_refunded_total_item / NULLIF(prf_sum_total_refund_amount, 0))::numeric, 2
            )::text
        END,
        '0.00'
    ) AS "Refund Line Item Payment Processor Fee",
    
    -- Calculate total processing fees (create - refund)
    COALESCE(
        ROUND(
            COALESCE(
                ROUND((processing_fee * actual_amount_items / NULLIF(pt_amount, 0))::numeric, 2), 0.00
            ) - 
            COALESCE(
                CASE
                    WHEN (refunded_processing_fee * sum_refunded_total_item) = 0 THEN 0.00
                    ELSE ROUND((refunded_processing_fee * sum_refunded_total_item / NULLIF(prf_sum_total_refund_amount, 0))::numeric, 2)
                END, 0.00
            ), 2
        )::text,
        '0.00'
    ) AS "Total Line Item Payment Processor Fee",
    
    COALESCE(tax_percentage::text, '') AS "Tax %",
    COALESCE(sales_tax::text, '') AS "Tax",
    COALESCE(delivery_fee::text, '') AS "Delivery Fee",
    
    -- Calculate total collected amount
    COALESCE(
        ROUND(
            tip + final_line_item_sub_total + line_item_booking_fee + sales_tax + delivery_fee -
            (
                COALESCE(
                    ROUND((processing_fee * actual_amount_items / NULLIF(pt_amount, 0))::numeric, 2), 0.00
                ) - 
                COALESCE(
                    CASE
                        WHEN (refunded_processing_fee * sum_refunded_total_item) = 0 THEN 0.00
                        ELSE ROUND((refunded_processing_fee * sum_refunded_total_item / NULLIF(prf_sum_total_refund_amount, 0))::numeric, 2)
                    END, 0.00
                )
            ), 2
        )::text,
        '0.00'
    ) AS "Total Collected",
    
    partner_name AS "Partner Name",
    partner_id AS "PartnerID",
    order_id_original

FROM main_data
ORDER BY "Line Item ID";

-- Create indexes for better query performance on frequently accessed columns
CREATE INDEX IF NOT EXISTS idx_order_report_pre_dc_line_item_id 
    ON order_report_sch.order_report_pre_dc("Line Item ID");
    
CREATE INDEX IF NOT EXISTS idx_order_report_pre_dc_order_id 
    ON order_report_sch.order_report_pre_dc("Order Id");
    
CREATE INDEX IF NOT EXISTS idx_order_report_pre_dc_rid 
    ON order_report_sch.order_report_pre_dc("RID");

-- TESTING 1 --

-- Validation queries
SELECT COUNT(*) AS total_records FROM order_report_sch.order_report_pre_dc;
SELECT COUNT(DISTINCT "Line Item ID") AS unique_line_items FROM order_report_sch.order_report_pre_dc;
SELECT COUNT(DISTINCT "Order Id") AS unique_orders FROM order_report_sch.order_report_pre_dc;

-- Sample output for verification
SELECT * FROM order_report_sch.order_report_pre_dc WHERE "RID" = 'LDV0014809' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_pre_dc WHERE "RID" = 'LDV0014980' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_pre_dc WHERE "RID" = 'LDV0014976' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_pre_dc WHERE "RID" = 'LDV0014919' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_pre_dc WHERE "RID" = 'LDV0014771' ORDER BY "Line Item ID";


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
  pc.*,
  lc.*
FROM order_report_sch.order_report_pre_dc r
LEFT JOIN order_report_sch.order_controls oc
  ON r.order_id_original = oc.order_id::uuid
LEFT JOIN order_report_sch.product_controls pc
  ON r."Line Item ID"::uuid = pc.order_item_id_p
LEFT JOIN order_report_sch.location_controls lc
  ON r."Line Item ID"::uuid = lc.order_item_id_l
ORDER BY r."Line Item ID";

-- Clean up the final table by removing helper columns
ALTER TABLE order_report_sch.order_report_dynamic
DROP COLUMN IF EXISTS order_item_id_p,
DROP COLUMN IF EXISTS order_item_id_l,
DROP COLUMN IF EXISTS order_id_original,
DROP COLUMN IF EXISTS order_id;


-- TESTING 2 --

-- Validation queries
SELECT COUNT(*) AS total_records FROM order_report_sch.order_report_dynamic;
SELECT COUNT(DISTINCT "Line Item ID") AS unique_line_items FROM order_report_sch.order_report_dynamic;
SELECT COUNT(DISTINCT "Order Id") AS unique_orders FROM order_report_sch.order_report_dynamic;

-- Sample output for verification
SELECT * FROM order_report_sch.order_report_dynamic WHERE "RID" = 'LDV0014809' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_dynamic WHERE "RID" = 'LDV0014980' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_dynamic WHERE "RID" = 'LDV0014976' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_dynamic WHERE "RID" = 'LDV0014919' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_dynamic WHERE "RID" = 'LDV0014771' ORDER BY "Line Item ID";

--------------------------------------------------------------------------------
-- 5) Formating Final Report with Dynamic Controls
--------------------------------------------------------------------------------
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
SELECT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014976' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014919' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_g WHERE "RID" = 'LDV0014771' ORDER BY "Line Item ID";
SELECT * FROM order_report_sch.order_report_g WHERE "Order Id" = '100000005027' ORDER BY "Line Item ID";

SELECT * FROM order_report_sch.order_report_g; 

SELECT * FROM public."Orders" WHERE "OrderNumber" = '100000005120';

