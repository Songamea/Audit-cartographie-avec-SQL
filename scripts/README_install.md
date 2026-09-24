# Installation du projet

Ce script automatise l'initialisation du conteneur PostgreSQL et l'import du CSV source.

## Prérequis

- Python 3.10+
- Docker Desktop ou Docker Engine
- Accès au docker daemon

## Exécution

Depuis la racine du projet :

```powershell
python .\scripts\setup_project.py
```

## Ce que fait le script

1. Vérifie que Docker est disponible.
2. Vérifie que les fichiers suivants existent :
   - docker/docker-compose.yml
   - database/sql/postgresql_schema.sql
   - data/pc_captv_p.csv
3. Lance le conteneur PostgreSQL avec Docker Compose.
4. Exécute automatiquement le script SQL au démarrage.
5. Charge le CSV dans la table de staging selon le schéma SQL.

## Connexion PostgreSQL

- Hôte : localhost
- Port : 5433
- Base : transport_velo
- User : audit_user
- Mot de passe : audit_password

## Vérification rapide

```powershell
docker compose -f docker/docker-compose.yml exec postgres psql -U audit_user -d transport_velo -c "SELECT COUNT(*) FROM sensor;"
```
