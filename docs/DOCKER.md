# Docker — parcours TP1 puis TP2

Le projet utilise deux fichiers Compose séparés. Le TP1 démarre PostgreSQL
dans le conteneur `Velib-Bordeaux`, sur un réseau partagé :

- `docker/tp1/docker-compose.yml` : PostgreSQL et le modèle relationnel du TP1 ;
- `docker/tp2/docker-compose.yml` : plateforme complète du TP2.

Les scripts fournissent le parcours guidé :

```powershell
python .\scripts\setup_tp1.py
python .\scripts\setup_tp2.py
```

Le conteneur `Velib-Bordeaux` doit rester démarré pendant le TP2. Le Compose
TP2 rejoint son réseau, vérifie la base existante et y ajoute le schéma TP2 ;
il ne démarre pas un deuxième PostgreSQL.

## TP1

```powershell
docker compose -f docker/tp1/docker-compose.yml up -d
docker compose -f docker/tp1/docker-compose.yml ps
docker compose -f docker/tp1/docker-compose.yml exec postgres `
  psql -U audit_user -d transport_velo
```

Paramètres : hôte `localhost`, port `5433`, base `transport_velo`, utilisateur
`audit_user`, mot de passe `audit_password`.

Vérification :

```sql
SELECT COUNT(*) FROM sensor;
SELECT type_code, COUNT(*) FROM sensor GROUP BY type_code ORDER BY type_code;
```

Vérifier le conteneur et la persistance :

```powershell
docker ps --filter "name=Velib-Bordeaux"
docker volume inspect tp1_postgres_data_tp1
```

## TP2

```powershell
docker compose -f docker/tp2/docker-compose.yml up -d --build
docker compose -f docker/tp2/docker-compose.yml ps
```

Le PostgreSQL du TP1 reste accessible sur `5433`. Le TP2 expose Grafana sur
`3000`, Metabase sur `3001` et Prometheus sur `9090`. Pour accéder à la base
pendant le TP2, utiliser le Compose TP1 :

```powershell
docker compose -f docker/tp1/docker-compose.yml exec postgres `
  psql -U audit_user -d transport_velo
```

## Arrêter ou réinitialiser

Arrêter le TP2 conserve PostgreSQL et ses données :

```powershell
docker compose -f docker/tp2/docker-compose.yml down
```

Pour arrêter également PostgreSQL, toujours sans supprimer les données :

```powershell
docker compose -f docker/tp1/docker-compose.yml down
```

Pour tout effacer (base partagée et volumes TP2) et repartir à zéro :

```powershell
python .\scripts\reset_project.py
```
