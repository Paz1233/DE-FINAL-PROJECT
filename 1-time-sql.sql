CREATE TABLE hive.sunhouse.raw_payments (
      payment_id VARCHAR,
      payment_date VARCHAR,
      payment_data VARCHAR,
      batch VARCHAR
  )
  WITH (
      format = 'JSON',
      partitioned_by = ARRAY['batch'],
	  external_location = 'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Bronze/payment/'
  );
  
  CALL hive.system.sync_partition_metadata(
    schema_name => 'sunhouse', 
    table_name => 'raw_payments', 
    mode => 'ADD'
);

CREATE TABLE hive.sunhouse.raw_coin_change (
      date_used VARCHAR,
      ILS_to_USD DOUBLE,
      ILS_to_EUR DOUBLE
  )
  WITH (
      format = 'JSON',
	  external_location = 'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Bronze/coin-change/'
  );

  CREATE TABLE hive.sunhouse.raw_check_in (
      "check in date" VARCHAR,
      "check in time" VARCHAR,
      id VARCHAR,
      "flight number" VARCHAR,
      "DEPARTURE DATE" VARCHAR
  )
  WITH (
      format = 'PARQUET',
	  external_location = 'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Bronze/flight-checkin-topic/'
  );

  CREATE TABLE hive.sunhouse.raw_updates (
	  "flight number" VARCHAR,
      "departure date" VARCHAR,
      status VARCHAR,
      "new departure date" VARCHAR,
      "update time" VARCHAR
  )
  WITH (
      format = 'PARQUET',
	  external_location = 'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Bronze/flight-updates-topic/'
  );

CREATE TABLE hive.sunhouse.raw_flight_booking (
    date VARCHAR,
    booking_id VARCHAR,
    user_id VARCHAR,
    destination VARCHAR,
    F_N VARCHAR,
    D_D VARCHAR,
    passenger_count VARCHAR,
    price VARCHAR,
    booking_date VARCHAR,
    batch VARCHAR
)
WITH (
    format = 'CSV',
    partitioned_by = ARRAY['batch'],
    external_location = 'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Bronze/booking/'
);
 
CALL hive.system.sync_partition_metadata(
    schema_name => 'sunhouse',
    table_name => 'raw_flight_booking',
    mode => 'ADD'
);

CREATE TABLE hive.sunhouse.raw_flight_schedule (
    flightnumber VARCHAR,
    departuredate VARCHAR,
    departuretime VARCHAR,
    departure VARCHAR,
    destination VARCHAR,
    airline VARCHAR
)
WITH (
    format = 'PARQUET',
    external_location = 'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Bronze/flight-schedule/'
);

CREATE TABLE hive.sunhouse.raw_flights (
    date VARCHAR,
    number VARCHAR,
    departure VARCHAR,
    total_seats VARCHAR,
    fuel_consumption VARCHAR,
    fuel_price_per_liter VARCHAR,
    crew_members varchar
)
WITH (
    format = 'CSV',
    skip_header_line_count = 1 ,
    external_location = 'abfs://warehouse@dataengineering2025sa.dfs.core.windows.net/SunHouse/Bronze/flights/'
);