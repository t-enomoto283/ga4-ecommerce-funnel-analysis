# GA4 Ecommerce Funnel Analysis

BigQueryのGA4公開Eコマースデータを使用し、  
生のイベントデータからセッション単位のデータマートを構築し、
データ品質検証、ファネル分析、BI向けデータ整形、Tableauによる可視化まで行ったプロジェクトです。

分析結果を出すだけでなく、GA4のイベントデータを
「継続的に分析・可視化できるデータ」に変換することを重視しました。

---

## Project Overview

本プロジェクトでは、Google Analytics 4の公開Eコマースデータを対象に、
以下の流れでデータ処理・分析を行いました。

    GA4 Raw Events
          ↓
    Data Profiling / Quality Check
          ↓
    Transformation
          ↓
    Session Data Mart
          ↓
    BI Dataset / Analysis Mart
          ↓
    Tableau Visualization

また、分析過程で発見したイベント計測上の異常について、
継続的な検知を想定した日次データ品質チェックSQLを作成しました。

---

## Data Source

BigQuery Public Dataset：

    bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*

対象期間：

    2020-11-01 ～ 2021-01-31

92日間のGA4 Eコマースイベントデータを使用しています。

---

## Data Engineering

### 1. Data Profiling / Grain Validation

GA4のイベントデータをセッション単位へ変換する前に、
`user_pseudo_id × ga_session_id` が複数の日付を跨ぐ可能性を確認しました。

日付をそのまま集約粒度に含めると、
同一セッションが日付単位で分割される可能性があります。

そのため、最終的なセッションマートでは以下の粒度を採用しています。

    1 row = 1 user_pseudo_id × 1 ga_session_id

`session_date` には、そのセッションで最初に記録された
`event_date` を使用しています。

関連SQL：

    sql/01_data_profiling/session_grain_check.sql

---

### 2. Session Funnel Data Mart

GA4の生イベントデータから `ga_session_id` を抽出し、
イベント単位のデータをセッション単位へ集約しました。

各セッションについて、以下のイベントが1回以上発生しているかを
0 / 1のフラグとして保持しています。

    page_view
    view_item
    add_to_cart
    begin_checkout
    add_shipping_info
    add_payment_info
    purchase

これにより、GA4のイベント単位データを
ファネル分析で再利用できるセッション単位のデータへ変換しました。

分析用テーブル：

    ga4_session_funnel_mart

関連SQL：

    sql/02_data_mart/create_session_funnel_mart.sql

---

### 3. Data Quality Monitoring

分析過程で、`view_item` が記録されている一方で
`add_to_cart` が0件となる日が連続して存在することを確認しました。

このような計測異常を継続的に検知することを想定し、
日次品質チェックSQLを作成しました。

判定ステータス：

    MISSING_EVENT
    INSUFFICIENT_DATA
    RATE_ANOMALY
    OK

過去7日間の有効データの中央値を基準とし、
単純な固定値だけではなく直近のデータ傾向との比較によって
急激な変化を検知する設計としています。

なお、本プロジェクトでは監視SQLの設計・実装までを対象としており、
スケジュール実行や外部通知の自動化は実装していません。

関連SQL：

    sql/03_data_quality/daily_event_quality_check.sql

---

### 4. BI Dataset

セッションマートをそのまま可視化するだけではなく、
BIで扱いやすい形式へ変換しました。

#### Funnel Stage Dataset

横持ちで保持しているイベントフラグを `UNPIVOT` し、

    stage × session_count

の縦持ち形式へ変換しています。

関連SQL：

    sql/04_bi_dataset/funnel_stage_dataset.sql

#### Daily Funnel Dataset

セッションマートを日付単位で集計し、
各ファネルステージのセッション数を時系列で確認できる
データセットを作成しました。

関連SQL：

    sql/04_bi_dataset/daily_funnel_dataset.sql

---

## Checkout Analysis

### Shipping → Payment

後半ファネルを確認した結果、
`add_shipping_info → add_payment_info` を詳細分析の対象としました。

セッション単位で確認すると、

    Shipping sessions                 11,105
    Shipping & Payment sessions        6,812
    Shipping & Payment rate           61.34%

となりました。

ただし、セッションマートの0 / 1フラグだけでは
イベントの発生順序までは確認できません。

そこでGA4生データの `event_timestamp` に戻り、
セッションごとの最初のShippingと最初のPaymentの時刻を比較しました。

結果：

    Shipping sessions                         11,105
    Shipping & Payment sessions                6,812
    Payment after Shipping sessions            6,811

両イベントが存在する6,812セッションのうち、
6,811セッションで今回の定義による
`add_shipping_info → add_payment_info` の順序を確認しました。

関連SQL：

    sql/05_checkout_analysis/validate_shipping_payment_sequence.sql

---

### Shipping / Payment Analysis Mart

Shipping → Paymentをさらに分析するため、
ファネル全体用のマートとは別に専用の分析マートを作成しました。

分析用テーブル：

    ga4_shipping_payment_analysis_mart

粒度：

    1 row = 1 user_pseudo_id × 1 ga_session_id

主な分析軸：

    session_date
    device_category
    country
    traffic_source
    traffic_medium

イベントフラグ：

    add_shipping_info_flag
    add_payment_info_flag

ファネル全体用マートへ分析軸を追加し続けるのではなく、
用途に応じて分析マートを分離しています。

関連SQL：

    sql/05_checkout_analysis/create_shipping_payment_mart.sql

---

## Tableau Visualization

作成したデータマートをTableau Publicへ接続し、
ファネル全体とShipping → Paymentの詳細分析を可視化しました。

**Tableau Public：**

https://public.tableau.com/views/GA4EcommerceFunnelAnalysis_17900292718680/GA4_E__1?:language=ja-JP&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link

主な可視化：

- 92日間のEコマースファネル
- 日別ファネル推移
- Shipping → Payment到達状況
- Device別比較
- Country別比較
- Source / Medium別比較

※ Source / Medium分析では、
参照元情報として利用できない `(data deleted) / (data deleted)` を
可視化上のノイズとして除外しています。

---

## Repository Structure

    ga4-ecommerce-funnel-analysis/
    │
    ├── README.md
    │
    └── sql/
        │
        ├── 01_data_profiling/
        │   └── session_grain_check.sql
        │
        ├── 02_data_mart/
        │   └── create_session_funnel_mart.sql
        │
        ├── 03_data_quality/
        │   └── daily_event_quality_check.sql
        │
        ├── 04_bi_dataset/
        │   ├── funnel_stage_dataset.sql
        │   └── daily_funnel_dataset.sql
        │
        └── 05_checkout_analysis/
            ├── create_shipping_payment_mart.sql
            └── validate_shipping_payment_sequence.sql

---

## Technologies

- Google BigQuery
- SQL
- GA4 event data
- Tableau Public
- GitHub

---

## Key Points

本プロジェクトでは、分析結果そのものだけでなく、
分析可能なデータを作るまでのプロセスを重視しています。

- GA4生データの構造・粒度確認
- セッション粒度の設計
- イベントデータの集約・フラグ化
- 分析用データマートの作成
- データ品質チェック
- BI用途に合わせたデータ変換
- 分析目的に応じた専用マートの作成
- 生データのtimestampを利用したイベント順序検証
- Tableauによる可視化

データの抽出だけでなく、
「データを整備し、再利用可能な形にし、分析・BIで継続的に利用できる状態にする」
ことを意識して設計しました。
