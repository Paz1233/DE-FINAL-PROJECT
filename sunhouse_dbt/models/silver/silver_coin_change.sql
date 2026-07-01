{{ config(
    materialized='incremental',
    incremental_strategy='append',
    catalog='iceberg',
    schema='sunhouse',
    properties={
        'location': "'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Silver/coin-change/'"
    }
) }}
WITH flattened_bronze AS (
    SELECT
        -- Parse the simple date string and append the time to meet your timestamp rule
        CAST(REPLACE(date_used, date_used, date_used || ' 00:00:00') AS TIMESTAMP(3)) AS change_date,
        
        -- Extract the raw flat rates directly from the JSON payload
        CAST(ILS_to_USD AS DOUBLE) AS ils_to_usd,
        CAST(ILS_to_EUR AS DOUBLE) AS ils_to_eur
    -- Replace 'coin_change_raw' with your actual Hive Bronze source table name
    FROM {{ source('bronze', 'raw_coin_change') }}
    WHERE date_used IS NOT NULL
)

SELECT
    b.change_date,
    t.currency_type,
    -- Handle inversion calculation cleanly while protecting against division by zero
    CASE 
        WHEN t.raw_rate = 0 THEN 0.00
        ELSE CAST(1.0 / t.raw_rate AS DECIMAL(10, 5))
    END AS coin_value
FROM flattened_bronze b
-- Multiply each row by 2 to create separate entries for USD and EUR
CROSS JOIN UNNEST(
    ARRAY['USD', 'EUR'],
    ARRAY[b.ils_to_usd, b.ils_to_eur]
) AS t(currency_type, raw_rate)
WHERE t.raw_rate IS NOT NULL