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
WHERE control_name = 'Tax Counties'
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


SELECT * FROM order_report_sch.location_controls WHERE "Tax Counties" IS NOT NULL;
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

FROM order_report_sch.order_report_final r
LEFT JOIN order_report_sch.order_controls oc
  ON r.order_id_original = oc.order_id::uuid
LEFT JOIN order_report_sch.product_controls pc
  ON r."Line Item Id"::uuid = pc.order_item_id_p
LEFT JOIN order_report_sch.location_controls lc
  ON r."Line Item Id"::uuid = lc.order_item_id_l
ORDER BY r."Line Item Id";

ALTER TABLE order_report_sch.order_report_dynamic
DROP COLUMN order_item_id_p,
DROP COLUMN order_item_id_l,
DROP COLUMN order_id_original,
DROP COLUMN order_id;

--check

SELECT * FROM order_report_sch.order_report_dynamic WHERE "RID" = 'LDV0014980' ORDER BY "Line Item Id";

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

SELECT * FROM order_report_sch.order_report_final WHERE "RID" = 'LDV0014980' ORDER BY "Line Item Id";


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

SELECT * FROM order_report_sch.order_report_final WHERE "RID" = 'LDV0014980' ORDER BY "Line Item Id";
