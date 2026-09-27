/*
  Purpose:
  セッション単位のファネルマートから、
  ファネル各ステージのセッション数を日別に集計し、
  BIで時系列推移を確認できるデータセットを作成する。

  Input:
  ga4_session_funnel_mart

  Output grain:
  1 row = 1 session_date
*/

SELECT
  session_date,
  COUNT(*) AS session_count,
  SUM(page_view_flag) AS page_view_sessions,
  SUM(view_item_flag) AS view_item_sessions,
  SUM(add_to_cart_flag) AS add_to_cart_sessions,
  SUM(begin_checkout_flag) AS begin_checkout_sessions,
  SUM(add_shipping_info_flag) AS add_shipping_info_sessions,
  SUM(add_payment_info_flag) AS add_payment_info_sessions,
  SUM(purchase_flag) AS purchase_sessions
FROM `resonant-tract-508812-p9.ga4_analysis.ga4_session_funnel_mart`
GROUP BY session_date
ORDER BY session_date
