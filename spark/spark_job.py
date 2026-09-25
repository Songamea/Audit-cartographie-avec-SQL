from __future__ import annotations

import os
import time
from pathlib import Path

import psycopg2
from pyspark.sql import SparkSession
from pyspark.sql.functions import coalesce, col, current_timestamp, lit, to_timestamp
from pyspark.sql.types import DoubleType, IntegerType
from prometheus_client import Counter, Gauge, start_http_server

INPUT = "/data-lake/aggregated/weather_sensors.jsonl"
CLEAN_DIR = "/data-lake/clean"
PROCESSED = Gauge("spark_processed_records", "Records processed by the Spark job")
LOADS = Counter("spark_loads_total", "Successful PostgreSQL loads")


def load_to_postgres(rows: list[dict]) -> None:
    if not rows:
        return
    with psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "postgres"),
        dbname=os.getenv("POSTGRES_DB", "transport_velo"),
        user=os.getenv("POSTGRES_USER", "audit_user"),
        password=os.getenv("POSTGRES_PASSWORD", "audit_password"),
    ) as connection, connection.cursor() as cursor:
        for row in rows:
            cursor.execute(
                """
                INSERT INTO weather_sensor_clean (
                    event_id, observed_at, collected_at, source, temperature_c,
                    humidity_pct, wind_speed_kmh, precipitation_mm, sensor_gid,
                    sensor_ident, sensor_type, zone, sensor_latitude,
                    sensor_longitude, sensor_label, comptage_5m
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (event_id) DO NOTHING
                """,
                tuple(
                    row.get(field)
                    for field in (
                        "event_id",
                        "observed_at",
                        "collected_at",
                        "source",
                        "temperature_c",
                        "humidity_pct",
                        "wind_speed_kmh",
                        "precipitation_mm",
                        "sensor_gid",
                        "sensor_ident",
                        "sensor_type",
                        "zone",
                        "sensor_latitude",
                        "sensor_longitude",
                        "sensor_label",
                        "comptage_5m",
                    )
                ),
            )
    LOADS.inc()


def process(spark: SparkSession) -> None:
    if not Path(INPUT).exists():
        return
    raw = spark.read.json(INPUT)
    if raw.rdd.isEmpty():
        return
    clean = (
        raw.dropDuplicates(["event_id"])
        .withColumn("observed_at", to_timestamp("observed_at"))
        .withColumn("collected_at", to_timestamp("collected_at"))
        .withColumn("temperature_c", col("temperature_c").cast(DoubleType()))
        .withColumn("humidity_pct", col("humidity_pct").cast(DoubleType()))
        .withColumn("wind_speed_kmh", col("wind_speed_kmh").cast(DoubleType()))
        .withColumn(
            "precipitation_mm",
            coalesce(col("precipitation_mm").cast(DoubleType()), lit(0.0)),
        )
        .withColumn("sensor_gid", col("sensor_gid").cast(IntegerType()))
        .withColumn("zone", col("zone").cast(IntegerType()))
        .withColumn("comptage_5m", col("comptage_5m").cast(IntegerType()))
        .withColumn("processed_at", current_timestamp())
        .dropna(subset=["event_id", "observed_at", "sensor_gid"])
    )
    clean.write.mode("overwrite").parquet(CLEAN_DIR)
    rows = [row.asDict() for row in clean.collect()]
    load_to_postgres(rows)
    PROCESSED.set(len(rows))
    print(f"spark processed={len(rows)}", flush=True)


if __name__ == "__main__":
    start_http_server(9104)
    spark = (
        SparkSession.builder.appName("DataSuiteWeatherCleaning")
        .master("local[*]")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("WARN")
    while True:
        try:
            process(spark)
        except Exception as exc:
            print(f"spark error: {exc}", flush=True)
        time.sleep(30)
