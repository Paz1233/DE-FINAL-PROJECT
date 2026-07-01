insert into "iceberg"."sunhouse"."silver_check_in" ("flight_id", "booking_id", "check_in_date")
    (
        select "flight_id", "booking_id", "check_in_date"
        from "iceberg"."sunhouse"."silver_check_in__dbt_tmp"
    )

