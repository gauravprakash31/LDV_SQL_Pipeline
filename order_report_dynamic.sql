CREATE EXTENSION IF NOT EXISTS tablefunc;

/* Flatten ALL dynamic controls into one table */
DROP TABLE IF EXISTS clean_sch.dc_new_all;
CREATE TABLE clean_sch.dc_new_all AS

-- 1) Order-level controls assigned to each line-item
SELECT
  oi.order_item_id    AS order_items_id,
  dc.dc_name_o        AS control_name,
  dco.dc_option_o     AS control_value
FROM clean_sch.dc_values_o dv
JOIN clean_sch.dc_options_o dco ON dv.dc_option_id_o = dco.dc_option_id_o
JOIN clean_sch.dc_o         dc  ON dco.dc_id_o         = dc.dc_id_o
JOIN clean_sch.order_items  oi  ON dv.dc_order_id_o    = oi.order_id

UNION ALL

-- 2) OrderItem-level controls (favorite fruit, referral...)
SELECT
  di.dc_order_item_id AS order_items_id,
  dc.dc_name_o        AS control_name,
  dco.dc_option_o     AS control_value
FROM clean_sch.dc_items_o di
JOIN clean_sch.dc_o         dc  ON di.dc_id_o        = dc.dc_id_o
JOIN clean_sch.dc_options_o dco ON di.dc_option_id_o = dco.dc_option_id_o

UNION ALL

-- 3) Product-level controls
SELECT
  oi.order_item_id    AS order_items_id,
  p.dc_name_p         AS control_name,
  po.dc_option_p      AS control_value
FROM clean_sch.dc_values_p dv
JOIN clean_sch.dc_options_p po ON dv.dc_option_id_p = po.dc_option_id_p
JOIN clean_sch.dc_p         p  ON po.dc_id_p        = p.dc_id_p
JOIN clean_sch.order_items  oi ON dv.product_id      = oi.product_id

UNION ALL

-- 4) Location-level controls
SELECT
  oi.order_item_id    AS order_items_id,
  l.dc_name_l         AS control_name,
  lo.dc_option_l      AS control_value
FROM clean_sch.dc_values_l dv
JOIN clean_sch.dc_options_l lo ON dv.dc_option_id_l = lo.dc_option_id_l
JOIN clean_sch.dc_l         l  ON lo.dc_id_l        = l.dc_id_l
JOIN clean_sch.order_items  oi ON dv.location_id     = oi.location_id
;

/* Dynamic pivot of all control names */
DO $$
DECLARE
  col_list TEXT;
  dyn_sql  TEXT;
BEGIN
  -- Build one CASE per distinct control_name
  SELECT string_agg(
    format(
      'MAX(CASE WHEN control_name = %L THEN control_value END) AS %I',
      control_name,
      control_name
    ), ', '
  )
  INTO col_list
  FROM (
    SELECT DISTINCT control_name
    FROM clean_sch.dc_new_all
  ) sub;

  -- Create the pivoted control table
  dyn_sql := format($sql$
    DROP TABLE IF EXISTS order_report_sch.all_controls;
    CREATE TABLE order_report_sch.all_controls AS
    SELECT
      order_items_id,
      %s
    FROM clean_sch.dc_new_all
    GROUP BY order_items_id;
  $sql$, col_list);

  EXECUTE dyn_sql;
END
$$;

/* Final join into order report */
DROP TABLE IF EXISTS order_report_sch.order_report_with_all_dc;
CREATE TABLE order_report_sch.order_report_with_all_dc AS
SELECT
  o.*,
  c.*    -- all dynamic-control columns for order, item, product, location
FROM order_report_sch.order_report_final o
LEFT JOIN order_report_sch.all_controls c
  ON o."Line Item Id" = c.order_items_id;



SELECT *
FROM order_report_sch.order_report_with_all_dc
WHERE "RID" = 'LDV0014980'
ORDER BY "Line Item Id" ASC; 
