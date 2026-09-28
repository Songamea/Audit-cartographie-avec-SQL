#!/usr/bin/env python3
"""Audite, nettoie et re-audite les donnees TP2 dans PostgreSQL."""

from __future__ import annotations

import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPOSE = ROOT / "docker" / "tp1" / "docker-compose.yml"
AUDIT_SQL = ROOT / "database" / "sql" / "tp3_audit.sql"
CLEAN_SQL = ROOT / "database" / "sql" / "tp3_clean.sql"
RESULTS_DIR = ROOT / "reports" / "tp3"


def run_sql(sql_file: Path) -> str:
    result = subprocess.run(
        [
            "docker",
            "compose",
            "-f",
            str(COMPOSE),
            "exec",
            "-T",
            "postgres",
            "psql",
            "-X",
            "-v",
            "ON_ERROR_STOP=1",
            "-U",
            "audit_user",
            "-d",
            "transport_velo",
            "-A",
            "-F",
            ";",
            "-P",
            "footer=off",
            "-q",
            "-f",
            "-",
        ],
        cwd=ROOT,
        input=sql_file.read_text(encoding="utf-8"),
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout


def main() -> None:
    if shutil.which("docker") is None:
        raise SystemExit("Docker est requis et doit etre demarre.")

    compose_status = subprocess.run(
        ["docker", "compose", "-f", str(COMPOSE), "ps", "-q", "postgres"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    if not compose_status.stdout.strip():
        raise SystemExit(
            "Le conteneur Velib-Bordeaux n'est pas actif. Demarre le TP1 "
            "avant de relancer l'audit TP3."
        )

    table_check = subprocess.run(
        [
            "docker",
            "compose",
            "-f",
            str(COMPOSE),
            "exec",
            "-T",
            "postgres",
            "psql",
            "-v",
            "ON_ERROR_STOP=1",
            "-U",
            "audit_user",
            "-d",
            "transport_velo",
            "-Atc",
            "SELECT to_regclass('public.weather_sensor_clean') IS NOT NULL",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    if table_check.stdout.strip().lower() != "t":
        raise SystemExit(
            "La table weather_sensor_clean est absente. Lance d'abord "
            "python .\\scripts\\setup_tp2.py."
        )

    row_count = subprocess.run(
        [
            "docker",
            "compose",
            "-f",
            str(COMPOSE),
            "exec",
            "-T",
            "postgres",
            "psql",
            "-v",
            "ON_ERROR_STOP=1",
            "-U",
            "audit_user",
            "-d",
            "transport_velo",
            "-Atc",
            "SELECT COUNT(*) FROM weather_sensor_clean",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    if int(row_count.stdout.strip()) == 0:
        raise SystemExit(
            "weather_sensor_clean ne contient encore aucun evenement. "
            "Attends quelques cycles du pipeline TP2, puis relance TP3."
        )

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    before_path = RESULTS_DIR / f"quality_before_{timestamp}.csv"
    actions_path = RESULTS_DIR / f"cleaning_actions_{timestamp}.csv"
    after_path = RESULTS_DIR / f"quality_after_{timestamp}.csv"

    before_path.write_text(run_sql(AUDIT_SQL), encoding="utf-8")
    actions_path.write_text(run_sql(CLEAN_SQL), encoding="utf-8")
    after_path.write_text(run_sql(AUDIT_SQL), encoding="utf-8")

    print(f"Audit avant nettoyage : {before_path.relative_to(ROOT)}")
    print(f"Corrections appliquees : {actions_path.relative_to(ROOT)}")
    print(f"Audit apres nettoyage : {after_path.relative_to(ROOT)}")
    print("Compare les colonnes issue_count avant/apres et conserve ces resultats.")


if __name__ == "__main__":
    main()
