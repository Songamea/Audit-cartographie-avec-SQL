-- TP Audit et cartographie des donnees
-- Source : pc_captv_p.csv, Bordeaux Metropole
-- Execution locale : psql -d transport_velo -f postgresql_schema.sql
-- Execution Docker : ce fichier est monte dans /docker-entrypoint-initdb.d/

BEGIN;

DROP TABLE IF EXISTS sensor_measurement CASCADE;
DROP TABLE IF EXISTS sensor CASCADE;
DROP TABLE IF EXISTS traffic_zone CASCADE;
DROP TABLE IF EXISTS sensor_type CASCADE;
DROP TABLE IF EXISTS staging_sensor_source CASCADE;

CREATE TABLE sensor_type (
    code varchar(30) PRIMARY KEY,
    label varchar(120) NOT NULL
);

CREATE TABLE traffic_zone (
    zone_code integer PRIMARY KEY,
    source_label varchar(30) NOT NULL
);

CREATE TABLE staging_sensor_source (
    geo_point text,
    geo_shape text,
    gid text,
    libelle text,
    ident text,
    sensor_type text,
    zone text,
    comptage_5m text,
    cdate text,
    mdate text
);

-- Le CSV est monte par docker-compose dans le meme repertoire d'initialisation.
\copy staging_sensor_source FROM '/docker-entrypoint-initdb.d/pc_captv_p.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', QUOTE '"', ESCAPE '"', NULL '')

INSERT INTO sensor_type (code, label)
SELECT DISTINCT trim(sensor_type), trim(sensor_type)
FROM staging_sensor_source
WHERE nullif(trim(sensor_type), '') IS NOT NULL;

INSERT INTO traffic_zone (zone_code, source_label)
SELECT DISTINCT trim(zone)::integer, trim(zone)
FROM staging_sensor_source
WHERE nullif(trim(zone), '') IS NOT NULL;

CREATE TABLE sensor (
    gid integer PRIMARY KEY,
    ident varchar(30) NOT NULL UNIQUE,
    libelle text NOT NULL,
    type_code varchar(30) NOT NULL REFERENCES sensor_type(code),
    zone_code integer NOT NULL REFERENCES traffic_zone(zone_code),
    latitude numeric(10,7) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude numeric(10,7) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    geo_point_source text NOT NULL,
    geo_shape jsonb NOT NULL CHECK (geo_shape->>'type' = 'Point'),
    cdate timestamptz NOT NULL,
    mdate timestamptz NOT NULL,
    CHECK (mdate >= cdate)
);

INSERT INTO sensor (
    gid, ident, libelle, type_code, zone_code, latitude, longitude,
    geo_point_source, geo_shape, cdate, mdate
)
SELECT
    s.gid::integer,
    trim(s.ident),
    trim(s.libelle),
    trim(s.sensor_type),
    trim(s.zone)::integer,
    split_part(trim(s.geo_point), ',', 1)::numeric,
    split_part(trim(s.geo_point), ',', 2)::numeric,
    s.geo_point,
    s.geo_shape::jsonb,
    s.cdate::timestamptz,
    s.mdate::timestamptz
FROM staging_sensor_source AS s
WHERE nullif(trim(s.gid), '') IS NOT NULL;

CREATE TABLE sensor_measurement (
    sensor_gid integer PRIMARY KEY REFERENCES sensor(gid) ON DELETE CASCADE,
    comptage_5m integer CHECK (comptage_5m IS NULL OR comptage_5m >= 0),
    observed_at timestamptz NOT NULL
);

INSERT INTO sensor_measurement (sensor_gid, comptage_5m, observed_at)
SELECT gid::integer, nullif(trim(comptage_5m), '')::integer, mdate::timestamptz
FROM staging_sensor_source
WHERE nullif(trim(comptage_5m), '') IS NOT NULL;

CREATE INDEX sensor_type_idx ON sensor(type_code);
CREATE INDEX sensor_zone_idx ON sensor(zone_code);
CREATE INDEX sensor_coordinates_idx ON sensor(latitude, longitude);

-- Donnees de test : la contrainte d'unicite evite de dupliquer une mesure existante.
INSERT INTO sensor_measurement (sensor_gid, comptage_5m, observed_at)
SELECT s.gid, 42, CURRENT_TIMESTAMP
FROM sensor AS s
WHERE s.ident = 'P52.2'
ON CONFLICT (sensor_gid) DO UPDATE
SET comptage_5m = EXCLUDED.comptage_5m,
    observed_at = EXCLUDED.observed_at;

INSERT INTO sensor_measurement (sensor_gid, comptage_5m, observed_at)
SELECT s.gid, 18, CURRENT_TIMESTAMP
FROM sensor AS s
WHERE s.ident = 'P1.2'
ON CONFLICT (sensor_gid) DO UPDATE
SET comptage_5m = EXCLUDED.comptage_5m,
    observed_at = EXCLUDED.observed_at;

-- Verification des relations et de la disponibilite des comptages.
SELECT st.code AS type, COUNT(*) AS nombre_capteurs
FROM sensor AS s
JOIN sensor_type AS st ON st.code = s.type_code
GROUP BY st.code
ORDER BY st.code;

SELECT tz.zone_code, COUNT(*) AS nombre_capteurs
FROM sensor AS s
JOIN traffic_zone AS tz ON tz.zone_code = s.zone_code
GROUP BY tz.zone_code
ORDER BY tz.zone_code;

SELECT COUNT(*) AS capteurs_sans_mesure
FROM sensor AS s
LEFT JOIN sensor_measurement AS sm ON sm.sensor_gid = s.gid
WHERE sm.sensor_gid IS NULL;

COMMIT;
