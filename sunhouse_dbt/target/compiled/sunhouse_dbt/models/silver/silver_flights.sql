

WITH raw_coalesced AS (
    SELECT
        UPPER(REGEXP_REPLACE(TRIM(number), '[^a-zA-Z0-9]')) AS clean_flight_number,
        
        COALESCE(
            NULLIF(TRIM(departure), ''), 
            NULLIF(TRIM(date), '')
        ) AS raw_date_string,
        
        TRY_CAST(TRIM(fuel_consumption) AS INT) AS fuel_consumption,
        TRY_CAST(TRIM(fuel_price_per_liter) AS DECIMAL(10, 4)) AS fuel_price_per_liter,
        TRY_CAST(TRIM(crew_members) AS INT) AS crew_members
    FROM "hive"."sunhouse"."raw_flights"
    WHERE number IS NOT NULL 
      AND (departure IS NOT NULL OR date IS NOT NULL)
),

standardized_date AS (
    SELECT
        clean_flight_number,
        fuel_consumption,
        fuel_price_per_liter,
        crew_members,
        
        -- 2. Safely cast the timestamp string to a pure DATE, then to a standard VARCHAR (YYYY-MM-DD)
        -- This strips out any 'T' or time components like '00:00:00' flawlessly
        CAST(
            CAST(
                CASE 
                    WHEN raw_date_string LIKE '%T%' THEN CAST(REPLACE(raw_date_string, 'T', ' ') AS TIMESTAMP(3))
                    WHEN raw_date_string LIKE '%:%' THEN CAST(raw_date_string AS TIMESTAMP(3))
                    ELSE CAST(DATE_PARSE(raw_date_string, '%Y-%m-%d') AS TIMESTAMP(3))
                END AS DATE
            ) AS VARCHAR
        ) AS clean_departure_date
    FROM raw_coalesced
),

flights_with_ids AS (
    SELECT
        -- 3. Now the macro receives a pristine, uniform 'YYYY-MM-DD' string, guaranteeing matching IDs!
        
    LOWER(
        TO_HEX(
            MD5(
                CAST(
                    CONCAT(
                        UPPER(REGEXP_REPLACE(TRIM(clean_flight_number), '[^a-zA-Z0-9]')),
                        '_',
                        TRIM(clean_departure_date)
                    ) AS VARBINARY
                )
            )
        )
    )
 AS flight_id,
        clean_flight_number AS flight_number,
        CAST(CONCAT(clean_departure_date, ' 00:00:00') AS TIMESTAMP(3)) AS departure_timestamp,
        fuel_consumption,
        fuel_price_per_liter,
        crew_members
    FROM standardized_date
),

booked_seats_agg AS (
    SELECT
        flight_id,
        SUM(passenger_count) AS actual_total_seats
    FROM "iceberg"."sunhouse"."silver_flight_booking"
    GROUP BY flight_id
)

SELECT
    f.flight_id,
    f.flight_number,
    f.departure_timestamp,
    COALESCE(b.actual_total_seats, 0) AS total_seats,
    f.fuel_consumption,
    f.fuel_price_per_liter,
    f.crew_members
FROM flights_with_ids f
LEFT JOIN booked_seats_agg b 
    ON f.flight_id = b.flight_id