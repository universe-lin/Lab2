{% snapshot snapshot_stock_analytics %}

{{
  config(
    target_schema='snapshot',
    unique_key='ticker || \'-\' || date',
    strategy='check',
    check_cols=['ma_7', 'ma_14', 'rsi_14', 'momentum']
  )
}}

SELECT * FROM {{ ref('stock_analytics') }}

{% endsnapshot %}
