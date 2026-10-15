-- =====================================================================
-- Step 4: Create the RAW tables (batch load from the CSV files in S3)
-- =====================================================================
-- Column order matches the CSV files, and the header row is skipped in the file format.
-- The 4 dimension files (restaurants, users, food, menu) have an extra unnamed index
-- column at the start, so those tables begin with a throwaway _idx column.
-- The 3 fact files (orders, order_items, reviews) do not have this index column.
USE ROLE ACCOUNTADMIN;
USE DATABASE FOOD_DELIVERY;
USE SCHEMA RAW;

-- restaurants: from restaurant.csv
-- Columns in the file: id, name, city, rating, rating_count, cost, cuisine, lic_no, link, address, menu
-- I kept everything as STRING here. I will fix the data types later in dbt (Silver layer).
CREATE OR REPLACE TABLE RAW.restaurants (
  _idx          STRING,                    -- index column from the CSV, I ignore it later
  id            STRING, name        STRING, city    STRING, rating   STRING,
  rating_count  STRING, cost        STRING, cuisine STRING, lic_no   STRING,
  link          STRING, address     STRING, menu    STRING
);

-- users: from users.csv
-- Columns in the file: user_id, name, email, password, Age, Gender, Marital Status,
--                      Occupation, Monthly Income, Educational Qualifications, Family size
-- I renamed the columns with spaces to snake_case so they are easy to query.
CREATE OR REPLACE TABLE RAW.users (
  _idx STRING,                             -- index column from the CSV
  user_id STRING, name STRING, email STRING, password STRING, age STRING,
  gender STRING, marital_status STRING, occupation STRING, monthly_income STRING,
  education STRING, family_size STRING
);

-- food: from food.csv
-- Columns in the file: f_id, item, veg_or_non_veg
CREATE OR REPLACE TABLE RAW.food (
  _idx STRING,                             -- index column from the CSV
  f_id STRING, item STRING, veg_or_non_veg STRING
);

-- menu: from menu.csv
-- Columns in the file: (blank index), menu_id, r_id, f_id, cuisine, price
CREATE OR REPLACE TABLE RAW.menu (
  _idx STRING,                             -- the blank first column in the CSV
  menu_id STRING, r_id STRING, f_id STRING, cuisine STRING, price STRING
);

-- orders: from generated/orders.csv
-- This file is clean, so I used proper data types right away instead of STRING.
CREATE OR REPLACE TABLE RAW.orders (
  order_id          NUMBER,
  order_timestamp   TIMESTAMP_NTZ,
  order_date        DATE,
  user_id           NUMBER,
  r_id              NUMBER,
  restaurant_city   STRING,
  cuisine           STRING,
  items_count       NUMBER,
  sales_qty         NUMBER,
  subtotal          NUMBER,
  discount          NUMBER,
  delivery_fee      NUMBER,
  gst               NUMBER,
  sales_amount      NUMBER,
  currency          STRING,
  payment_method    STRING,
  order_status      STRING,
  customer_rating   NUMBER,
  delivery_time_min NUMBER
);

-- order_items: from generated/order_items.csv
-- One row per item in an order. This file is also clean, so I used typed columns.
CREATE OR REPLACE TABLE RAW.order_items (
  order_item_id NUMBER,
  order_id      NUMBER,
  r_id          NUMBER,
  f_id          STRING,
  price         NUMBER,
  quantity      NUMBER,
  line_amount   NUMBER
);

-- reviews: from generated/reviews.csv
-- The comment column has free text. I will use it later for the AI part (sentiment and topic).
CREATE OR REPLACE TABLE RAW.reviews (
  review_id     NUMBER,
  order_id      NUMBER,
  user_id       NUMBER,
  restaurant_id NUMBER,
  rating        NUMBER,
  comment       STRING,
  review_date   DATE
);