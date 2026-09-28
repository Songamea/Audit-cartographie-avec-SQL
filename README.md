# Audit et cartographie des données — TP1 et TP2

Projet sur les données de mobilité cyclable de Bordeaux Métropole.

- **TP1** : audit du CSV, modélisation et chargement PostgreSQL.
- **TP2** : pipeline météo avec Kafka, Data Lake, Spark, PostgreSQL,
  Metabase, Prometheus et Grafana.

Les deux TPs ont deux fichiers Compose séparés. Le TP1 crée le conteneur
PostgreSQL **`Velib-Bordeaux`** ; le TP2 le laisse actif et utilise directement
sa base via un réseau Docker commun. Il n'y a donc ni deuxième serveur
PostgreSQL ni arrêt du TP1 entre les deux étapes.

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

Le résultat attendu est un nombre de capteurs supérieur à zéro. Garde le
conteneur **`Velib-Bordeaux` démarré** : le script TP2 en a besoin.

Dans Docker Desktop, ce serveur PostgreSQL apparaît dans **Containers** sous
le nom `Velib-Bordeaux`. Le stockage persistant peut aussi se vérifier dans
**Volumes** ou avec :

```powershell
docker volume ls
docker volume inspect tp1_postgres_data_tp1
```

### 2. Lancer le TP2 sans arrêter PostgreSQL

Dans un autre terminal, ou après le retour du script TP1 :

```powershell
python .\scripts\setup_tp2.py
```

Le script vérifie que `Velib-Bordeaux` est actif et que la base contient les
capteurs. Il ajoute la table `weather_sensor_clean` au PostgreSQL du TP1, puis
démarre les autres services sur le même réseau Docker. Il ne redémarre ni ne
recrée PostgreSQL.

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
docker compose -f docker/tp1/docker-compose.yml exec postgres `
  psql -U audit_user -d transport_velo
```

Pour Metabase, utiliser l'hôte Docker `postgres`, le port `5432`, la base
`transport_velo`, l'utilisateur `audit_user` et le mot de passe
`audit_password`.

Contrôler les résultats TP2 :

```powershell
docker compose -f docker/tp1/docker-compose.yml exec postgres `
  psql -U audit_user -d transport_velo `
  -c "SELECT COUNT(*) AS clean_records FROM weather_sensor_clean;"
```

## Arrêt et réinitialisation

Arrêter les services TP2 en laissant PostgreSQL démarré :

```powershell
docker compose -f docker/tp2/docker-compose.yml down
```

Quand tu veux aussi arrêter PostgreSQL, sans effacer sa base :

```powershell
docker compose -f docker/tp1/docker-compose.yml down
```

Pour réinitialiser les TPs et **effacer définitivement** la base et les
données Docker :

```powershell
python .\scripts\reset_project.py
```

Puis reprendre le parcours depuis l'étape 1. Le script de reset utilise
`down -v` et supprime les volumes ; ce n'est pas un simple arrêt.

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
