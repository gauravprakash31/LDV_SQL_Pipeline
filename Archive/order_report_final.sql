DROP TABLE IF EXISTS process_sch.order_report_final;
CREATE TABLE process_sch.order_report_final AS
SELECT
  reservation_code                          AS rid,
  order_number                              AS order_id_report,  -- sheet label
  order_item_id,
  created_on_items                          AS order_date,
  amount                                    AS original_order_amount,
  payment_refunded_total                    AS order_refunded_amount,
  total                                     AS order_amount,
  order_type                                AS order_type,
  payment_type,
  payment_provider_name,
  is_refunded                               AS refunded_flag,
  user_name                                 AS user_name,
  product_name,
  start_date,
  end_date,
  location_name,
  -- sub-site location name will require join to site; placeholder:
  site.location_name                        AS subsite_location_name,
  tax_percentage,
  total_amount_items                        AS line_item_sub_total,
  coupon_code                               AS promo_code_id,
  coupon_discount,
  discount                                  AS line_item_discount,
  tip                                       AS gratuity,
  final_line_item_sub_total,
  booking_fee,
  delivery_fee,
  create_lineitem_processing_fee,
  refund_lineitem_processing_fee,
  total_lineitem_processing_fee,
  sales_tax,
  total_collected,
  partner_name
FROM process_sch.order_report_raw orr
LEFT JOIN clean_sch.locations site ON site.location_id = orr.site_id;

SELECT * FROM process_sch.order_report_final LIMIT 50;


-- sample order:
SELECT *
FROM process_sch.order_report_final
WHERE order_id_report IN (
  SELECT order_number FROM clean_sch.orders
  WHERE order_id = 'b9aa1928-4acf-4f6e-994a-5f9b4c303404'
);

