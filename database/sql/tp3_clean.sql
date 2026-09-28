\pset format csv
\pset footer off

BEGIN;

CREATE TEMP TABLE tp3_cleaning_actions (
    action text NOT NULL,
    corrected_rows bigint NOT NULL
) ON COMMIT DROP;

WITH changed AS (
    UPDATE weather_sensor_clean
    SET temperature_c = NULL
    WHERE temperature_c IS NOT NULL
      AND (
          temperature_c::text IN ('NaN', 'Infinity', '-Infinity')
          OR temperature_c < -90
          OR temperature_c > 60
      )
    RETURNING 1
)
INSERT INTO tp3_cleaning_actions
SELECT 'Set invalid temperature to NULL', COUNT(*) FROM changed;

WITH changed AS (
    UPDATE weather_sensor_clean
    SET humidity_pct = NULL
    WHERE humidity_pct IS NOT NULL
      AND (humidity_pct < 0 OR humidity_pct > 100)
    RETURNING 1
)
INSERT INTO tp3_cleaning_actions
SELECT 'Set invalid humidity to NULL', COUNT(*) FROM changed;

WITH changed AS (
    UPDATE weather_sensor_clean
    SET wind_speed_kmh = NULL
    WHERE wind_speed_kmh IS NOT NULL
      AND (
          wind_speed_kmh::text IN ('NaN', 'Infinity', '-Infinity')
          OR wind_speed_kmh < 0
      )
    RETURNING 1
)
INSERT INTO tp3_cleaning_actions
SELECT 'Set negative wind speed to NULL', COUNT(*) FROM changed;

WITH changed AS (
    UPDATE weather_sensor_clean
    SET precipitation_mm = 0
    WHERE precipitation_mm::text IN ('NaN', 'Infinity', '-Infinity')
       OR precipitation_mm < 0
    RETURNING 1
)
INSERT INTO tp3_cleaning_actions
SELECT 'Replace negative precipitation with 0', COUNT(*) FROM changed;

WITH changed AS (
    UPDATE weather_sensor_clean AS w
    SET sensor_ident = s.ident,
        sensor_type = s.type_code,
        zone = s.zone_code,
        sensor_latitude = s.latitude,
        sensor_longitude = s.longitude,
        sensor_label = s.libelle
    FROM sensor AS s
    WHERE s.gid = w.sensor_gid
      AND (
          w.sensor_ident IS DISTINCT FROM s.ident
          OR w.sensor_type IS DISTINCT FROM s.type_code
          OR w.zone IS DISTINCT FROM s.zone_code
          OR w.sensor_latitude IS DISTINCT FROM s.latitude
          OR w.sensor_longitude IS DISTINCT FROM s.longitude
          OR w.sensor_label IS DISTINCT FROM s.libelle
      )
    RETURNING 1
)
INSERT INTO tp3_cleaning_actions
SELECT 'Restore sensor metadata from canonical sensor row', COUNT(*) FROM changed;

WITH changed AS (
    UPDATE weather_sensor_clean
    SET source = btrim(source)
    WHERE source IS DISTINCT FROM btrim(source)
      AND nullif(btrim(source), '') IS NOT NULL
    RETURNING 1
)
INSERT INTO tp3_cleaning_actions
SELECT 'Trim source text', COUNT(*) FROM changed;

SELECT action, corrected_rows
FROM tp3_cleaning_actions
ORDER BY action;

COMMIT;
