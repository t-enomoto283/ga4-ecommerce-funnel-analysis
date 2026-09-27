/*
  Purpose:
  add_shipping_info と add_payment_info が同一セッション内に
  存在するだけでなく、時系列として
  add_shipping_info → add_payment_info の順序が成立しているか検証する。

  Background:
  セッションマートのイベントフラグだけでは、
  各イベントの発生有無は確認できるが発生順序は確認できない。
  そのためGA4生データのevent_timestampを使用して検証する。

  Method:
  1. user_pseudo_id × ga_session_id 単位に集約
  2. 最初のadd_shipping_infoのtimestampを取得
  3. 最初のadd_payment_infoのtimestampを取得
  4. payment timestamp > shipping timestamp となるセッション数を確認

  Period:
  2020-11-01 ～ 2021-01-31
*/

WITH session_events AS (
  SELECT
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,
    MIN(
      IF(
        event_name = 'add_shipping_info',
        event_timestamp, NULL
      )
    ) AS first_shipping_timestamp,
    MIN(
      IF(
        event_name = 'add_payment_info',
        event_timestamp, NULL
      )
    ) AS first_payment_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('add_shipping_info', 'add_payment_info')
  GROUP BY
    user_pseudo_id,
    ga_session_id
)
SELECT
  COUNTIF(first_shipping_timestamp IS NOT NULL) AS shipping_sessions,
  COUNTIF(
    first_shipping_timestamp IS NOT NULL
    AND first_payment_timestamp IS NOT NULL
  ) AS shipping_and_payment_sessions,
  COUNTIF(
    first_shipping_timestamp IS NOT NULL
    AND first_payment_timestamp > first_shipping_timestamp
  ) AS payment_after_shipping_sessions
FROM session_events
