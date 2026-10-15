-- =====================================================================
-- Phase 2 · Step 1 — Warehouse, database, schemas, role
-- Run in Snowsight as ACCOUNTADMIN (a worksheet).
-- =====================================================================
USE ROLE ACCOUNTADMIN;

-- Compute: extra-small, auto-suspend fast so the trial credits last.
CREATE WAREHOUSE IF NOT EXISTS FOOD_DELIVERY_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND   = 60
  AUTO_RESUME    = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- Database + medallion schemas.
CREATE DATABASE IF NOT EXISTS FOOD_DELIVERY;
CREATE SCHEMA  IF NOT EXISTS FOOD_DELIVERY.BRONZE;    -- Iceberg tables Spark wrote (dbt sources)
CREATE SCHEMA  IF NOT EXISTS FOOD_DELIVERY.RAW;       -- only used by the COPY fallback path
CREATE SCHEMA  IF NOT EXISTS FOOD_DELIVERY.STAGING;   -- cleaned / conformed (dbt)
CREATE SCHEMA  IF NOT EXISTS FOOD_DELIVERY.MARTS;     -- Gold, Iceberg (dbt)
CREATE SCHEMA  IF NOT EXISTS FOOD_DELIVERY.SNAPSHOTS; -- SCD2 history (dbt)
CREATE SCHEMA  IF NOT EXISTS FOOD_DELIVERY.AI;        -- LLM-enriched tables (OpenAI jobs)

-- A role dbt/Airflow will use.
CREATE ROLE IF NOT EXISTS DBT_ROLE;
GRANT USAGE   ON WAREHOUSE FOOD_DELIVERY_WH TO ROLE DBT_ROLE;
GRANT OPERATE ON WAREHOUSE FOOD_DELIVERY_WH TO ROLE DBT_ROLE;
GRANT ALL     ON DATABASE  FOOD_DELIVERY    TO ROLE DBT_ROLE;
GRANT ALL     ON ALL SCHEMAS IN DATABASE FOOD_DELIVERY TO ROLE DBT_ROLE;
GRANT ALL     ON FUTURE SCHEMAS IN DATABASE FOOD_DELIVERY TO ROLE DBT_ROLE;
GRANT ALL     ON FUTURE TABLES IN DATABASE FOOD_DELIVERY TO ROLE DBT_ROLE;
GRANT ALL     ON FUTURE VIEWS  IN DATABASE FOOD_DELIVERY TO ROLE DBT_ROLE;

-- Let your login use the role (replace with your Snowflake username).
SET my_user = CURRENT_USER();
GRANT ROLE DBT_ROLE TO USER IDENTIFIER($my_user);

SELECT 'setup complete' AS status;