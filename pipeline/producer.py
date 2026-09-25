import json
import os
import time
import uuid
from datetime import datetime, timezone

import requests
from kafka import KafkaProducer
from prometheus_client import Counter, start_http_server

KAFKA_BROKER = os.getenv("KAFKA_BROKER", "kafka:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "weather.bordeaux")
INTERVAL = int(os.getenv("POLL_INTERVAL_SECONDS", "30"))
API_URL = "https://api.open-meteo.com/v1/forecast"
EVENTS = Counter("api_events_total", "Weather events published to Kafka")
ERRORS = Counter("api_errors_total", "Weather API errors")


def fetch_weather() -> dict:
    response = requests.get(
        API_URL,
        params={
            "latitude": 44.8378,
            "longitude": -0.5792,
            "current": "temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation",
            "timezone": "Europe/Paris",
        },
        timeout=15,
    )
    response.raise_for_status()
    payload = response.json()
    current = payload["current"]
    return {
        "event_id": str(uuid.uuid4()),
        "collected_at": datetime.now(timezone.utc).isoformat(),
        "source": "open-meteo",
        "latitude": 44.8378,
        "longitude": -0.5792,
        "observed_at": current["time"],
        "temperature_c": current.get("temperature_2m"),
        "humidity_pct": current.get("relative_humidity_2m"),
        "wind_speed_kmh": current.get("wind_speed_10m"),
        "precipitation_mm": current.get("precipitation"),
    }


def main() -> None:
    start_http_server(9101)
    producer = KafkaProducer(
        bootstrap_servers=KAFKA_BROKER,
        value_serializer=lambda value: json.dumps(value).encode("utf-8"),
        retries=10,
    )
    while True:
        try:
            event = fetch_weather()
            producer.send(TOPIC, value=event).get(timeout=15)
            EVENTS.inc()
            print(f"published event_id={event['event_id']} observed_at={event['observed_at']}", flush=True)
        except Exception as exc:
            ERRORS.inc()
            print(f"collection error: {exc}", flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
