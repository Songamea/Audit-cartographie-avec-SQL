#!/usr/bin/env python3
"""Verifie que le TP1 est termine, puis lance la plateforme TP2."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TP1_COMPOSE = ROOT / "docker" / "tp1" / "docker-compose.yml"
TP2_COMPOSE = ROOT / "docker" / "tp2" / "docker-compose.yml"


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
    subprocess.run(
        [
            "docker",
            "compose",
            "-f",
            str(TP2_COMPOSE),
            "up",
            "-d",
            "--build",
            "--remove-orphans",
        ],
        cwd=ROOT,
        check=True,
    )
    print("\nTP2 demarre. Verification :")
    print("docker compose -f docker/tp2/docker-compose.yml ps")


if __name__ == "__main__":
    main()
