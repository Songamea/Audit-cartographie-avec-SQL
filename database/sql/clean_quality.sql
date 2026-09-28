\set ON_ERROR_STOP on

BEGIN;

INSERT INTO tp3_quality_run (phase, rows_before)
VALUES ('cleaning', (SELECT COUNT(*) FROM weather_sensor_clean))
RETURNING run_id \gset

DROP INDEX IF EXISTS weather_sensor_clean_grain_uidx;

INSERT INTO tp3_quality_correction (
    run_id, event_id, rule_code, old_values, new_values
)
SELECT :run_id, event_id, 'OPEN_METEO_LOCAL_TIME_TO_UTC',
       jsonb_build_object('observed_at', observed_at),
       jsonb_build_object(
           'observed_at', (observed_at AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Paris'
       )
FROM weather_sensor_clean
WHERE source = 'open-meteo' AND observed_at > collected_at;

UPDATE weather_sensor_clean AS w
SET observed_at = (w.observed_at AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Paris'
WHERE w.source = 'open-meteo' AND w.observed_at > w.collected_at;

INSERT INTO tp3_quality_correction (
    run_id, event_id, rule_code, old_values, new_values
)
SELECT :run_id, w.event_id, 'SENSOR_REFERENCE_REFRESH',
       jsonb_build_object(
           'sensor_ident', w.sensor_ident, 'sensor_type', w.sensor_type,
           'zone', w.zone, 'sensor_latitude', w.sensor_latitude,
           'sensor_longitude', w.sensor_longitude, 'sensor_label', w.sensor_label
       ),
       jsonb_build_object(
           'sensor_ident', s.ident, 'sensor_type', s.type_code,
           'zone', s.zone_code, 'sensor_latitude', s.latitude,
           'sensor_longitude', s.longitude, 'sensor_label', s.libelle
       )
FROM weather_sensor_clean AS w
JOIN sensor AS s ON s.gid = w.sensor_gid
WHERE w.sensor_ident IS DISTINCT FROM s.ident
   OR w.sensor_type IS DISTINCT FROM s.type_code
   OR w.zone IS DISTINCT FROM s.zone_code
   OR w.sensor_latitude IS DISTINCT FROM s.latitude
   OR w.sensor_longitude IS DISTINCT FROM s.longitude
   OR w.sensor_label IS DISTINCT FROM s.libelle;

UPDATE weather_sensor_clean AS w
SET sensor_ident = s.ident,
    sensor_type = s.type_code,
    zone = s.zone_code,
    sensor_latitude = s.latitude,
    sensor_longitude = s.longitude,
    sensor_label = s.libelle
FROM sensor AS s
WHERE s.gid = w.sensor_gid
  AND (w.sensor_ident IS DISTINCT FROM s.ident
       OR w.sensor_type IS DISTINCT FROM s.type_code
       OR w.zone IS DISTINCT FROM s.zone_code
       OR w.sensor_latitude IS DISTINCT FROM s.latitude
       OR w.sensor_longitude IS DISTINCT FROM s.longitude
       OR w.sensor_label IS DISTINCT FROM s.libelle);

INSERT INTO tp3_quality_quarantine
SELECT w.*, 'INVALID_WEATHER_RANGE', current_timestamp, :run_id
FROM weather_sensor_clean AS w
WHERE w.temperature_c < -90 OR w.temperature_c > 60
   OR w.humidity_pct < 0 OR w.humidity_pct > 100
   OR w.wind_speed_kmh < 0 OR w.wind_speed_kmh > 300
   OR w.precipitation_mm < 0 OR w.comptage_5m < 0
ON CONFLICT (event_id) DO NOTHING;

DELETE FROM weather_sensor_clean AS w
WHERE (w.temperature_c < -90 OR w.temperature_c > 60
    OR w.humidity_pct < 0 OR w.humidity_pct > 100
    OR w.wind_speed_kmh < 0 OR w.wind_speed_kmh > 300
    OR w.precipitation_mm < 0 OR w.comptage_5m < 0)
  AND EXISTS (
      SELECT 1 FROM tp3_quality_quarantine AS q
      WHERE q.event_id = w.event_id
        AND q.quarantine_reason = 'INVALID_WEATHER_RANGE'
  );

INSERT INTO tp3_quality_quarantine
SELECT w.*, 'UNRESOLVED_FUTURE_OBSERVATION', current_timestamp, :run_id
FROM weather_sensor_clean AS w
WHERE w.source = 'open-meteo' AND w.observed_at > w.collected_at
ON CONFLICT (event_id) DO NOTHING;

DELETE FROM weather_sensor_clean AS w
WHERE w.source = 'open-meteo' AND w.observed_at > w.collected_at
  AND EXISTS (
      SELECT 1 FROM tp3_quality_quarantine AS q
      WHERE q.event_id = w.event_id
        AND q.quarantine_reason = 'UNRESOLVED_FUTURE_OBSERVATION'
  );

WITH ranked AS (
    SELECT event_id,
           ROW_NUMBER() OVER (
               PARTITION BY sensor_gid, observed_at
               ORDER BY collected_at DESC, processed_at DESC, event_id DESC
           ) AS row_number
    FROM weather_sensor_clean
)
INSERT INTO tp3_quality_quarantine
SELECT w.*, 'DUPLICATE_SENSOR_OBSERVATION', current_timestamp, :run_id
FROM weather_sensor_clean AS w
JOIN ranked AS r USING (event_id)
WHERE r.row_number > 1
ON CONFLICT (event_id) DO NOTHING;

WITH ranked AS (
    SELECT event_id,
           ROW_NUMBER() OVER (
               PARTITION BY sensor_gid, observed_at
               ORDER BY collected_at DESC, processed_at DESC, event_id DESC
           ) AS row_number
    FROM weather_sensor_clean
)
DELETE FROM weather_sensor_clean AS w
USING ranked AS r, tp3_quality_quarantine AS q
WHERE w.event_id = r.event_id
  AND r.row_number > 1
  AND q.event_id = w.event_id
  AND q.quarantine_reason = 'DUPLICATE_SENSOR_OBSERVATION';

INSERT INTO tp3_quality_exclusion (event_id, quarantine_reason, quality_run_id)
SELECT event_id, quarantine_reason, quality_run_id
FROM tp3_quality_quarantine
ON CONFLICT (event_id) DO NOTHING;

CREATE UNIQUE INDEX weather_sensor_clean_grain_uidx
        ON weather_sensor_clean (sensor_gid, observed_at);

UPDATE tp3_quality_run
SET rows_after = (SELECT COUNT(*) FROM weather_sensor_clean),
    finished_at = current_timestamp
WHERE run_id = :run_id;

COMMIT;

SELECT run_id, phase, rows_before, rows_after,
       rows_before - rows_after AS removed_from_target, started_at, finished_at
FROM tp3_quality_run
WHERE run_id = :run_id;

SELECT quarantine_reason, COUNT(*) AS quarantined_rows
FROM tp3_quality_quarantine
WHERE quality_run_id = :run_id
GROUP BY quarantine_reason
ORDER BY quarantine_reason;

SELECT rule_code, COUNT(*) AS corrected_rows
FROM tp3_quality_correction
WHERE run_id = :run_id
GROUP BY rule_code
ORDER BY rule_code;