#!/usr/bin/env python3
"""Lance et verifie la base PostgreSQL du TP1."""

from __future__ import annotations

import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPOSE = ROOT / "docker" / "tp1" / "docker-compose.yml"
TP2_COMPOSE = ROOT / "docker" / "tp2" / "docker-compose.yml"


def main() -> None:
    if shutil.which("docker") is None:
        raise SystemExit("Docker est requis et doit etre demarre.")
    tp2_status = subprocess.run(
        ["docker", "compose", "-f", str(TP2_COMPOSE), "ps", "-q"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    if tp2_status.stdout.strip():
        raise SystemExit(
            "Des services du TP2 sont encore actifs et utilisent PostgreSQL. "
            "Arrete-les avant de relancer le TP1 :\n"
            "docker compose -f docker/tp2/docker-compose.yml down"
        )
    subprocess.run(
        ["docker", "compose", "-f", str(COMPOSE), "up", "-d"],
        cwd=ROOT,
        check=True,
    )
    check_command = [
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
        "SELECT COUNT(*) FROM sensor;",
    ]
    print("Attente de l'initialisation complete de PostgreSQL...")
    for attempt in range(1, 31):
        result = subprocess.run(
            check_command,
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            sensor_count = result.stdout.strip()
            break
        if attempt == 30:
            raise SystemExit(
                "PostgreSQL n'est pas devenu disponible apres 60 secondes. "
                "Consulte les logs avec :\n"
                "docker compose -f docker/tp1/docker-compose.yml logs postgres"
            )
        time.sleep(2)
    print(f"\nCapteurs charges dans la base partagee : {sensor_count}")
    print("\nTP1 demarre et verifie. Laisse ce conteneur actif pour le TP2.")
    print("Puis lance : python .\\scripts\\setup_tp2.py")


if __name__ == "__main__":
    main()
