BEGIN;

CREATE TABLE IF NOT EXISTS tp3_quality_run (
    run_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    phase varchar(12) NOT NULL CHECK (phase IN ('before', 'cleaning', 'after')),
    started_at timestamptz NOT NULL DEFAULT current_timestamp,
    finished_at timestamptz,
    rows_before bigint,
    rows_after bigint
);

CREATE TABLE IF NOT EXISTS tp3_quality_check (
    run_id bigint NOT NULL REFERENCES tp3_quality_run(run_id),
    check_code varchar(50) NOT NULL,
    category varchar(20) NOT NULL,
    severity varchar(10) NOT NULL CHECK (severity IN ('critical', 'high', 'medium', 'low')),
    checked_rows bigint NOT NULL CHECK (checked_rows >= 0),
    anomaly_rows bigint NOT NULL CHECK (anomaly_rows >= 0),
    description text NOT NULL,
    PRIMARY KEY (run_id, check_code)
);

CREATE TABLE IF NOT EXISTS tp3_quality_correction (
    run_id bigint NOT NULL REFERENCES tp3_quality_run(run_id),
    event_id uuid NOT NULL,
    rule_code varchar(50) NOT NULL,
    old_values jsonb NOT NULL,
    new_values jsonb NOT NULL,
    corrected_at timestamptz NOT NULL DEFAULT current_timestamp,
    PRIMARY KEY (run_id, event_id, rule_code)
);

CREATE TABLE IF NOT EXISTS tp3_quality_quarantine (
    LIKE weather_sensor_clean INCLUDING DEFAULTS INCLUDING CONSTRAINTS,
    quarantine_reason varchar(60) NOT NULL,
    quarantined_at timestamptz NOT NULL DEFAULT current_timestamp,
    quality_run_id bigint NOT NULL REFERENCES tp3_quality_run(run_id),
    PRIMARY KEY (event_id)
);

CREATE TABLE IF NOT EXISTS tp3_quality_exclusion (
    event_id uuid PRIMARY KEY,
    quarantine_reason varchar(60) NOT NULL,
    quarantined_at timestamptz NOT NULL DEFAULT current_timestamp,
    quality_run_id bigint NOT NULL REFERENCES tp3_quality_run(run_id)
);

CREATE INDEX IF NOT EXISTS tp3_quality_quarantine_reason_idx
    ON tp3_quality_quarantine (quarantine_reason);

COMMIT;