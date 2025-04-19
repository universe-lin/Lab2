WITH base AS (
    SELECT * FROM {{ ref('clean_stock_prices') }}
),

moving_averages AS (
    SELECT
        ticker,
        date,
        close,
        AVG(close) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS ma_7,
        AVG(close) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) AS ma_14,
        LAG(close) OVER (
            PARTITION BY ticker
            ORDER BY date
        ) AS previous_close
    FROM base
),

price_changes AS (
    SELECT
        ticker,
        date,
        close,
        ma_7,
        ma_14,
        previous_close,
        close - previous_close AS momentum,
        CASE
            WHEN close - previous_close > 0 THEN close - previous_close
            ELSE 0
        END AS gain,
        CASE
            WHEN close - previous_close < 0 THEN ABS(close - previous_close)
            ELSE 0
        END AS loss
    FROM moving_averages
),

rsi_calc AS (
    SELECT
        ticker,
        date,
        close,
        ma_7,
        ma_14,
        momentum,
        100 - (100 / (1 + (
            AVG(gain) OVER (
                PARTITION BY ticker
                ORDER BY date
                ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
            ) / NULLIF(
                AVG(loss) OVER (
                    PARTITION BY ticker
                    ORDER BY date
                    ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
                ), 0)
        ))) AS rsi_14
    FROM price_changes
)

SELECT
    ticker,
    date,
    close,
    ma_7,
    ma_14,
    momentum,
    rsi_14
FROM rsi_calc
