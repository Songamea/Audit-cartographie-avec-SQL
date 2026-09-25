import csv
import json
import math
import os
import time
from pathlib import Path

from kafka import KafkaConsumer
from prometheus_client import Counter, Gauge, start_http_server

BROKER = os.getenv("KAFKA_BROKER", "kafka:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "weather.bordeaux")
SENSORS = Path("/data-lake/raw/source2/pc_captv_p.csv")
OUTPUT = Path("/data-lake/aggregated/weather_sensors.jsonl")
RAW_OUTPUT = Path("/data-lake/raw/api/weather.jsonl")
EVENTS = Counter("aggregated_events_total", "Events enriched with sensor metadata")
SENSOR_ROWS = Gauge("sensor_inventory_rows", "Rows available in the source 2 inventory")


def load_sensors() -> list[dict]:
    if not SENSORS.exists():
        return []
    with SENSORS.open(encoding="utf-8-sig", newline="") as handle:
        sensors = list(csv.DictReader(handle, delimiter=";"))
    SENSOR_ROWS.set(len(sensors))
    return sensors


def nearest_sensor(event: dict, sensors: list[dict]) -> dict:
    def distance(sensor: dict) -> float:
        point = sensor["Geo Point"].split(",")
        return math.hypot(float(point[0]) - event["latitude"], float(point[1]) - event["longitude"])

    sensor = min(sensors, key=distance)
    point = sensor["Geo Point"].split(",")
    return {
        "sensor_gid": int(sensor["gid"]),
        "sensor_ident": sensor["ident"],
        "sensor_type": sensor["type"],
        "zone": int(sensor["zone"]),
        "sensor_latitude": float(point[0]),
        "sensor_longitude": float(point[1]),
        "sensor_label": sensor["libelle"],
        "comptage_5m": int(sensor["comptage_5m"]) if sensor["comptage_5m"].strip() else None,
    }


def main() -> None:
    start_http_server(9103)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    RAW_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    consumer = KafkaConsumer(
        TOPIC,
        bootstrap_servers=BROKER,
        group_id="data-suite-aggregator",
        auto_offset_reset="earliest",
        enable_auto_commit=True,
        value_deserializer=lambda value: json.loads(value.decode("utf-8")),
    )
    sensors = []
    while not sensors:
        sensors = load_sensors()
        if not sensors:
            time.sleep(5)
    with OUTPUT.open("a", encoding="utf-8") as output, RAW_OUTPUT.open("a", encoding="utf-8") as raw_output:
        for message in consumer:
            event = message.value
            raw_output.write(json.dumps(event) + "\n")
            raw_output.flush()
            enriched = {**event, **nearest_sensor(event, sensors)}
            output.write(json.dumps(enriched) + "\n")
            output.flush()
            EVENTS.inc()
            print(f"aggregated event_id={event['event_id']}", flush=True)


if __name__ == "__main__":
    main()
