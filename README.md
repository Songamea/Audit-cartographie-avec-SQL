# Guide de démarrage du projet

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
│   └── docker-compose.yml
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

## 3. Étapes pour initialiser le TP

### Étape 1 : vérifier Docker

```powershell
docker --version
```

Si cette commande ne fonctionne pas, il faut démarrer Docker Desktop ou installer Docker Engine.

### Étape 2 : lancer le projet

Depuis la racine du projet :

```powershell
python .\scripts\setup_project.py
```

Ce script :
- vérifie que les fichiers sont présents
- vérifie que Docker est accessible
- lance le conteneur PostgreSQL via Docker Compose

### Étape 3 : vérifier la base

```powershell
docker compose -f docker/docker-compose.yml exec postgres psql -U audit_user -d transport_velo
```

### Étape 4 : ouvrir le rapport complet

Une fois le projet lancé, tu peux ouvrir le rapport détaillé ici :

- [docs/Rapport TP1.md](docs/Rapport%20TP1.md)

---

## 4. Rôle des fichiers principaux

- [data/pc_captv_p.csv](data/pc_captv_p.csv) : données source
- [database/sql/postgresql_schema.sql](database/sql/postgresql_schema.sql) : crée les tables et charge le CSV
- [database/models/modele_logique.dbml](database/models/modele_logique.dbml) : modèle logique
- [docker/docker-compose.yml](docker/docker-compose.yml) : configuration Docker PostgreSQL
- [docs/DOCKER.md](docs/DOCKER.md) : fiche technique Docker
- [scripts/setup_project.py](scripts/setup_project.py) : script de lancement automatique

---

## 5. Ce qui se passe concrètement

Le script Python ne remplace pas le SQL.

Il fait juste :
1. vérifier l’environnement
2. lancer Docker Compose

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

