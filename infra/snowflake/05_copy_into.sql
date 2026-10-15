-- =====================================================================
-- Step 5: Load the RAW tables from S3 using COPY INTO
-- =====================================================================
-- This loads the CSV files I uploaded into each raw/<table>/ folder.
-- The header row is skipped by the file format (SKIP_HEADER = 1),
-- and the columns are loaded by position, not by name.
USE ROLE ACCOUNTADMIN;
USE DATABASE FOOD_DELIVERY;
USE SCHEMA RAW;
USE WAREHOUSE FOOD_DELIVERY_WH;

-- Dimension tables: this is messy real-world data, so I use CONTINUE.
-- Bad rows get skipped and the load keeps going instead of failing.
COPY INTO RAW.restaurants FROM @FOOD_DELIVERY_RAW_STAGE/restaurants/  ON_ERROR = 'CONTINUE';
COPY INTO RAW.users       FROM @FOOD_DELIVERY_RAW_STAGE/users/        ON_ERROR = 'CONTINUE';
COPY INTO RAW.food        FROM @FOOD_DELIVERY_RAW_STAGE/food/         ON_ERROR = 'CONTINUE';
COPY INTO RAW.menu        FROM @FOOD_DELIVERY_RAW_STAGE/menu/         ON_ERROR = 'CONTINUE';
-- Fact tables: this data is clean and generated, so I keep it strict.
-- If any row is bad, the load stops, so the row counts stay exact.
COPY INTO RAW.orders      FROM @FOOD_DELIVERY_RAW_STAGE/orders/       ON_ERROR = 'ABORT_STATEMENT';
COPY INTO RAW.order_items FROM @FOOD_DELIVERY_RAW_STAGE/order_items/  ON_ERROR = 'ABORT_STATEMENT';
COPY INTO RAW.reviews     FROM @FOOD_DELIVERY_RAW_STAGE/reviews/      ON_ERROR = 'ABORT_STATEMENT';

-- Sanity check: count the rows in every table after the load.
SELECT 'restaurants' t, COUNT(*) n FROM RAW.restaurants
UNION ALL SELECT 'users',       COUNT(*) FROM RAW.users
UNION ALL SELECT 'food',        COUNT(*) FROM RAW.food
UNION ALL SELECT 'menu',        COUNT(*) FROM RAW.menu
UNION ALL SELECT 'orders',      COUNT(*) FROM RAW.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM RAW.order_items
UNION ALL SELECT 'reviews',     COUNT(*) FROM RAW.reviews
ORDER BY t;
-- What I expect: orders = 10,000,000, order_items about 23,000,000, restaurants about 148,541.

-- ---------------------------------------------------------------------
-- Optional, not used now: auto-load new files with Snowpipe.
-- I may try this later if I want files to load as soon as they land in S3.
-- CREATE PIPE RAW.orders_pipe AUTO_INGEST = TRUE AS
--   COPY INTO RAW.orders FROM @FOOD_DELIVERY_RAW_STAGE/orders/;
-- Then connect the pipe's SQS ARN to an S3 event notification.
-- ---------------------------------------------------------------------