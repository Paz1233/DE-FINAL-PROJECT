

WITH clean_bronze AS (
    SELECT
        -- Basic cleans on IDs
        CAST(REGEXP_REPLACE(booking_id, '[^0-9]') AS INT) AS booking_id,
        CAST(REGEXP_REPLACE(user_id, '[^0-9]') AS INT) AS user_id,
        UPPER(TRIM(destination)) AS destination,
        
        -- Clean up Flight Number for consistency
        UPPER(REGEXP_REPLACE(TRIM(F_N), '[^a-zA-Z0-9]')) AS clean_flight_number,

        -- Handle problematic D_D (Departure Date) variations safely
        CASE 
            -- Scenario A: Date is in YYYY-MM-DD format
            WHEN REGEXP_LIKE(TRIM(D_D), '^\d{4}-\d{2}-\d{2}$') THEN 
                TRIM(D_D)
            -- Scenario B: Date is in DD-MM-YYYY format (flip it to YYYY-MM-DD)
            WHEN REGEXP_LIKE(TRIM(D_D), '^\d{2}-\d{2}-\d{4}$') THEN 
                CAST(DATE_PARSE(TRIM(D_D), '%d-%m-%Y') AS VARCHAR)
            -- Scenario C: Date uses slashes YYYY/MM/DD
            WHEN REGEXP_LIKE(TRIM(D_D), '^\d{4}/\d{2}/\d{2}$') THEN 
                REPLACE(TRIM(D_D), '/', '-')
            -- Catch-all for corrupt text strings like 'NULL', 'NA', or blanks
            ELSE NULL 
        END AS clean_departure_date,

        -- Cast financial/numeric metrics safely
        TRY_CAST(TRIM(passenger_count) AS INT) AS passenger_count,
        TRY_CAST(TRIM(price) AS DECIMAL(10, 2)) AS price,
        
        -- Handle booking date formatting
        TRIM(booking_date) AS raw_booking_date
    FROM "hive"."sunhouse"."raw_flight_booking"
    WHERE F_N IS NOT NULL 
      AND D_D IS NOT NULL
),

surrogate_key_generation AS (
    SELECT
        -- Now we apply our macro onto the safely cleaned business keys
        
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
        booking_id,
        user_id,
        destination,
        passenger_count,
        price,
        -- Assuming booking_date might be an ISO string or standard timestamp string
        CAST(REPLACE(raw_booking_date, 'T', ' ') AS TIMESTAMP(3)) AS booking_date
    FROM clean_bronze
    -- Drop rows where the departure date was corrupt beyond repair
    WHERE clean_departure_date IS NOT NULL 
)

SELECT
    booking_id,
    user_id,
    flight_id,
    destination,
    passenger_count,
    price,
    booking_date
FROM surrogate_key_generation