{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='flight_id',
    catalog='iceberg',
    schema='sunhouse',
    properties={
        'location': "'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Gold/flights/'"
    }
) }}

WITH latest_updates AS (

    SELECT *
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY flight_id
                ORDER BY update_time DESC
            ) AS rn
        FROM {{ ref('gold_updates') }}
    )
    WHERE rn = 1

)

SELECT
    fs.flight_id,
    fs.flight_number,
    fs.departure_date,
    fs.departure_airport,
    fs.destination_airport,
    fs.airline_name,

    f.total_seats,
    f.fuel_consumption,
    f.fuel_price_per_liter,
    f.crew_members,

    u.status,
    u.update_time,
    u.new_departure_date

FROM {{ ref('silver_flight_schedule') }} fs

LEFT JOIN {{ ref('silver_flights') }} f
    ON f.flight_id = fs.flight_id

LEFT JOIN latest_updates u
    ON u.flight_id = fs.flight_id