#!/usr/bin/env python3
"""Verifie que le TP1 est termine, puis lance la plateforme TP2."""

from __future__ import annotations

import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TP1_COMPOSE = ROOT / "docker" / "tp1" / "docker-compose.yml"
TP2_COMPOSE = ROOT / "docker" / "tp2" / "docker-compose.yml"
SHARED_VOLUME = "tp1_postgres_data_tp1"


def run_compose(*args: str, capture_output: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["docker", "compose", "-f", str(TP2_COMPOSE), *args],
        cwd=ROOT,
        capture_output=capture_output,
        text=capture_output,
        check=True,
    )


def main() -> None:
    if shutil.which("docker") is None:
        raise SystemExit("Docker est requis et doit etre demarre.")
    result = subprocess.run(
        ["docker", "compose", "-f", str(TP1_COMPOSE), "ps", "-q", "postgres"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    if result.stdout.strip():
        raise SystemExit(
            "Le TP1 est encore actif. Verifie-le, puis execute :\n"
            "docker compose -f docker/tp1/docker-compose.yml down\n"
            "Ensuite relance ce script."
        )
    volume = subprocess.run(
        ["docker", "volume", "inspect", SHARED_VOLUME],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if volume.returncode != 0:
        raise SystemExit(
            "Le volume PostgreSQL du TP1 est introuvable. Lance d'abord "
            "python .\\scripts\\setup_tp1.py et verifie les donnees."
        )

    print("Rattachement a la base PostgreSQL conservee depuis le TP1...")
    run_compose("up", "-d", "postgres")
    ready = False
    for _ in range(30):
        result = subprocess.run(
            [
                "docker",
                "compose",
                "-f",
                str(TP2_COMPOSE),
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
        if result.returncode == 0:
            ready = True
            break
        time.sleep(2)
    if not ready:
        raise SystemExit(
            "La base partagee n'est pas devenue disponible apres 60 secondes. "
            "Consulte les logs :\n"
            "docker compose -f docker/tp2/docker-compose.yml logs postgres"
        )

    sensor_count = run_compose(
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
            "La base existe, mais la table sensor du TP1 est vide. "
            "Verifie le TP1 avant de poursuivre."
        ) from exc

    run_compose(
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
        "-f",
        "/docker-entrypoint-initdb.d/02_tp2_schema.sql",
    )
    run_compose("up", "-d", "--build", "--remove-orphans")
    print("\nTP2 demarre. Verification :")
    print("docker compose -f docker/tp2/docker-compose.yml ps")
    print(f"La base partagee contient {sensor_count} capteurs du TP1.")


if __name__ == "__main__":
    main()
