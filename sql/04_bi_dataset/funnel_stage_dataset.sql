/*
  Purpose:
  セッション単位のファネルマートを、
  BIでファネルステージごとに可視化しやすい縦持ち形式へ変換する。

  Input:
  ga4_session_funnel_mart

  Transformation:
  横持ちで保持している7つのイベントフラグをUNPIVOTし、
  stage × session_count の形式へ変換する。

  Funnel stages:
  page_view
  → view_item
  → add_to_cart
  → begin_checkout
  → add_shipping_info
  → add_payment_info
  → purchase
*/

SELECT
  stage,
  SUM(session_flag) AS session_count
FROM (
  SELECT
    page_view_flag,
    view_item_flag,
    add_to_cart_flag,
    begin_checkout_flag,
    add_shipping_info_flag,
    add_payment_info_flag,
    purchase_flag
  FROM `resonant-tract-508812-p9.ga4_analysis.ga4_session_funnel_mart`
)
UNPIVOT (
  session_flag FOR stage IN (
    page_view_flag AS 'page_view',
    view_item_flag AS 'view_item',
    add_to_cart_flag AS 'add_to_cart',
    begin_checkout_flag AS 'begin_checkout',
    add_shipping_info_flag AS 'add_shipping_info',
    add_payment_info_flag AS 'add_payment_info',
    purchase_flag AS 'purchase'
  )
)
GROUP BY stage
ORDER BY
  CASE stage
    WHEN 'page_view' THEN 1
    WHEN 'view_item' THEN 2
    WHEN 'add_to_cart' THEN 3
    WHEN 'begin_checkout' THEN 4
    WHEN 'add_shipping_info' THEN 5
    WHEN 'add_payment_info' THEN 6
    WHEN 'purchase' THEN 7
  END
