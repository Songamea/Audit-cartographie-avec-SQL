#!/usr/bin/env python3
"""Arrete le projet et supprime ses volumes Docker."""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPOSE_FILE = ROOT / "docker" / "tp2" / "docker-compose.yml"


def main() -> None:
    subprocess.run(
        ["docker", "compose", "-f", str(COMPOSE_FILE), "down", "-v"],
        cwd=ROOT,
        check=True,
    )
    print("TP reinitialise. Rejoue l'etape correspondante avec setup_tp1.py ou setup_tp2.py.")


if __name__ == "__main__":
    main()
