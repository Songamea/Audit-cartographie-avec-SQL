#!/usr/bin/env python3
"""Lance la base PostgreSQL du projet via Docker Compose."""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPOSE_FILE = ROOT / "docker" / "docker-compose.yml"
SQL_FILE = ROOT / "database" / "sql" / "postgresql_schema.sql"
CSV_FILE = ROOT / "data" / "pc_captv_p.csv"


def ensure_files() -> None:
    required = [COMPOSE_FILE, SQL_FILE, CSV_FILE]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        raise SystemExit(
            "Fichiers requis absents :\n- " + "\n- ".join(missing)
        )


def ensure_docker_available() -> None:
    try:
        subprocess.run(
            ["docker", "--version"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception as exc:
        raise SystemExit(
            "Docker n'est pas installé ou n'est pas démarré.\n"
            "Installe Docker Desktop / Docker Engine, puis relance ce script."
        ) from exc


def main() -> None:
    ensure_files()
    ensure_docker_available()

    print(f"Projet : {ROOT}")
    print(f"Docker Compose : {COMPOSE_FILE}")
    print(f"SQL : {SQL_FILE}")
    print(f"CSV : {CSV_FILE}")
    print("\nLancement du conteneur PostgreSQL...")

    subprocess.run(
        ["docker", "compose", "-f", str(COMPOSE_FILE), "up", "-d", "--remove-orphans"],
        cwd=str(ROOT),
        check=True,
    )

    print("\n✅ Base PostgreSQL démarrée.")
    print("Connexion attendue :")
    print("  - hôte : localhost")
    print("  - port : 5433")
    print("  - base : transport_velo")
    print("  - utilisateur : audit_user")
    print("  - mot de passe : audit_password")
    print("\nPour vérifier :")
    print("  docker compose -f docker/docker-compose.yml ps")
    print("  docker compose -f docker/docker-compose.yml exec postgres psql -U audit_user -d transport_velo")


if __name__ == "__main__":
    main()
