{%- macro deduplicate(relation, partition_by, order_by) -%}
    {{ return(adapter.dispatch('deduplicate')(relation, partition_by, order_by)) }}
{% endmacro %}

{%- macro trino__deduplicate(relation, partition_by, order_by) -%}

    select * from (
        select
            *,
            row_number() over (
                partition by {{ partition_by }}
                order by {{ order_by }}
            ) as rn
        from {{ relation }}
    )
    where rn = 1

{%- endmacro -%}

{%- macro default__deduplicate(relation, partition_by, order_by) -%}

    with row_numbered as (
        select
            _inner.*,
            row_number() over (
                partition by {{ partition_by }}
                order by {{ order_by }}
            ) as rn
        from {{ relation }} as _inner
    )

    select
        distinct data.*
    from {{ relation }} as data
    natural join row_numbered
    where row_numbered.rn = 1

{%- endmacro -%}

{% macro redshift__deduplicate(relation, partition_by, order_by) -%}

    select *
    from {{ relation }} as tt
    qualify
        row_number() over (
            partition by {{ partition_by }}
            order by {{ order_by }}
        ) = 1

{% endmacro %}

{%- macro postgres__deduplicate(relation, partition_by, order_by) -%}

    select
        distinct on ({{ partition_by }}) *
    from {{ relation }}
    order by {{ partition_by }}{{ ',' ~ order_by }}

{%- endmacro -%}

{%- macro snowflake__deduplicate(relation, partition_by, order_by) -%}

    select *
    from {{ relation }}
    qualify
        row_number() over (
            partition by {{ partition_by }}
            order by {{ order_by }}
        ) = 1

{%- endmacro -%}

{%- macro databricks__deduplicate(relation, partition_by, order_by) -%}

    select *
    from {{ relation }}
    qualify
        row_number() over (
            partition by {{ partition_by }}
            order by {{ order_by }}
        ) = 1

{%- endmacro -%}

{%- macro bigquery__deduplicate(relation, partition_by, order_by) -%}

    select unique.*
    from (
        select
            array_agg (
                original
                order by {{ order_by }}
                limit 1
            )[offset(0)] unique
        from {{ relation }} original
        group by {{ partition_by }}
    )

{%- endmacro -%}
