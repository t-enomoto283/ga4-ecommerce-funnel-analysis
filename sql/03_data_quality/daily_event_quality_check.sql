/*
  Purpose:
  ファネル分析に使用するイベントデータについて、
  日次で計測欠損・急激な変動を検知する。

  Target:
  view_item → add_to_cart の到達率

  Monitoring logic:
  - MISSING_EVENT:
    view_itemが存在するにもかかわらずadd_to_cartが0件
  - INSUFFICIENT_DATA:
    過去7日間の有効データが3日未満
  - RATE_ANOMALY:
    当日の到達率が過去7日間中央値の0.5倍未満、
    または1.5倍超
  - OK:
    上記のいずれにも該当しない

  Baseline:
  過去7日間のうちadd_to_cartが存在する日を対象として
  add_to_cart_rateの中央値を算出する。

  Source:
  ga4_session_funnel_mart
*/

WITH daily_rates AS (
  SELECT
    session_date,
    SUM(view_item_flag) AS view_item_sessions,
    SUM(add_to_cart_flag) AS add_to_cart_sessions,
    ROUND(
      SAFE_DIVIDE(
        SUM(add_to_cart_flag),
        SUM(view_item_flag)
      ) * 100,
      2
    ) AS add_to_cart_rate
  FROM `resonant-tract-508812-p9.ga4_analysis.ga4_session_funnel_mart`
  GROUP BY session_date
),

median_rates AS (
  SELECT
    current_day.session_date,
    PERCENTILE_CONT(past_day.add_to_cart_rate, 0.5) OVER (
      PARTITION BY current_day.session_date
    ) AS previous_7day_median,
    COUNT(past_day.session_date) OVER (
      PARTITION BY current_day.session_date
    ) AS previous_7day_valid_days
  FROM daily_rates AS current_day
  LEFT JOIN daily_rates AS past_day
    ON past_day.session_date BETWEEN
      FORMAT_DATE(
        '%Y%m%d',
        DATE_SUB(
          PARSE_DATE('%Y%m%d', current_day.session_date),
          INTERVAL 7 DAY
        )
      )
      AND FORMAT_DATE(
        '%Y%m%d',
        DATE_SUB(
          PARSE_DATE('%Y%m%d', current_day.session_date),
          INTERVAL 1 DAY
        )
      )
    AND past_day.add_to_cart_sessions > 0
),

daily_quality AS (
  SELECT
    daily_rates.session_date,
    daily_rates.view_item_sessions,
    daily_rates.add_to_cart_sessions,
    daily_rates.add_to_cart_rate,
    ROUND(
      ANY_VALUE(median_rates.previous_7day_median),
      2
    ) AS previous_7day_median,
    ANY_VALUE(median_rates.previous_7day_valid_days) AS previous_7day_valid_days
  FROM daily_rates
  LEFT JOIN median_rates
    ON daily_rates.session_date = median_rates.session_date
  GROUP BY
    daily_rates.session_date,
    daily_rates.view_item_sessions,
    daily_rates.add_to_cart_sessions,
    daily_rates.add_to_cart_rate
),

quality_metrics AS (
  SELECT
    session_date,
    view_item_sessions,
    add_to_cart_sessions,
    add_to_cart_rate,
    previous_7day_median,
    previous_7day_valid_days,
    ROUND(
      SAFE_DIVIDE(
        add_to_cart_rate,
        previous_7day_median
      ),
      2
    ) AS rate_ratio
  FROM daily_quality
)

SELECT
  session_date,
  view_item_sessions,
  add_to_cart_sessions,
  add_to_cart_rate,
  previous_7day_median,
  previous_7day_valid_days,
  rate_ratio,
  CASE
    WHEN view_item_sessions > 0
      AND add_to_cart_sessions = 0
      THEN 'MISSING_EVENT'
    WHEN previous_7day_valid_days < 3
      THEN 'INSUFFICIENT_DATA'
    WHEN previous_7day_valid_days >= 3
      AND (
        rate_ratio < 0.5
        OR rate_ratio > 1.5
      )
      THEN 'RATE_ANOMALY'
    ELSE 'OK'
  END AS monitoring_status
FROM quality_metrics
ORDER BY session_date
