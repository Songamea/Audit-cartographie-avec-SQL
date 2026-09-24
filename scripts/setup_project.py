#!/usr/bin/env python3
"""Initialise le projet PostgreSQL avec Docker et importe le CSV source."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCKER_DIR = ROOT / "docker"
DATA_DIR = ROOT / "data"
SQL_DIR = ROOT / "database" / "sql"
COMPOSE_FILE = DOCKER_DIR / "docker-compose.yml"
SQL_FILE = SQL_DIR / "postgresql_schema.sql"
CSV_FILE = DATA_DIR / "pc_captv_p.csv"


def run(cmd: list[str], description: str) -> None:
    print(f"\n> {description}")
    print("Commande :", " ".join(cmd))
    result = subprocess.run(cmd, cwd=str(ROOT), text=True)
    if result.returncode != 0:
        raise SystemExit(f"Erreur pendant : {description}")


def ensure_files() -> None:
    required = [COMPOSE_FILE, SQL_FILE, CSV_FILE]
    missing = [str(p.relative_to(ROOT)) for p in required if not p.exists()]
    if missing:
        raise SystemExit("Fichiers requis absents :\n- " + "\n- ".join(missing))


def ensure_docker_available() -> None:
    try:
        subprocess.run(["docker", "--version"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        raise SystemExit("Docker n'est pas installé ou n'est pas accessible dans le PATH.")


def main() -> None:
    ensure_docker_available()
    ensure_files()

    print(f"Projet racine : {ROOT}")
    print(f"Docker Compose : {COMPOSE_FILE}")
    print(f"SQL : {SQL_FILE}")
    print(f"CSV : {CSV_FILE}")

    run(["docker", "compose", "-f", str(COMPOSE_FILE), "up", "-d", "--remove-orphans"], "Démarrage du conteneur PostgreSQL")

    print("\n Base PostgreSQL démarrée avec succès.")
    print("Connexion attendue :")
    print("  hôte : localhost")
    print("  port : 5433")
    print("  base : transport_velo")
    print("  user : audit_user")
    print("  mot de passe : audit_password")
    print("\nPour vérifier :")
    print("  docker compose -f docker/docker-compose.yml ps")
    print("  docker compose -f docker/docker-compose.yml exec postgres psql -U audit_user -d transport_velo")


if __name__ == "__main__":
    main()
