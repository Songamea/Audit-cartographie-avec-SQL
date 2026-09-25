# PostgreSQL avec Docker - TP1

## Demarrer la base

Depuis ce dossier :

```powershell
docker compose -f docker/tp1/docker-compose.yml up -d
```

Le conteneur cree automatiquement la base `transport_velo`, les tables, les contraintes et les donnees de test au premier demarrage.

## Se connecter avec psql

```powershell
docker compose -f docker/tp1/docker-compose.yml exec postgres psql -U audit_user -d transport_velo
```

Parametres de connexion :

- Hote : `localhost`
- Port : `5433`
- Base : `transport_velo`
- Utilisateur : `audit_user`
- Mot de passe : `audit_password`

## Tester les donnees

```sql
SELECT COUNT(*) FROM sensor;

SELECT st.code, COUNT(*)
FROM sensor AS s
JOIN sensor_type AS st ON st.code = s.type_code
GROUP BY st.code
ORDER BY st.code;

SELECT s.ident, sm.comptage_5m, sm.observed_at
FROM sensor AS s
JOIN sensor_measurement AS sm ON sm.sensor_gid = s.gid
ORDER BY s.ident
LIMIT 10;
```

## Reinitialiser completement la base

Les scripts du dossier `/docker-entrypoint-initdb.d/` ne sont executes que lorsque le volume est vide. Pour rejouer le chargement apres une modification du SQL ou du CSV :

```powershell
docker compose -f docker/tp1/docker-compose.yml down -v
docker compose -f docker/tp1/docker-compose.yml up -d
```

Cette commande supprime le volume PostgreSQL local du projet.

## Arreter le service

```powershell
docker compose -f docker/tp1/docker-compose.yml down
```