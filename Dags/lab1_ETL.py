from airflow import DAG
from airflow.models import Variable
from airflow.decorators import task
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

from datetime import timedelta
from datetime import datetime
import snowflake.connector
import requests
import yfinance as yf
import pandas as pd
from typing import List, Dict

def return_snowflake_conn():
    hook = SnowflakeHook(snowflake_conn_id='snowflake_conn_lemur')
    conn = hook.get_conn()
    return conn.cursor()

@task
def extract(stock_symbols)->Dict:
    stock_data = {}
    for symbol in stock_symbols:
        df = yf.download(symbol, period='180d')   
        stock_data[symbol] = df

    return stock_data

@task
def transform(stock_data:List):
    records = []
    for symbol, df in stock_data.items():
        df.columns = df.columns.droplevel(1)
        df.reset_index(inplace=True)  
        for _, row in df.iterrows():
            records.append([
                symbol,
                row['Date'].strftime('%Y-%m-%d'),
                row['Open'],
                row['Close'],
                row['High'],
                row['Low'],
                row['Volume']
            ])
    return records

@task
def load(cur, records, target_table):
    print(f'{len(records)} records found')

    try:
        cur.execute("BEGIN;")
        cur.execute(f"""
            CREATE TABLE IF NOT EXISTS {target_table} (
                SYMBOL VARCHAR,
                DATE DATE,
                OPEN FLOAT,
                CLOSE FLOAT,
                HIGH FLOAT,
                LOW FLOAT,
                VOLUME INT,
                PRIMARY KEY (SYMBOL, DATE)
            );
        """)
        cur.execute(f"DELETE FROM {target_table}")
        for r in records:
            sql = f"""
                INSERT INTO {target_table} (SYMBOL, DATE, OPEN, CLOSE, HIGH, LOW, VOLUME)
                VALUES ('{r[0]}', '{r[1]}', {r[2]}, {r[3]}, {r[4]}, {r[5]}, {r[6]})
            """
            cur.execute(sql)
        cur.execute("COMMIT;")
    except Exception as e:
        cur.execute("ROLLBACK;")
        print(e)
        raise e

with DAG(
    dag_id='lab1StockETL',
    start_date=datetime(2024, 2, 27),
    catchup=False,
    tags=['ETL'],
    schedule='30 2 * * *'
) as dag:
    target_table = "USER_DB_LEMUR.raw.stock_prices"
    stock_symbols = ["NVDA", "AAPL"]
    cur = return_snowflake_conn()

    data = extract(stock_symbols)
    transformed_data = transform(data)
    load(cur, transformed_data, target_table)