/*
  Purpose:
  GA4のセッション粒度を設計する前に、
  同一の user_pseudo_id × ga_session_id が複数の日付を跨ぐケースが
  存在するかを確認する。

  Background:
  日別ファネルを作成する際、event_dateをそのままセッションの粒度に含めると、
  日付を跨ぐセッションが複数行に分割される可能性がある。

  この確認結果をもとに、分析用データマートでは
  1行 = 1 user_pseudo_id × 1 ga_session_id
  とし、session_dateにはセッション内の最初のイベント日を採用する。
*/

SELECT
  user_pseudo_id,
  ga_session_id,
  COUNT(DISTINCT event_date) AS date_count
FROM (
  SELECT
    user_pseudo_id,
    event_date,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)
GROUP BY
  user_pseudo_id,
  ga_session_id
HAVING COUNT(DISTINCT event_date) > 1
ORDER BY date_count DESC
LIMIT 20
