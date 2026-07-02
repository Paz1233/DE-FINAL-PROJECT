
  
    

    create table "iceberg"."sunhouse"."gold_booking"
      
      WITH (location = 'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Gold/bookings/')
    as (
      

WITH booking AS (

    SELECT *
    FROM "iceberg"."sunhouse"."silver_flight_booking"

),

checkin AS (

    SELECT
        CAST(booking_id AS INTEGER) AS booking_id,
        check_in_date
    FROM "iceberg"."sunhouse"."silver_check_in"
    GROUP BY booking_id, check_in_date

),

rates AS (

    SELECT
        change_date,
        currency_type,
        coin_value
    FROM "iceberg"."sunhouse"."silver_coin_change"

),

payments AS (

    SELECT
        booking_id,
        COUNT(*) AS num_of_payments
    FROM "iceberg"."sunhouse"."silver_payments"
    GROUP BY booking_id

)

SELECT

    b.booking_id,
    b.user_id,
    b.flight_id,
    b.passenger_count,
    b.currency_type as original_currency_type,

    b.booking_date,

    c.check_in_date,

    ROUND(
        b.price * COALESCE(r.coin_value,1),
        2
    ) AS flight_price_ils,

    COALESCE(p.num_of_payments,0) AS num_of_payments,

    date_diff(
        'minute',
        c.check_in_date,
        f.departure_date
    ) AS checkin_to_departure_minutes,

    date_diff(
        'hour',
        b.booking_date,
        c.check_in_date
    ) AS from_booking_to_check_in_hours,

    f.destination_airport as destination

FROM booking b

LEFT JOIN checkin c
    ON b.booking_id = c.booking_id

LEFT JOIN rates r
    ON r.currency_type = b.currency_type
   AND r.change_date = CAST(b.booking_date AS DATE)

LEFT JOIN payments p
    ON p.booking_id = b.booking_id

LEFT JOIN "iceberg"."sunhouse"."gold_flights" f
    ON b.flight_id = f.flight_id


    );

  