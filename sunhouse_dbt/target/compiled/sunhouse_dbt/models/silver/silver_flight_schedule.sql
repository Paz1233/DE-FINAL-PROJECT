

WITH raw_extracted AS (
    SELECT
        flightnumber,
        TRIM(departuredate) AS raw_date,
        TRIM(departuretime) AS raw_time,
        departure,
        destination,
        airline
    FROM "hive"."sunhouse"."raw_flight_schedule"
    WHERE flightnumber IS NOT NULL 
      AND departuredate IS NOT NULL
),

standardized_datetime AS (
    SELECT
        CASE
            -- DD/MM/YYYY (or DD/MM/YYYY HH:mm)
            WHEN raw_date LIKE '%/%' THEN
                CAST(
                    DATE_PARSE(
                        CONCAT(
                            SPLIT(raw_date, ' ')[1],
                            ' ',
                            CASE
                                WHEN TRY(DATE_PARSE(raw_time, '%H:%i')) IS NOT NULL
                                    THEN raw_time
                                ELSE '00:00'
                            END
                        ),
                        '%d/%m/%Y %H:%i'
                    ) AS TIMESTAMP(3)
                )

            -- YYYY-MM-DD (or YYYY-MM-DD HH:mm:ss)
            ELSE
                CAST(
                    DATE_PARSE(
                        CONCAT(
                            SPLIT(raw_date, ' ')[1],
                            ' ',
                            CASE
                                WHEN TRY(DATE_PARSE(raw_time, '%H:%i')) IS NOT NULL
                                    THEN raw_time
                                ELSE '00:00'
                            END
                        ),
                        '%Y-%m-%d %H:%i'
                    ) AS TIMESTAMP(3)
                )
        END AS full_departure_timestamp,

        flightnumber,
        departure,
        destination,
        airline
    FROM raw_extracted
),

clean_bronze AS (
    SELECT
        UPPER(REGEXP_REPLACE(TRIM(flightnumber), '[^a-zA-Z0-9]')) AS clean_flight_number,
        
        -- 2. Extract a clean string date (YYYY-MM-DD) for macro ID consistency
        CAST(CAST(full_departure_timestamp AS DATE) AS VARCHAR) AS clean_departure_date,
        
        full_departure_timestamp,
        COALESCE(UPPER(TRIM(departure)), 'UNKNOWN') AS departure_airport,
        COALESCE(UPPER(TRIM(destination)), 'UNKNOWN') AS destination_airport,
        COALESCE(UPPER(TRIM(airline)), 'UNKNOWN') AS airline_name
    FROM standardized_datetime
),

surrogate_key_generation AS (
    SELECT
        -- 3. Run macro with the pristine YYYY-MM-DD string format
        
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
        departure_airport,
        destination_airport,
        airline_name,
        full_departure_timestamp AS departure_date
    FROM clean_bronze
),

full_destination as (
    SELECT 
        s.flight_id,
        s.departure_airport,
        CASE
            WHEN s.destination_airport = 'UNKOWN' THEN b.destination
            ELSE s.destination_airport
        END AS destination_airport,
        s.airline_name,
        s.departure_date
    FROM surrogate_key_generation s
    LEFT JOIN "iceberg"."sunhouse"."silver_flight_booking" b
    ON s.flight_id = b.flight_id
)

SELECT DISTINCT * 
FROM full_destination