CREATE TABLE IF NOT EXISTS weather_sensor_clean (
    event_id uuid PRIMARY KEY,
    observed_at timestamptz NOT NULL,
    collected_at timestamptz NOT NULL,
    source varchar(80) NOT NULL,
    temperature_c numeric(6,2),
    humidity_pct numeric(6,2),
    wind_speed_kmh numeric(8,2),
    precipitation_mm numeric(8,2) NOT NULL DEFAULT 0,
    sensor_gid integer NOT NULL REFERENCES sensor(gid),
    sensor_ident varchar(30) NOT NULL,
    sensor_type varchar(30) NOT NULL,
    zone integer NOT NULL,
    sensor_latitude numeric(10,7) NOT NULL,
    sensor_longitude numeric(10,7) NOT NULL,
    sensor_label text NOT NULL,
    comptage_5m integer CHECK (comptage_5m IS NULL OR comptage_5m >= 0),
    processed_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS weather_sensor_observed_idx ON weather_sensor_clean(observed_at);
CREATE INDEX IF NOT EXISTS weather_sensor_zone_idx ON weather_sensor_clean(zone);
