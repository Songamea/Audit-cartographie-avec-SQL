import glob
import os
import time

import psycopg2
from prometheus_client import Gauge, start_http_server

RAW = Gauge("datalake_raw_records", "Number of raw API records in the Data Lake")
AGGREGATED = Gauge("datalake_aggregated_records", "Number of aggregated records in the Data Lake")
CLEAN = Gauge("postgres_clean_records", "Number of clean records in PostgreSQL")


def count_lines(pattern: str) -> int:
    total = 0
    for path in glob.glob(pattern):
        with open(path, encoding="utf-8") as handle:
            total += sum(1 for _ in handle)
    return total


def main() -> None:
    start_http_server(9105)
    while True:
        RAW.set(count_lines("/data-lake/raw/api/*.jsonl"))
        AGGREGATED.set(count_lines("/data-lake/aggregated/*.jsonl"))
        try:
            with psycopg2.connect(
                host=os.getenv("POSTGRES_HOST", "postgres"),
                dbname=os.getenv("POSTGRES_DB", "transport_velo"),
                user=os.getenv("POSTGRES_USER", "audit_user"),
                password=os.getenv("POSTGRES_PASSWORD", "audit_password"),
            ) as connection, connection.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM weather_sensor_clean")
                CLEAN.set(cursor.fetchone()[0])
        except Exception:
            CLEAN.set(0)
        time.sleep(15)


if __name__ == "__main__":
    main()
