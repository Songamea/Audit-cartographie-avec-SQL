# Audit et cartographie des données — TP1 et TP2

Projet sur les données de mobilité cyclable de Bordeaux Métropole.

- **TP1** : audit du CSV, modélisation et chargement PostgreSQL.
- **TP2** : pipeline météo avec Kafka, Data Lake, Spark, PostgreSQL,
  Metabase, Prometheus et Grafana.

Les deux TPs ont deux fichiers Compose séparés. Le TP2 doit être lancé après
la vérification du TP1. Comme les deux utilisent le port `5433`, le Compose
TP1 doit être arrêté avant de lancer le TP2.

## Prérequis

- Docker Desktop démarré ;
- Docker Compose v2 ;
- Python 3.10 ou plus récent pour les scripts.

Les dépendances Python du pipeline sont installées dans les images Docker.

## Lancement guidé

### 1. Lancer et vérifier le TP1

Depuis la racine du dépôt :

```powershell
python .\scripts\setup_tp1.py
```

Le script démarre PostgreSQL, charge `data/pc_captv_p.csv` et affiche le
nombre de capteurs. Vérifier aussi l'état du service et les données :

```powershell
docker compose -f docker/tp1/docker-compose.yml ps
docker compose -f docker/tp1/docker-compose.yml exec postgres `
  psql -U audit_user -d transport_velo `
  -c "SELECT COUNT(*) AS sensors FROM sensor;"
```

Le résultat attendu est un nombre de capteurs supérieur à zéro. Quand cette
vérification est correcte, arrêter le Compose TP1 sans supprimer son volume :

```powershell
docker compose -f docker/tp1/docker-compose.yml down
```

### 2. Lancer le TP2

Après l'arrêt du TP1 :

```powershell
python .\scripts\setup_tp2.py
```

Le script vérifie que le TP1 est arrêté, puis construit et démarre toute la
plateforme TP2.

Vérifier les conteneurs :

```powershell
docker compose -f docker/tp2/docker-compose.yml ps
```

Le démarrage peut prendre quelques minutes. Les événements météo sont ensuite
produits automatiquement toutes les 30 secondes.

## Accès aux services TP2

| Service | Adresse / paramètres |
| --- | --- |
| PostgreSQL | `localhost:5433` |
| Grafana | <http://localhost:3000>, `admin` / `admin` |
| Metabase | <http://localhost:3001> |
| Prometheus | <http://localhost:9090> |

Connexion PostgreSQL :

```powershell
docker compose -f docker/tp2/docker-compose.yml exec postgres `
  psql -U audit_user -d transport_velo
```

Pour Metabase, utiliser l'hôte Docker `postgres`, le port `5432`, la base
`transport_velo`, l'utilisateur `audit_user` et le mot de passe
`audit_password`.

Contrôler les résultats TP2 :

```powershell
docker compose -f docker/tp2/docker-compose.yml exec postgres `
  psql -U audit_user -d transport_velo `
  -c "SELECT COUNT(*) AS clean_records FROM weather_sensor_clean;"
```

## Arrêt et réinitialisation

Arrêt sans supprimer les données :

```powershell
docker compose -f docker/tp2/docker-compose.yml down
```

Pour rejouer l'initialisation complète d'un TP :

```powershell
python .\scripts\reset_project.py tp1
python .\scripts\reset_project.py tp2
```

Puis reprendre le parcours depuis l'étape 1.

## Ce que fait chaque TP

### TP1

Le script SQL charge le CSV en staging, crée `sensor_type`,
`traffic_zone`, `sensor` et `sensor_measurement`, ajoute les clés, contraintes
et index, puis insère deux mesures de test.

### TP2

`producer.py` interroge Open-Meteo et publie dans Kafka. `source2.py` copie
l'inventaire CSV dans le Data Lake. `aggregator.py` rapproche la météo du
capteur le plus proche. Spark nettoie, déduplique et charge
`weather_sensor_clean` dans PostgreSQL. Prometheus et Grafana exposent le
suivi du pipeline ; Metabase permet l'exploration SQL.

## Arborescence

```text
data/                 CSV source et échantillon TP2
database/models/      modèle logique DBML
database/sql/         scripts PostgreSQL TP1 et TP2
docker/tp1/           Compose PostgreSQL du TP1
docker/tp2/           Compose de la plateforme TP2
pipeline/             producer, source2, agrégateur et métriques
spark/                image et job PySpark
monitoring/           Prometheus et Grafana
scripts/              scripts setup et reset
docs/                 rapports et documentation Docker
```

## Documentation

- [Rapport TP1](<docs/Rapport%20TP1.md>)
- [Rapport TP2](<docs/Rapport%20TP2.md>)
- [Dossier TP3 - audit qualité](docs/TP3.md)
- [Documentation Docker](docs/DOCKER.md)
- [Échantillon TP2](data/sample/README.md)

Limite : le CSV TP1 est un inventaire, pas un historique complet des
comptages. Le rapprochement météo/capteur du TP2 est donc un enrichissement
spatial de démonstration.
