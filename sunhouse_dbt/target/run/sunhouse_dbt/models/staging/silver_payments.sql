
  
    

    create table "iceberg"."sunhouse"."silver_payments"
      
      WITH (location = 'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Silver/payment/')
    as (
      

WITH raw_payment_data AS (
    SELECT
        payment_id AS payment_id,
        -- Extract last 5 characters for booking_id and cast to INT
        CAST(SUBSTRING(payment_id, -5) AS INT) AS booking_id,
        
        -- Fix the ISO timestamp string by replacing 'T' with a space, then casting to TIMESTAMP(3)
        CAST(REPLACE(payment_date, 'T', ' ') AS TIMESTAMP(3)) AS payment_date,
        
        -- Parse the raw json string text into a Trino JSON object
        JSON_PARSE(payment_data) AS json_payload
    FROM "hive"."sunhouse"."raw_payments"
    WHERE payment_id IS NOT NULL 
      AND payment_data IS NOT NULL
)
SELECT
    payment_id,
    booking_id,
    payment_date, -- Now a fully qualified timestamp containing hours/minutes
    CAST(JSON_EXTRACT_SCALAR(json_payload, '$.currency') AS VARCHAR) AS currency,
    CAST(JSON_EXTRACT_SCALAR(json_payload, '$.transaction_type') AS VARCHAR) AS transaction_type,
    CAST(JSON_EXTRACT_SCALAR(json_payload, '$.amount') AS DECIMAL(10, 2)) AS amount
FROM raw_payment_data
    );

  