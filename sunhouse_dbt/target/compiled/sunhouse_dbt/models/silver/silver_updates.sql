

WITH raw_check_in AS (
    SELECT
        -- Call your brand new macro here!
        
    LOWER(
        TO_HEX(
            MD5(
                CAST(
                    CONCAT(
                        UPPER(REGEXP_REPLACE(TRIM("flight number"), '[^a-zA-Z0-9]')),
                        '_',
                        TRIM("departure date")
                    ) AS VARBINARY
                )
            )
        )
    )
 AS flight_id,
        UPPER(TRIM(status)) as status,
        CAST(REPLACE(TRIM("new departure date"), 'T', ' ') AS TIMESTAMP(3)) AS new_departure_date,
        CAST(REPLACE(TRIM("update time"), 'T', ' ') AS TIMESTAMP(3)) AS update_time
    FROM "hive"."sunhouse"."raw_updates"
    WHERE "flight number" IS NOT NULL 
      AND "departure date" IS NOT NULL
      AND "new departure date" IS NOT NULL
      AND "update time" IS NOT NULL
)

SELECT
    flight_id,
    status,
    new_departure_date,
    update_time
FROM raw_check_in