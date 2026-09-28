\pset format csv
\pset tuples_only off
\pset footer off

WITH table_stats AS (
    SELECT COUNT(*)::bigint AS checked_rows
    FROM weather_sensor_clean
),
checks AS (
    SELECT
        'Completeness'::text AS category,
        'Required fields missing or blank'::text AS control_name,
        COUNT(*) FILTER (
            WHERE event_id IS NULL
               OR observed_at IS NULL
               OR collected_at IS NULL
               OR nullif(btrim(source), '') IS NULL
               OR sensor_gid IS NULL
               OR nullif(btrim(sensor_ident), '') IS NULL
               OR nullif(btrim(sensor_type), '') IS NULL
               OR zone IS NULL
               OR sensor_latitude IS NULL
               OR sensor_longitude IS NULL
               OR nullif(btrim(sensor_label), '') IS NULL
               OR processed_at IS NULL
        )::bigint AS issue_count,
        'HIGH'::text AS severity,
        'Required columns should be populated; metadata is repaired from sensor when possible.'::text AS policy
    FROM weather_sensor_clean
    UNION ALL
    SELECT
        'Completeness',
        'Optional weather fields missing (informational)',
        COUNT(*) FILTER (
            WHERE temperature_c IS NULL
               OR humidity_pct IS NULL
               OR wind_speed_kmh IS NULL
        )::bigint,
        'INFO',
        'Weather fields are optional; absence is reported, not imputed.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT
        'Uniqueness',
        'Duplicate event_id',
        COUNT(*)::bigint,
        'HIGH',
        'event_id is the primary key; duplicates are also prevented by PostgreSQL.'
    FROM (
        SELECT event_id
        FROM weather_sensor_clean
        GROUP BY event_id
        HAVING COUNT(*) > 1
    ) AS duplicates
    UNION ALL
    SELECT
        'Validity',
        'Temperature outside -90..60 C',
        COUNT(*) FILTER (
            WHERE temperature_c IS NOT NULL
              AND (
                  temperature_c::text IN ('NaN', 'Infinity', '-Infinity')
                  OR temperature_c < -90
                  OR temperature_c > 60
              )
        )::bigint,
        'MEDIUM',
        'Out-of-range optional values are set to NULL; no value is invented.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT
        'Validity',
        'Humidity outside 0..100 percent',
        COUNT(*) FILTER (
            WHERE humidity_pct IS NOT NULL
              AND (humidity_pct < 0 OR humidity_pct > 100)
        )::bigint,
        'MEDIUM',
        'Out-of-range optional values are set to NULL; no value is invented.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT
        'Validity',
        'Negative wind speed',
        COUNT(*) FILTER (
            WHERE wind_speed_kmh IS NOT NULL
              AND (
                  wind_speed_kmh::text IN ('NaN', 'Infinity', '-Infinity')
                  OR wind_speed_kmh < 0
              )
        )::bigint,
        'MEDIUM',
        'Negative optional values are set to NULL; no value is invented.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT
        'Validity',
        'Negative precipitation',
        COUNT(*) FILTER (
            WHERE precipitation_mm::text IN ('NaN', 'Infinity', '-Infinity')
               OR precipitation_mm < 0
        )::bigint,
        'MEDIUM',
        'Substituted with 0 because the target schema requires a nonnegative value.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT
        'Validity',
        'Coordinates outside latitude/longitude bounds',
        COUNT(*) FILTER (
            WHERE sensor_latitude NOT BETWEEN -90 AND 90
               OR sensor_longitude NOT BETWEEN -180 AND 180
        )::bigint,
        'HIGH',
        'Coordinates are replaced by the canonical sensor coordinates.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT
        'Validity',
        'Negative bicycle count',
        COUNT(*) FILTER (WHERE comptage_5m < 0)::bigint,
        'MEDIUM',
        'The target table CHECK constraint prevents negative counts.'
    FROM weather_sensor_clean
    UNION ALL
    SELECT
        'Consistency',
        'Sensor metadata differs from canonical sensor row',
        COUNT(*) FILTER (
            WHERE w.sensor_ident IS DISTINCT FROM s.ident
               OR w.sensor_type IS DISTINCT FROM s.type_code
               OR w.zone IS DISTINCT FROM s.zone_code
               OR w.sensor_latitude IS DISTINCT FROM s.latitude
               OR w.sensor_longitude IS DISTINCT FROM s.longitude
               OR w.sensor_label IS DISTINCT FROM s.libelle
        )::bigint,
        'HIGH',
        'Denormalized metadata is replaced with values from sensor using sensor_gid.'
    FROM weather_sensor_clean AS w
    JOIN sensor AS s ON s.gid = w.sensor_gid
    UNION ALL
    SELECT
        'Integrity',
        'Events referencing a missing sensor',
        COUNT(*) FILTER (
            WHERE NOT EXISTS (
                SELECT 1 FROM sensor AS s WHERE s.gid = w.sensor_gid
            )
        )::bigint,
        'CRITICAL',
        'The foreign key should prevent orphan references.'
    FROM weather_sensor_clean AS w
)
SELECT
    category,
    control_name,
    table_stats.checked_rows,
    checks.issue_count,
    severity,
    policy
FROM checks
CROSS JOIN table_stats
ORDER BY
    CASE category
        WHEN 'Completeness' THEN 1
        WHEN 'Uniqueness' THEN 2
        WHEN 'Validity' THEN 3
        WHEN 'Consistency' THEN 4
        ELSE 5
    END,
    control_name;
