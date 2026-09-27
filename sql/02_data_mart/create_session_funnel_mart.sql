/*
  Purpose:
  GA4のイベント単位データを、ファネル分析で再利用できる
  セッション単位のデータマートへ変換する。

  Grain:
  1 row = 1 user_pseudo_id × 1 ga_session_id

  session_date:
  同一セッションが複数の日付を跨ぐ可能性を考慮し、
  セッション内で最初に記録された event_date を採用する。

  Transformation:
  GA4のevent_paramsからga_session_idを取得し、
  ファネルを構成する各イベントについて、
  セッション内で1回以上発生していれば1、なければ0としてフラグ化する。

  Funnel stages:
  page_view
  → view_item
  → add_to_cart
  → begin_checkout
  → add_shipping_info
  → add_payment_info
  → purchase

  Source:
  BigQuery Public Dataset
  bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*

  Period:
  2020-11-01 ～ 2021-01-31
*/

SELECT
  user_pseudo_id,
  (
    SELECT value.int_value
    FROM UNNEST(event_params)
    WHERE key = 'ga_session_id'
  ) AS ga_session_id,
  MIN(event_date) AS session_date,
  IF(
    COUNTIF(event_name = 'page_view') > 0,
    1, 0
  ) AS page_view_flag,
  IF(
    COUNTIF(event_name = 'view_item') > 0,
    1, 0
  ) AS view_item_flag,
  IF(
    COUNTIF(event_name = 'add_to_cart') > 0,
    1, 0
  ) AS add_to_cart_flag,
  IF(
    COUNTIF(event_name = 'begin_checkout') > 0,
    1, 0
  ) AS begin_checkout_flag,
  IF(
    COUNTIF(event_name = 'add_shipping_info') > 0,
    1, 0
  ) AS add_shipping_info_flag,
  IF(
    COUNTIF(event_name = 'add_payment_info') > 0,
    1, 0
  ) AS add_payment_info_flag,
  IF(
    COUNTIF(event_name = 'purchase') > 0,
    1, 0
  ) AS purchase_flag
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY
  user_pseudo_id,
  ga_session_id
