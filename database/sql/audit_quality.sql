\set ON_ERROR_STOP on

\if :{?phase}
\else
\echo 'Usage: psql -v phase=before|after -f audit_quality.sql'
\quit 2
\endif

INSERT INTO tp3_quality_run (phase)
VALUES (:'phase')
RETURNING run_id \gset

WITH duplicate_groups AS (
    SELECT sensor_gid, observed_at, COUNT(*) AS group_rows
    FROM weather_sensor_clean
    GROUP BY sensor_gid, observed_at
    HAVING COUNT(*) > 1
), checks AS (
    SELECT
        'required_completeness'::varchar AS check_code,
        'completeness'::varchar AS category,
        'high'::varchar AS severity,
        COUNT(*)::bigint AS checked_rows,
        COUNT(*) FILTER (
            WHERE event_id IS NULL OR observed_at IS NULL OR collected_at IS NULL
               OR source IS NULL OR sensor_gid IS NULL OR sensor_ident IS NULL
               OR sensor_type IS NULL OR zone IS NULL OR sensor_label IS NULL
        )::bigint AS anomaly_rows,
        'Null in a field required by the target schema.'::text AS description
    FROM weather_sensor_clean
    UNION ALL
    SELECT 'optional_weather_missing', 'completeness', 'low', COUNT(*)::bigint,
        COUNT(*) FILTER (
            WHERE temperature_c IS NULL OR humidity_pct IS NULL
               OR wind_speed_kmh IS NULL
        )::bigint,
        'Rows missing at least one nullable weather measure; kept because the API may omit measures.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT 'optional_count_missing', 'completeness', 'low', COUNT(*)::bigint,
        COUNT(*) FILTER (WHERE comptage_5m IS NULL)::bigint,
        'Missing bicycle count from the source inventory; not imputed because no historical measurement is available.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT 'event_id_uniqueness', 'uniqueness', 'critical', COUNT(*)::bigint,
        (COUNT(*) - COUNT(DISTINCT event_id))::bigint,
        'Duplicate technical event identifiers; the primary key should prevent these.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT 'observation_grain_duplicates', 'uniqueness', 'medium', COUNT(*)::bigint,
        COALESCE((SELECT SUM(group_rows - 1) FROM duplicate_groups), 0)::bigint,
        'Excess rows at the business grain (sensor_gid, observed_at), even when event_id differs.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT 'weather_ranges', 'validity', 'high', COUNT(*)::bigint,
        COUNT(*) FILTER (
            WHERE temperature_c < -90 OR temperature_c > 60
               OR humidity_pct < 0 OR humidity_pct > 100
               OR wind_speed_kmh < 0 OR wind_speed_kmh > 300
               OR precipitation_mm < 0 OR comptage_5m < 0
        )::bigint,
        'Temperature outside [-90, 60] C, humidity outside [0, 100] %, wind outside [0, 300] km/h, or negative precipitation/count.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT 'observation_after_collection', 'consistency', 'high', COUNT(*)::bigint,
        COUNT(*) FILTER (
            WHERE source = 'open-meteo' AND observed_at > collected_at
        )::bigint,
        'Open-Meteo current observation later than its collection time; possible timezone interpretation error.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT 'sensor_coordinates', 'validity', 'high', COUNT(*)::bigint,
        COUNT(*) FILTER (
            WHERE sensor_latitude NOT BETWEEN -90 AND 90
               OR sensor_longitude NOT BETWEEN -180 AND 180
        )::bigint,
        'Enriched sensor coordinates outside geographic bounds.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT 'sensor_reference_consistency', 'consistency', 'medium', COUNT(*)::bigint,
        COUNT(*) FILTER (
            WHERE s.gid IS NULL OR w.sensor_ident IS DISTINCT FROM s.ident
               OR w.sensor_type IS DISTINCT FROM s.type_code
               OR w.zone IS DISTINCT FROM s.zone_code
               OR w.sensor_latitude IS DISTINCT FROM s.latitude
               OR w.sensor_longitude IS DISTINCT FROM s.longitude
               OR w.sensor_label IS DISTINCT FROM s.libelle
        )::bigint,
        'Enriched sensor snapshot differs from the current sensor reference table.'
    FROM weather_sensor_clean AS w
    LEFT JOIN sensor AS s ON s.gid = w.sensor_gid
    UNION ALL
    SELECT 'source_domain', 'validity', 'medium', COUNT(*)::bigint,
        COUNT(*) FILTER (WHERE btrim(source) <> 'open-meteo')::bigint,
        'Source should be the configured Open-Meteo provider.'
    FROM weather_sensor_clean
)
INSERT INTO tp3_quality_check (
    run_id, check_code, category, severity, checked_rows, anomaly_rows, description
)
SELECT :run_id, check_code, category, severity, checked_rows, anomaly_rows, description
FROM checks;

UPDATE tp3_quality_run
SET rows_before = CASE WHEN phase = 'before'
        THEN (SELECT COUNT(*) FROM weather_sensor_clean) ELSE rows_before END,
    rows_after = CASE WHEN phase = 'after'
        THEN (SELECT COUNT(*) FROM weather_sensor_clean) ELSE rows_after END,
    finished_at = current_timestamp
WHERE run_id = :run_id;

SELECT r.run_id, r.phase, r.started_at, r.rows_before, r.rows_after,
       c.check_code, c.category, c.severity, c.checked_rows, c.anomaly_rows,
       ROUND(100.0 * c.anomaly_rows / NULLIF(c.checked_rows, 0), 2) AS anomaly_pct,
       c.description
FROM tp3_quality_run AS r
JOIN tp3_quality_check AS c USING (run_id)
WHERE r.run_id = :run_id
ORDER BY c.category, c.check_code;