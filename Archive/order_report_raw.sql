DROP TABLE IF EXISTS process_sch.order_report_raw;
CREATE TABLE process_sch.order_report_raw AS
SELECT
  ocp.*,                                    -- all order/payments/coupon cols
  -- priority: site tax if available else location
  COALESCE(site.tax_rate, l.tax_rate) AS tax_percentage,
  -- final item sub total (no calc until we know discount semantics)
  ocp.total_amount_items - ocp.coupon_discount - ocp.discount AS final_line_items_sub_total,
  -- distributed processing fee
  ocp.processing_fee * (ocp.total_amount_items / NULLIF(ocp.total,0)) AS create_lineitem_processing_fee,
  ocp.refunded_processing_fee * (ocp.total_amount_items / NULLIF(ocp.total,0)) AS refund_lineitem_processing_fee,
  (ocp.processing_fee * (ocp.total_amount_items / NULLIF(ocp.total,0))
   + ocp.refunded_processing_fee * (ocp.total_amount_items / NULLIF(ocp.total,0))) AS total_lineitem_processing_fee,
  -- total collected (rough draft)
  ocp.amount - ocp.payment_refunded_total - ocp.refunded_processing_fee AS total_collected --
FROM process_sch.orders_with_coupons ocp
LEFT JOIN clean_sch.locations l    ON l.location_id  = ocp.location_id
LEFT JOIN clean_sch.locations site ON site.location_id = ocp.site_id;
