WITH base AS (
    SELECT * FROM {{ ref('clean_stock_prices') }}
),

moving_averages AS (
    SELECT
        ticker,
        date,
        close,
        AVG(close) OVER (
            PARTITION BY ticker ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS ma_7,
        AVG(close) OVER (
            PARTITION BY ticker ORDER BY date
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) AS ma_14,
        LAG(close) OVER (
            PARTITION BY ticker ORDER BY date
        ) AS previous_close
    FROM base
),

indicators AS (
    SELECT
        *,
        CASE 
            WHEN previous_close IS NULL THEN NULL
            ELSE 100 - (100 / (1 + ((close - previous_close) / NULLIF(previous_close, 0))))
        END AS rsi,
        (close - previous_close) AS momentum
    FROM moving_averages
)

SELECT *
FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY ticker, date ORDER BY date) AS row_num
    FROM indicators
)
QUALIFY row_num = 1