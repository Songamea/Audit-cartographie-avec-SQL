# Audit et cartographie des données — TP1 et TP2

Projet sur les données de mobilité cyclable de Bordeaux Métropole.

- **TP1** : audit du CSV, modélisation et chargement PostgreSQL.
- **TP2** : pipeline météo avec Kafka, Data Lake, Spark, PostgreSQL,
  Metabase, Prometheus et Grafana.

Les deux TPs ont deux fichiers Compose séparés, mais partagent **la même base
PostgreSQL persistante**. Le TP2 complète la base créée par le TP1. Il faut
arrêter le conteneur TP1 avant le TP2, mais l'arrêt normal ne supprime pas le
volume qui contient les données.

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

Le script démarre PostgreSQL, attend la fin de son initialisation, charge
`data/pc_captv_p.csv` et affiche le nombre de capteurs. Vérifier aussi l'état
du service et les données :

```powershell
docker compose -f docker/tp1/docker-compose.yml ps
docker compose -f docker/tp1/docker-compose.yml exec postgres `
  psql -U audit_user -d transport_velo `
  -c "SELECT COUNT(*) AS sensors FROM sensor;"
```

Le résultat attendu est un nombre de capteurs supérieur à zéro. Quand cette
vérification est correcte, arrêter le conteneur TP1 :

```powershell
docker compose -f docker/tp1/docker-compose.yml down
```

`down` supprime le conteneur et le réseau du TP1, **pas le volume
`tp1_postgres_data_tp1`**. Les tables et les données restent stockées.
Dans Docker Desktop, le conteneur n'apparaît plus dans **Containers** après
l'arrêt ; la base persistante se vérifie dans **Volumes** ou avec :

```powershell
docker volume ls
docker volume inspect tp1_postgres_data_tp1
```

### 2. Lancer le TP2

Après l'arrêt du TP1 :

```powershell
python .\scripts\setup_tp2.py
```

Le script vérifie que le TP1 est arrêté et que sa base contient les capteurs.
Il rattache le PostgreSQL TP2 au volume conservé, ajoute la table
`weather_sensor_clean` à cette même base, puis construit et démarre les autres
services. Il ne recharge ni ne remplace le modèle et les données du TP1.

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

Arrêter la plateforme TP2 sans supprimer la base partagée :

```powershell
docker compose -f docker/tp2/docker-compose.yml down
```

Pour réinitialiser les TPs et **effacer définitivement** la base partagée et
les données Docker du TP2 :

```powershell
python .\scripts\reset_project.py
```

Puis reprendre le parcours depuis l'étape 1. Ne pas confondre cette commande
avec `docker compose down` : le script de reset utilise `down -v` et supprime
les volumes.

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
- [Documentation Docker](docs/DOCKER.md)
- [Échantillon TP2](data/sample/README.md)

Limite : le CSV TP1 est un inventaire, pas un historique complet des
comptages. Le rapprochement météo/capteur du TP2 est donc un enrichissement
spatial de démonstration.

## Rendus et livrables : où trouver quoi ?

### Rendu TP1 — audit, cartographie et base relationnelle

| Livrable | Fichier / emplacement |
| --- | --- |
| Sujet, contexte, problématique, sources et dictionnaire | [Rapport TP1](<docs/Rapport%20TP1.md>) |
| Modèle conceptuel (diagramme) | [data/diagrame.png](data/diagrame.png) |
| Modèle logique DBML | [modele_logique.dbml](database/models/modele_logique.dbml) |
| Création des tables, contraintes, import CSV et données de test | [postgresql_schema.sql](database/sql/postgresql_schema.sql) |
| Données sources | [pc_captv_p.csv](data/pc_captv_p.csv) |
| Lancement et vérification | [setup_tp1.py](scripts/setup_tp1.py), puis les commandes de vérification de l'étape 1 ci-dessus |

**État TP1 :** les livrables demandés sont présents dans le dépôt : sujet et
sources documentés, dictionnaire, modèles conceptuel et logique, script SQL
d'implémentation et de test, et cartographie globale dans le rapport. Le
lancement réel doit être vérifié sur la machine avec la procédure ci-dessus.

### Rendu TP2 — pipeline, exploitation et observabilité

| Livrable | Fichier / emplacement |
| --- | --- |
| Choix des sources, architecture, flux et limites | [Rapport TP2](<docs/Rapport%20TP2.md>) |
| Lancement TP2 après contrôle du TP1 | [setup_tp2.py](scripts/setup_tp2.py) |
| Collecte API, source CSV, agrégation et métriques | [dossier pipeline](pipeline) |
| Traitement PySpark | [spark_job.py](spark/spark_job.py) |
| Schéma PostgreSQL de la table propre | [tp2_schema.sql](database/sql/tp2_schema.sql) |
| Orchestration, images et configuration des services | [Compose TP2](docker/tp2/docker-compose.yml), [Dockerfile pipeline](pipeline/Dockerfile), [Dockerfile Spark](spark/Dockerfile) |
| Configuration Prometheus et dashboard Grafana | [prometheus.yml](monitoring/prometheus.yml), [dashboard Grafana](monitoring/grafana/dashboards/datasuite.json) |
| Exemple de données propres | [échantillon CSV TP2](data/sample/weather_sensor_clean_sample.csv) |

**État TP2 :** la collecte, Kafka, l'enrichissement, le Data Lake, le
traitement PySpark, le chargement PostgreSQL, l'orchestration Docker, les
métriques de pipeline et PostgreSQL, ainsi que le dashboard Grafana ont des
fichiers de réalisation dans le dépôt. Cependant, tous les critères du sujet
ne sont pas encore démontrés par des livrables prêts à l'emploi :

- Metabase est lancé par Docker, mais aucun dashboard Metabase préconfiguré
  n'est fourni ; il faut le créer dans l'interface après le premier démarrage.
- Les métriques visibles configurées couvrent le pipeline et PostgreSQL ; la
  supervision de l'état des conteneurs et des métriques CPU/mémoire n'est pas
  fournie actuellement.
- L'exécution de bout en bout et l'affichage des dashboards doivent encore
  être validés après démarrage sur une machine disposant de Docker.

En conséquence, le **TP1 est couvert par les livrables présents**, tandis que
le **TP2 est implémenté en grande partie, mais il reste à finaliser et vérifier
la partie Data Visualization/monitoring pour pouvoir affirmer que tous ses
objectifs sont atteints**.
