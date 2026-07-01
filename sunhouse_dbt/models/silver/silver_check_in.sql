{{ config(
    materialized='incremental',
    incremental_strategy='append',
    catalog='iceberg',
    schema='sunhouse',
    properties={
        'location': "'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Silver/check-in/'"
    }
) }}

WITH raw_check_in AS (
    SELECT
        -- Call your brand new macro here!
        {{ generate_flight_id('"flight number"', '"departure date"') }} AS flight_id,
        id as booking_id,
        TRIM("check in date") AS clean_check_in_date,
        TRIM("check in time") AS clean_check_in_time
    FROM {{ source('bronze', 'raw_check_in') }}
    WHERE "flight number" IS NOT NULL 
      AND "departure date" IS NOT NULL
      AND "check in date" IS NOT NULL
      AND "check in time" IS NOT NULL
),

normalized_timestamps AS (
    SELECT
        flight_id,
        booking_id,
        CASE 
            WHEN clean_check_in_time LIKE '%AM%' OR clean_check_in_time LIKE '%PM%' THEN
                CAST(DATE_PARSE(CONCAT(clean_check_in_date, ' ', clean_check_in_time), '%Y-%m-%d %h:%i %p') AS TIMESTAMP(3))
            ELSE
                CAST(DATE_PARSE(CONCAT(clean_check_in_date, ' ', clean_check_in_time), '%Y-%m-%d %H:%i') AS TIMESTAMP(3))
        END AS check_in_date
    FROM raw_check_in
)

SELECT
    flight_id,
    booking_id,
    check_in_date
FROM normalized_timestamps