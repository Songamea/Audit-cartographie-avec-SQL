\set ON_ERROR_STOP on

WITH before_run AS (
    SELECT run_id, rows_before
    FROM tp3_quality_run
    WHERE phase = 'before'
    ORDER BY run_id DESC
    LIMIT 1
), before_checks AS (
    SELECT c.*
    FROM before_run AS r
    JOIN tp3_quality_check AS c USING (run_id)
), after_run AS (
    SELECT run_id, rows_after
    FROM tp3_quality_run
    WHERE phase = 'after'
    ORDER BY run_id DESC
    LIMIT 1
), after_checks AS (
    SELECT c.*
    FROM after_run AS r
    JOIN tp3_quality_check AS c USING (run_id)
)
SELECT COALESCE(b.check_code, a.check_code) AS check_code,
       b.anomaly_rows AS anomalies_before,
       a.anomaly_rows AS anomalies_after,
       b.checked_rows AS rows_checked_before,
       a.checked_rows AS rows_checked_after,
       b.severity,
       COALESCE(b.description, a.description) AS description
FROM before_checks AS b
FULL OUTER JOIN after_checks AS a USING (check_code)
ORDER BY COALESCE(b.category, a.category), COALESCE(b.check_code, a.check_code);

SELECT b.rows_before AS rows_before,
       a.rows_after AS rows_after,
       b.rows_before - a.rows_after AS rows_removed_from_target
FROM (
    SELECT rows_before FROM tp3_quality_run
    WHERE phase = 'before' ORDER BY run_id DESC LIMIT 1
) AS b
CROSS JOIN (
    SELECT rows_after FROM tp3_quality_run
    WHERE phase = 'after' ORDER BY run_id DESC LIMIT 1
) AS a;

SELECT q.quarantine_reason, COUNT(*) AS quarantined_rows
FROM tp3_quality_quarantine AS q
GROUP BY q.quarantine_reason
ORDER BY q.quarantine_reason;

SELECT rule_code, COUNT(*) AS corrected_rows
FROM tp3_quality_correction
WHERE run_id = (
    SELECT MAX(run_id) FROM tp3_quality_run WHERE phase = 'cleaning'
)
GROUP BY rule_code
ORDER BY rule_code;