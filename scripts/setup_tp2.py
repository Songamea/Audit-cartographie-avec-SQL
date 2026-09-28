#!/usr/bin/env python3
"""Lance le TP2 en utilisant le conteneur PostgreSQL actif du TP1."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TP1_COMPOSE = ROOT / "docker" / "tp1" / "docker-compose.yml"
TP2_COMPOSE = ROOT / "docker" / "tp2" / "docker-compose.yml"
TP2_SCHEMA = ROOT / "database" / "sql" / "tp2_schema.sql"


def run_tp1(*args: str, capture_output: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["docker", "compose", "-f", str(TP1_COMPOSE), *args],
        cwd=ROOT,
        capture_output=capture_output,
        text=capture_output,
        check=True,
    )


def run_tp2(*args: str) -> None:
    subprocess.run(
        ["docker", "compose", "-f", str(TP2_COMPOSE), *args],
        cwd=ROOT,
        check=True,
    )


def main() -> None:
    if shutil.which("docker") is None:
        raise SystemExit("Docker est requis et doit etre demarre.")

    postgres = run_tp1("ps", "-q", "postgres", capture_output=True)
    if not postgres.stdout.strip():
        raise SystemExit(
            "Le conteneur PostgreSQL du TP1 n'est pas actif. Lance et verifie "
            "d'abord :\npython .\\scripts\\setup_tp1.py"
        )

    ready = subprocess.run(
        [
            "docker",
            "compose",
            "-f",
            str(TP1_COMPOSE),
            "exec",
            "-T",
            "postgres",
            "pg_isready",
            "-U",
            "audit_user",
            "-d",
            "transport_velo",
        ],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if ready.returncode != 0:
        raise SystemExit(
            "Le conteneur TP1 est actif, mais PostgreSQL n'est pas pret. "
            "Consulte ses logs :\n"
            "docker compose -f docker/tp1/docker-compose.yml logs postgres"
        )

    sensor_count = run_tp1(
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
        "SELECT COUNT(*) FROM sensor;",
        capture_output=True,
    ).stdout.strip()
    try:
        if int(sensor_count) < 1:
            raise ValueError
    except ValueError as exc:
        raise SystemExit(
            "La base PostgreSQL du TP1 ne contient aucun capteur. "
            "Verifie les donnees avant de poursuivre."
        ) from exc

    with TP2_SCHEMA.open("r", encoding="utf-8") as schema_file:
        subprocess.run(
            [
                "docker",
                "compose",
                "-f",
                str(TP1_COMPOSE),
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
            ],
            cwd=ROOT,
            stdin=schema_file,
            check=True,
        )

    run_tp2("up", "-d", "--build", "--remove-orphans")
    print("\nTP2 demarre. Verification :")
    print("docker compose -f docker/tp2/docker-compose.yml ps")
    print(
        f"La plateforme reutilise Velib-Bordeaux et ses {sensor_count} capteurs TP1."
    )


if __name__ == "__main__":
    main()
