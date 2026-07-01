{{ config(
    materialized='table',
    catalog='iceberg',
    schema='sunhouse',
    properties={
        'location': "'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Gold/payments/'"
    }
) }}

SELECT *
FROM {{ ref('silver_payments') }}