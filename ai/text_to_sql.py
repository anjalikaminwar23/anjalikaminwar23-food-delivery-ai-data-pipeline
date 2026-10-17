import os
import json
import re

import pandas as pd
import streamlit as st
import snowflake.connector
from google import genai
from google.genai import types
from dotenv import load_dotenv

load_dotenv()

MODEL = "gemini-3.5-flash-lite"

EXAMPLE_QUESTIONS = [
    "Top 10 cities by GMV",
    "Which cuisine has the most orders?",
    "Average delivery time by city, worst first",
    "Cancel rate by payment method",
]

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

SCHEMA = """
Tables available in Snowflake. Use bare table names, no database or schema prefix.

FCT_ORDERS(order_id, order_date, customer_id, restaurant_id, city, cuisine,
           payment_method, order_status, is_delivered, sales_amount, discount,
           delivery_fee, gst, customer_rating, delivery_time_min)

DIM_RESTAURANT(restaurant_id, restaurant_name, city, cuisine, rating, cost_for_two)

DIM_CUSTOMER(customer_id, customer_name, age, age_segment, gender, city)

MART_DAILY_CITY_REVENUE(order_date, city, orders, cancel_rate, gmv, aov)

MART_RESTAURANT_PERFORMANCE(restaurant_id, restaurant_name, city, cuisine,
                            orders, revenue, avg_customer_rating, cancel_rate)

MART_DELIVERY_SLA(city, order_hour, delivered_orders, p50_delivery_min, late_rate)

Note: GMV means delivered revenue. Prefer MART_ tables when they fit the question.
"""

SYSTEM_PROMPT = f"""
You are a Snowflake SQL expert. Generate exactly one read-only SQL query
that answers the user's question.

Rules:
- Generate only a SELECT query or a WITH ... SELECT query.
- Never modify data or execute DDL/DML.
- Use bare table names, without database or schema prefixes.
- Add LIMIT 100 or less, unless the question asks for a single total.
- Prefer MART_ tables when appropriate.
- Use only the tables and columns listed in the schema.
- Return valid JSON in this exact format:
  {{"sql": "your query here"}}

Schema:
{SCHEMA}
"""


@st.cache_resource
def get_connection():
    return snowflake.connector.connect(
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        user=os.getenv("SNOWFLAKE_USER"),
        password=os.getenv("SNOWFLAKE_PASSWORD"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
        database=os.getenv("SNOWFLAKE_DATABASE"),
        schema="MARTS",
        role="DBT_ROLE",
    )


def generate_sql(question):
    response = client.models.generate_content(
        model=MODEL,
        contents=question,
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            temperature=0,
            response_mime_type="application/json",
        ),
    )

    answer = json.loads(response.text)
    sql = answer.get("sql", "").strip()

    # Remove optional database/schema prefixes.
    sql = re.sub(
        r"(?i)\bFOOD_DELIVERY\.(?:MARTS|STAGING|RAW)\.",
        "",
        sql,
    )

    return sql.rstrip(";").strip()


def is_safe(sql):
    # Allow only a single SELECT or WITH statement.
    sql = sql.strip()

    if not re.match(r"(?is)^(SELECT|WITH)\b", sql):
        return False

    # Reject multiple statements.
    if ";" in sql:
        return False

    # Reject SQL comments to reduce opportunities to bypass checks.
    if "--" in sql or "/*" in sql or "*/" in sql:
        return False

    # Reject common write/DDL operations as SQL keywords.
    forbidden = re.compile(
        r"\b(INSERT|UPDATE|DELETE|DROP|TRUNCATE|ALTER|CREATE|"
        r"REPLACE|GRANT|REVOKE|MERGE|CALL|EXECUTE|COPY|"
        r"PUT|REMOVE|UNDROP)\b",
        re.IGNORECASE,
    )

    if forbidden.search(sql):
        return False

    return True


def run_query(sql):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(sql)
        return cursor.fetch_pandas_all()
    finally:
        cursor.close()


st.title("Chat with your Food delivery Data")
st.caption(f"Ask in English; Gemini ({MODEL}) writes SQL and Snowflake runs it.")

with st.sidebar:
    st.header("Example Questions")
    for q in EXAMPLE_QUESTIONS:
        st.markdown(f"- {q}")

question = st.text_input(
    "Enter your question here",
    placeholder="e.g. Top 10 restaurants by revenue in Bangalore",
)

if question:
    try:
        sql = generate_sql(question)
        st.code(sql, language="sql")

        if not is_safe(sql):
            st.error("The generated SQL failed the safety checks.")
        else:
            df = run_query(sql)

            st.success(f"{len(df)} rows returned")
            st.dataframe(df, hide_index=True)

            if (
                len(df.columns) == 2
                and pd.api.types.is_numeric_dtype(df.iloc[:, 1])
            ):
                st.bar_chart(
                    df,
                    x=df.columns[0],
                    y=df.columns[1],
                )

    except Exception as e:
        st.error(f"Error: {e}")