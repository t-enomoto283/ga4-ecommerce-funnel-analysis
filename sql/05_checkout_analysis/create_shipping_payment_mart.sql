/*
  Purpose:
  ファネル分析で特定した Shipping → Payment 区間を
  Device / Country / Source / Medium 別に深掘りするため、
  Tableauで利用する専用のセッション単位データマートを作成する。

  Grain:
  1 row = 1 user_pseudo_id × 1 ga_session_id

  Target:
  add_shipping_info または add_payment_info が
  発生したセッション

  Dimensions:
  - session_date
  - device_category
  - country
  - traffic_source
  - traffic_medium

  Metrics:
  - add_shipping_info_flag
  - add_payment_info_flag

  Design:
  ファネル全体用の ga4_session_funnel_mart とは役割を分離し、
  Shipping → Payment の詳細分析に必要な属性を持つ
  専用マートとして作成する。
*/

CREATE OR REPLACE TABLE
  `resonant-tract-508812-p9.ga4_analysis.ga4_shipping_payment_analysis_mart`
AS
WITH session_base AS (
  SELECT
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,
    event_date AS session_date,
    device.category AS device_category,
    geo.country AS country,
    traffic_source.source AS traffic_source,
    traffic_source.medium AS traffic_medium,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),
session_mart AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    MIN(session_date) AS session_date,
    ANY_VALUE(device_category) AS device_category,
    ANY_VALUE(country) AS country,
    ANY_VALUE(traffic_source) AS traffic_source,
    ANY_VALUE(traffic_medium) AS traffic_medium,
    IF(
      COUNTIF(event_name = 'add_shipping_info') > 0,
      1, 0
    ) AS add_shipping_info_flag,
    IF(
      COUNTIF(event_name = 'add_payment_info') > 0,
      1, 0
    ) AS add_payment_info_flag
  FROM session_base
  WHERE ga_session_id IS NOT NULL
  GROUP BY
    user_pseudo_id,
    ga_session_id
  HAVING
    add_shipping_info_flag = 1
    OR add_payment_info_flag = 1
)
SELECT
  *
FROM session_mart
