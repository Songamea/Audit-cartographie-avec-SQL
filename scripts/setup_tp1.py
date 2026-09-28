#!/usr/bin/env python3
"""Lance et verifie la base PostgreSQL du TP1."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPOSE = ROOT / "docker" / "tp1" / "docker-compose.yml"


def main() -> None:
    if shutil.which("docker") is None:
        raise SystemExit("Docker est requis et doit etre demarre.")
    subprocess.run(
        ["docker", "compose", "-f", str(COMPOSE), "up", "-d"],
        cwd=ROOT,
        check=True,
    )
    subprocess.run(
        [
            "docker",
            "compose",
            "-f",
            str(COMPOSE),
            "exec",
            "-T",
            "postgres",
            "psql",
            "-U",
            "audit_user",
            "-d",
            "transport_velo",
            "-c",
            "SELECT COUNT(*) AS sensors FROM sensor;",
        ],
        cwd=ROOT,
        check=True,
    )
    print("\nTP1 termine et verifie. Arrete-le avant de lancer le TP2 :")
    print("docker compose -f docker/tp1/docker-compose.yml down")
    print("Puis lance : python .\\scripts\\setup_tp2.py")


if __name__ == "__main__":
    main()
