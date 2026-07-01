{% macro generate_flight_id(flight_number_col, departure_date_col) %}
    LOWER(
        TO_HEX(
            MD5(
                CAST(
                    CONCAT(
                        UPPER(REGEXP_REPLACE(TRIM({{ flight_number_col }}), '[^a-zA-Z0-9]')),
                        '_',
                        TRIM({{ departure_date_col }})
                    ) AS VARBINARY
                )
            )
        )
    )
{% endmacro %}