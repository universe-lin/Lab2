SELECT
    SYMBOL AS ticker,
    DATE AS date,
    OPEN AS open,
    CLOSE AS close,
    HIGH AS high,
    LOW AS low,
    VOLUME AS volume
FROM {{ source('raw', 'stock_prices') }}
WHERE CLOSE IS NOT NULL
