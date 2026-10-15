-- =====================================================================
-- Step 3: Create the CSV file format and the external stage on S3
-- =====================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE FOOD_DELIVERY;
USE SCHEMA RAW;

-- File format: tells Snowflake how to read my CSV files.
-- I uploaded plain CSVs by hand, and they still have the header row, so I skip 1 line.
-- Review comments have commas inside them, but they are wrapped in quotes,
-- so I kept the double quote as the enclosing character.
CREATE OR REPLACE FILE FORMAT FOOD_DELIVERY.RAW.CSV_FMT
  TYPE = 'CSV'
  COMPRESSION = 'AUTO'                       -- files are not zipped now, AUTO also works if I use .gz later
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1                            -- first row is the column names, not data
  EMPTY_FIELD_AS_NULL = TRUE
  NULL_IF = ('', '\\N', 'NULL')              -- treat these values as NULL
  TRIM_SPACE = FALSE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;   -- some rows are messy (food.csv is missing a last field),
                                            -- so I let them load with NULLs instead of failing the load

-- Stage: a pointer to my S3 bucket, using the storage integration (no keys stored here).
-- Each table has its own folder under raw/:
--   raw/restaurants/  raw/users/  raw/food/  raw/menu/
--   raw/orders/  raw/order_items/  raw/reviews/
CREATE OR REPLACE STAGE FOOD_DELIVERY.RAW.FOOD_DELIVERY_RAW_STAGE
  STORAGE_INTEGRATION = FOOD_DELIVERY_S3_INT
  URL = 's3://<YOUR_BUCKET>/raw/'
  FILE_FORMAT = FOOD_DELIVERY.RAW.CSV_FMT;

-- Quick check: Snowflake should list the files from all 7 folders.
LIST @FOOD_DELIVERY.RAW.FOOD_DELIVERY_RAW_STAGE;