# Docker — parcours TP1 puis TP2

Le projet utilise deux fichiers Compose :

- `docker/tp1/docker-compose.yml` : PostgreSQL et le modèle relationnel du TP1 ;
- `docker/tp2/docker-compose.yml` : plateforme complète du TP2.

Les scripts fournissent le parcours guidé :

```powershell
python .\scripts\setup_tp1.py
docker compose -f docker/tp1/docker-compose.yml down
python .\scripts\setup_tp2.py
```

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

Arrêter le TP1 avant le TP2 :

```powershell
docker compose -f docker/tp1/docker-compose.yml down
```

## TP2

```powershell
docker compose -f docker/tp2/docker-compose.yml up -d --build
docker compose -f docker/tp2/docker-compose.yml ps
```

Le TP2 expose PostgreSQL sur `5433`, Grafana sur `3000`, Metabase sur `3001`
et Prometheus sur `9090`.

## Réinitialiser

Les scripts d'initialisation PostgreSQL ne sont exécutés que lorsque le volume
est vide. Pour rejouer un TP :

```powershell
python .\scripts\reset_project.py tp1
python .\scripts\reset_project.py tp2
```

Ces commandes suppriment uniquement les volumes du Compose choisi.
