#!/usr/bin/env python3
"""Arrete les deux TPs et supprime le volume PostgreSQL partage."""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TP1_COMPOSE = ROOT / "docker" / "tp1" / "docker-compose.yml"
TP2_COMPOSE = ROOT / "docker" / "tp2" / "docker-compose.yml"


def main() -> None:
    subprocess.run(
        ["docker", "compose", "-f", str(TP2_COMPOSE), "down", "-v"],
        cwd=ROOT,
        check=True,
    )
    subprocess.run(
        ["docker", "compose", "-f", str(TP1_COMPOSE), "down", "-v"],
        cwd=ROOT,
        check=True,
    )
    print("Les deux TPs et la base partagee ont ete reinitialises.")


if __name__ == "__main__":
    main()
