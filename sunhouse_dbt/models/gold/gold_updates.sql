{{ config(
    materialized='table',
    catalog='iceberg',
    schema='sunhouse',
    properties={
        'location': "'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Gold/updates/'"
    }
) }}

SELECT *
FROM {{ ref('silver_updates') }}