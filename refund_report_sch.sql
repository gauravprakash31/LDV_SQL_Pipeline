-- REFUND REPORT: standalone SQL starting from clean_sch tables
-- Drop & recreate reporting schema for refund report
DROP SCHEMA IF EXISTS refund_report_sch CASCADE;
CREATE SCHEMA IF NOT EXISTS refund_report_sch;

-- Build refund_report_raw with CTE
CREATE TABLE refund_report_sch.refund_report_raw AS
WITH base_items AS (
  SELECT
    oi.order_id,
    oi.order_item_id,
    o.order_number,
    r.reservation_code,
    oi.created_on_items      AS original_order_date,
    oi.start_date,
    oi.end_date,
    ui.user_name,
    prd.product_name,
    rt.rental_name,
    loc.location_name,
    site.location_name       AS site_name,
    COALESCE(site.tax_rate, loc.tax_rate) AS tax_percentage,
    oi.total_amount_items,
    oi.coupon_discount,
    oi.discount,
    oi.tip,
    oi.sales_tax,
    oi.delivery_fee,
    oi.booking_fee_item      AS booking_fee_item,
    oi.partner_id,
    pa.partner_name,
    pt.processing_fee,
    pr.refunded_processing_fee,
    pt.payment_source        AS order_type,
    pt.payment_type,
    pt.payment_provider_name,
    COALESCE(ocg.coupon_code, '') AS coupon_code,
    oh.refunded_total,
    oh.refund_order_number    AS refund_order_number
  FROM clean_sch.order_items oi
  JOIN clean_sch.orders o               ON o.order_id             = oi.order_id
  LEFT JOIN clean_sch.reservations r    ON r.reservation_id        = o.reservation_id
  LEFT JOIN clean_sch.users ui          ON ui.users_id            = o.created_by
  LEFT JOIN clean_sch.products prd      ON prd.product_id         = oi.product_id
  LEFT JOIN clean_sch.rental_types rt   ON rt.rental_types_id     = oi.rental_type_id
  LEFT JOIN clean_sch.locations loc     ON loc.location_id        = oi.location_id
  LEFT JOIN clean_sch.locations site    ON site.location_id       = oi.site_id
  LEFT JOIN clean_sch.partners pa       ON pa.partner_id          = oi.partner_id
  LEFT JOIN clean_sch.payment_transactions pt
                                        ON pt.order_id           = oi.order_id
  LEFT JOIN clean_sch.payment_refund pr
                                        ON pr.payment_transaction_id = pt.payment_transaction_id
  LEFT JOIN (
    SELECT order_item_id,
           STRING_AGG(c.coupon_code, ',') AS coupon_code
    FROM clean_sch.order_coupons oc
    JOIN clean_sch.coupons c ON c.coupon_id = oc.coupon_id
    GROUP BY order_item_id
  ) ocg ON ocg.order_item_id   = oi.order_item_id
  LEFT JOIN clean_sch.order_history oh  ON oh.order_id        = oi.order_id
)

-- 1) Payment rows
SELECT
  bi.reservation_code                AS "RID",
  bi.order_number                    AS "OrderId",
  bi.order_item_id                   AS "LineItemId",
  bi.original_order_date             AS "OriginalOrderDate",
  bi.original_order_date             AS "TransactionDate",
  bi.total_amount_items              AS "OriginalLineItemAmount",
  bi.order_type                      AS "OrderType",
  0                                  AS "RefundAmount",
  'Payment'                          AS "TransactionType",
  bi.payment_type                    AS "PaymentMethod",
  bi.payment_provider_name           AS "PaymentProcessor",
  NULL::text                         AS "RefundOrderId",
  bi.user_name                       AS "User",
  bi.product_name                    AS "ProductName",
  bi.rental_name                     AS "RentalType",
  bi.start_date                      AS "RentalStartDate",
  bi.end_date                        AS "RentalEndDate",
  bi.location_name                   AS "LocationName",
  bi.site_name                       AS "SubsiteLocationName",
  bi.tax_percentage                  AS "TaxPercent",
  bi.total_amount_items              AS "LineItemSubTotal",
  bi.coupon_code                     AS "PromoCodeId",
  bi.coupon_discount                 AS "CouponAmount",
  bi.discount                        AS "LineItemDiscount",
  bi.tip                             AS "Gratuity",
  bi.total_amount_items
    - bi.coupon_discount
    - bi.discount                     AS "FinalLineItemSubTotal",
  (bi.booking_fee_item * bi.total_amount_items / NULLIF(o.total,0)) AS "BookingFee",
  (bi.processing_fee * bi.total_amount_items / NULLIF(o.total,0))     AS "ProcessingFees",
  bi.sales_tax                       AS "Tax",
  bi.delivery_fee                    AS "DeliveryFee",
  (
    (bi.total_amount_items - bi.coupon_discount - bi.discount)
    + (bi.booking_fee_item * bi.total_amount_items / NULLIF(o.total,0))
    + bi.tip + bi.sales_tax + bi.delivery_fee
    - (bi.processing_fee * bi.total_amount_items / NULLIF(o.total,0))
  )                                  AS "TotalCollected",
  bi.refunded_total                  AS "OrderLevelRefund",
  bi.refund_order_number::text       AS "RefundOrderNumber",
  bi.partner_name                    AS "PartnerName",
  bi.partner_id                      AS "PartnerId"
FROM base_items bi
JOIN clean_sch.orders o ON o.order_id = bi.order_id

UNION ALL

-- 2) Refund rows
SELECT DISTINCT ON (p.order_item_id)
  p.reservation_code                AS "RID",
  p.order_number                    AS "OrderId",
  p.order_item_id                   AS "LineItemId",
  p.original_order_date             AS "OriginalOrderDate",
  ih.created_on                     AS "TransactionDate",
  p.total_amount_items              AS "OriginalLineItemAmount",
  p.order_type                      AS "OrderType",
  p.refunded_total                  AS "RefundAmount",
  'Refund'                          AS "TransactionType",
  p.payment_type                    AS "PaymentMethod",
  p.payment_provider_name           AS "PaymentProcessor",
  p.refund_order_number::text       AS "RefundOrderId",
  p.user_name                       AS "User",
  p.product_name                    AS "ProductName",
  p.rental_name                     AS "RentalType",
  p.start_date                      AS "RentalStartDate",
  p.end_date                        AS "RentalEndDate",
  p.location_name                   AS "LocationName",
  p.site_name                       AS "SubsiteLocationName",
  p.tax_percentage                  AS "TaxPercent",
  p.total_amount_items              AS "LineItemSubTotal",
  p.coupon_code                     AS "PromoCodeId",
  p.coupon_discount                 AS "CouponAmount",
  p.discount                        AS "LineItemDiscount",
  p.tip                             AS "Gratuity",
  p.total_amount_items
    - p.coupon_discount
    - p.discount                     AS "FinalLineItemSubTotal",
  (p.booking_fee_item * p.total_amount_items / NULLIF(o.total,0)) AS "BookingFee",
  (p.refunded_processing_fee * p.total_amount_items / NULLIF(o.total,0)) AS "ProcessingFees",
  p.sales_tax                       AS "Tax",
  p.delivery_fee                    AS "DeliveryFee",
  (
    (p.total_amount_items - p.coupon_discount - p.discount)
    + (p.booking_fee_item * p.total_amount_items / NULLIF(o.total,0))
    + p.tip + p.sales_tax + p.delivery_fee
    - (p.refunded_processing_fee * p.total_amount_items / NULLIF(o.total,0))
  )                                  AS "TotalCollected",
  p.refunded_total                  AS "OrderLevelRefund",
  p.refund_order_number::text       AS "RefundOrderNumber",
  p.partner_name                    AS "PartnerName",
  p.partner_id                      AS "PartnerId"

FROM base_items p
JOIN clean_sch.order_item_history ih
  ON ih.order_item_id = p.order_item_id
 AND ih.refunded_quantity > 0
JOIN clean_sch.order_history oh
  ON oh.order_id      = p.order_id
 AND oh.refunded_total > 0
JOIN clean_sch.orders o
  ON o.order_id       = p.order_id;


SELECT *
FROM refund_report_sch.refund_report_raw
WHERE "RID" = 'LDV0014980'
ORDER BY "LineItemId" ASC;
