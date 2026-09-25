# Guide de démarrage du projet

Le TP2 ajoute une plateforme DataSuite complète au modèle du TP1 : API Open-Meteo, Kafka, Data Lake, PySpark, PostgreSQL, Metabase, Prometheus et Grafana. Le rapport détaillé est dans [docs/TP2.md](docs/TP2.md).

Ce document est le README d’instruction pour l’utilisateur.

Il ne contient pas le rapport TP1. Le rapport détaillé est dans [docs/Rapport TP1.md](docs/Rapport%20TP1.md).

---

## 1. Arborescence du projet

```text
Audit-cartographie-avec-SQL/
├── README.md
├── docs/
│   ├── DOCKER.md
│   ├── Rapport TP1.md
│   └── Support_Audit_Cartographie_Donnees.pdf
├── data/
│   ├── pc_captv_p.csv
│   └── diagrame.png
├── database/
│   ├── models/
│   │   └── modele_logique.dbml
│   └── sql/
│       └── postgresql_schema.sql
├── docker/
│   ├── tp1/docker-compose.yml
│   └── tp2/docker-compose.yml
├── scripts/
│   ├── setup_project.py
│   └── reset_db.ps1
└── .git/
```

---

## 2. Prérequis

Il faut avoir installé :
- Python 3
- Docker Desktop ou Docker Engine
- Docker démarré sur la machine

---

## 3. Étapes pour initialiser le TP2

### Étape 1 : vérifier Docker

```powershell
docker --version
```

Si cette commande ne fonctionne pas, il faut démarrer Docker Desktop ou installer Docker Engine.

### Étape 2 : lancer le projet

Depuis la racine du projet :

```powershell
docker compose -f docker/tp2/docker-compose.yml up -d --build
```

Cette commande construit les images et lance toute la chaîne : collecte API, Kafka, source CSV, agrégation, Data Lake, Spark, PostgreSQL, Metabase, Prometheus et Grafana.

Le script `python .\scripts\setup_project.py` reste disponible comme raccourci et vérifie Docker avant le lancement.

### Étape 3 : vérifier la base

```powershell
docker compose -f docker/tp2/docker-compose.yml exec postgres psql -U audit_user -d transport_velo
```

### Étape 4 : ouvrir le rapport complet

Une fois le projet lancé, tu peux ouvrir le rapport détaillé ici :

- [docs/Rapport TP1.md](docs/Rapport%20TP1.md)
- [docs/TP2.md](docs/TP2.md)

---

## 4. Rôle des fichiers principaux

- [data/pc_captv_p.csv](data/pc_captv_p.csv) : données source
- [data/sample/weather_sensor_clean_sample.csv](data/sample/weather_sensor_clean_sample.csv) : échantillon partageable de 10 événements TP2
- [database/sql/postgresql_schema.sql](database/sql/postgresql_schema.sql) : crée les tables et charge le CSV
- [database/models/modele_logique.dbml](database/models/modele_logique.dbml) : modèle logique
- [docker/tp2/docker-compose.yml](docker/tp2/docker-compose.yml) : orchestration Docker de la plateforme TP2
- [docker/tp1/docker-compose.yml](docker/tp1/docker-compose.yml) : configuration Docker PostgreSQL du TP1
- [docs/DOCKER.md](docs/DOCKER.md) : fiche technique Docker
- [scripts/setup_project.py](scripts/setup_project.py) : script de lancement automatique

---

## 5. Ce qui se passe concrètement

Le script Python ne remplace pas le SQL. Pour le TP2, le Compose `docker/tp2/docker-compose.yml` orchestre l'ensemble des services.

Il fait :
1. vérifier l’environnement
2. lancer Docker Compose pour toute la plateforme

Ensuite, le fichier SQL fait le vrai travail :
- créer la base de données
- créer les tables
- créer les relations
- importer le CSV
- insérer les données de test

---

## 6. Commande de reset

Si tu veux reconstruire la base complètement :

```powershell
./scripts/reset_db.ps1
```

---

## 7. Documentation complémentaire

- [docs/DOCKER.md](docs/DOCKER.md)
- [docs/Rapport TP1.md](docs/Rapport%20TP1.md)

Tu peux maintenant passer au rapport complet pour la partie analyse métier, dictionnaire, modèle conceptuel et logique, ainsi que la justification de la modélisation.

