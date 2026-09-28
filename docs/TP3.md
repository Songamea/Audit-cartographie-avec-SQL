# TP3 - Audit qualite et nettoyage des donnees

## Objectif et perimetre

Ce TP prolonge le pipeline TP2. Il audite la table PostgreSQL `weather_sensor_clean`, corrige les erreurs explicables par une source de reference, met en quarantaine les lignes invalides ou redondantes et conserve les mesures avant/apres dans la base. Les suppressions sont ainsi recuperables et chaque execution est tracee.

La cartographie logique complete est dans [modele_logique.dbml](../database/models/modele_logique.dbml). La table TP2 est alimentee par Open-Meteo et enrichie avec le capteur cyclable le plus proche issu de `data/pc_captv_p.csv`.

## Cartographie cible

| Objet | Source / rôle | Champs principaux | Types et contraintes |
| --- | --- | --- | --- |
| `sensor_type` | Référentiel des types de capteurs | `code`, `label` | `code` PK, texte non nul |
| `traffic_zone` | Référentiel des zones | `zone_code`, `source_label` | `zone_code` PK, entier |
| `sensor` | Inventaire CSV Bordeaux Métropole | `gid`, `ident`, `type_code`, `zone_code`, coordonnées, dates | `gid` PK, `ident` unique, FK type et zone, coordonnées valides |
| `sensor_measurement` | Comptage de l'inventaire TP1 | `sensor_gid`, `comptage_5m`, `observed_at` | `sensor_gid` PK/FK vers `sensor`; comptage nullable et non négatif |
| `weather_sensor_clean` | Evénements météo enrichis, table auditée | `event_id`, `observed_at`, `collected_at`, mesures météo, `sensor_gid`, copie des attributs capteur, `processed_at` | `event_id` UUID PK; FK `sensor_gid` vers `sensor.gid`; temps en `timestamptz`; mesures en `numeric`; comptage nullable |

**Grain métier retenu :** une observation par couple `(sensor_gid, observed_at)`. `event_id` identifie une publication Kafka et ne garantit pas l'unicité d'une mesure, car chaque interrogation API reçoit un nouvel UUID. L'API utilisée fournit l'observation courante, pas une révision historique.

## Matrice de contrôles

| Dimension | Contrôle SQL | Niveau | Décision |
| --- | --- | --- | --- |
| Complétude | Champs obligatoires nuls; mesures météo optionnelles manquantes; comptage vélo absent | Fort pour les champs obligatoires, faible pour les mesures optionnelles | Les champs obligatoires sont déjà protégés par `NOT NULL`. Les champs météo optionnels et le comptage restent nuls si la source ne les fournit pas. |
| Unicité | UUID `event_id`; doublons au grain capteur/instant | Critique pour UUID, moyen pour le grain métier | Garder l'événement le plus récemment collecté; archiver les autres. |
| Validité | Plages météo plausibles et coordonnées géographiques | Fort | Archiver les mesures hors plage, sans inventer de valeur de remplacement. |
| Cohérence | Observation Open-Meteo postérieure à la collecte; copie capteur différente du référentiel | Fort pour les dates, moyen pour la copie capteur | Convertir l'heure locale connue en UTC; remplacer la copie par les valeurs du référentiel. |
| Intégrité | Existence du capteur associé et FK | Critique | La FK est déjà garantie en base; l'audit vérifie aussi les attributs recopiés. |
| Validité métier | Domaine de `source` | Moyen | Vérifier la valeur `open-meteo`; les autres valeurs sont signalées. |

Les limites retenues pour les mesures sont température `[-90, 60] °C`, humidité `[0, 100] %`, vent `[0, 300] km/h`, précipitations positives ou nulles et comptage vélo positif ou nul. Elles servent à isoler des valeurs manifestement aberrantes, pas à remplacer un contrôle météorologique spécialisé.

## Anomalies et décisions

L'échantillon versionné dans [weather_sensor_clean_sample.csv](../data/sample/weather_sensor_clean_sample.csv) contient 10 lignes. Les 10 UUID sont distincts, mais les 10 lignes ont `sensor_gid = 2615` et le même `observed_at`; elles ont été collectées à environ 30 secondes d'intervalle. Au grain métier retenu, cela représente un groupe et **9 lignes excédentaires**. La ligne la plus récente, collectée à `14:25:16 UTC`, est conservée; les neuf autres sont archivées comme `DUPLICATE_SENSOR_OBSERVATION`.

Dans cet échantillon, `observed_at` vaut `16:15+00` alors que `collected_at` se situe vers `14:20-14:25+00`. Open-Meteo est appelé avec le fuseau `Europe/Paris`, mais le TP2 publiait une heure locale sans décalage; elle pouvait être interprétée comme UTC. Le producteur normalise désormais le timestamp en UTC avant publication. Le nettoyage réinterprète les anciennes heures erronées en heure Europe/Paris puis UTC. Sur l'échantillon, `16:15` heure de Paris devient `14:15 UTC`, antérieure à la collecte.

Les mesures météo nulles restent nulles car elles sont optionnelles. Le champ `comptage_5m` peut aussi être nul : le CSV est un inventaire, pas un historique de comptages, donc aucune imputation ne serait défendable. TP2 remplaçait déjà une précipitation API absente par zéro avant PostgreSQL; cette perte de distinction entre « absent » et « aucune précipitation » ne peut pas être annulée par TP3.

## Scripts et exécution

Les quatre scripts SQL sont montés en lecture seule dans le conteneur PostgreSQL sous `/tp3`. Depuis la racine du projet, appliquer les étapes dans cet ordre :

```powershell
docker compose -f docker/tp2/docker-compose.yml up -d --build
docker compose -f docker/tp2/docker-compose.yml stop spark
docker compose -f docker/tp2/docker-compose.yml exec -T postgres psql -U audit_user -d transport_velo -f /tp3/tp3_quality_schema.sql
docker compose -f docker/tp2/docker-compose.yml exec -T postgres psql -U audit_user -d transport_velo -v phase=before -f /tp3/audit_quality.sql
docker compose -f docker/tp2/docker-compose.yml exec -T postgres psql -U audit_user -d transport_velo -f /tp3/clean_quality.sql
docker compose -f docker/tp2/docker-compose.yml exec -T postgres psql -U audit_user -d transport_velo -v phase=after -f /tp3/audit_quality.sql
docker compose -f docker/tp2/docker-compose.yml exec -T postgres psql -U audit_user -d transport_velo -f /tp3/report_quality.sql
docker compose -f docker/tp2/docker-compose.yml up -d spark
```

| Fichier | Fonction |
| --- | --- |
| `database/sql/tp3_quality_schema.sql` | Crée le journal d'exécution, les résultats de contrôles, le journal des corrections, la quarantaine et la liste d'exclusion consultée par Spark. Réexécutable sans effacer l'historique. |
| `database/sql/audit_quality.sql` | Enregistre les contrôles d'une phase `before` ou `after`; chaque résultat donne le nombre contrôlé, le nombre d'anomalies, la gravité et le taux. |
| `database/sql/clean_quality.sql` | Normalise les anciens timestamps, rafraîchit la copie du référentiel capteur, puis archive et retire les valeurs impossibles, dates restant futures et doublons métier. Une transaction rend l'opération atomique et crée un index unique sur `(sensor_gid, observed_at)`. |
| `database/sql/report_quality.sql` | Compare les derniers résultats avant/après et résume les lignes gardées en quarantaine et les corrections. |

Les tables `tp3_quality_run`, `tp3_quality_check`, `tp3_quality_correction`, `tp3_quality_quarantine` et `tp3_quality_exclusion` gardent les résultats côté base. Il faut arrêter Spark pendant l'audit et le nettoyage pour figer la cible. Après reprise, Spark ignore les UUID en quarantaine et la contrainte unique bloque les doublons au grain métier. Les scripts de nettoyage sont réexécutables; ne pas supprimer la quarantaine si une restauration est nécessaire.

## Résultats avant/après

Audit réellement exécuté le 28/09/2026 sur PostgreSQL TP2. Le premier état contrôlé comptait 552 lignes. Lors de cette première séquence, Spark a réimporté des événements depuis le JSONL après leur suppression; Spark a ensuite été arrêté, les protections anti-rejeu ont été ajoutées et le nettoyage relancé. Deux nouvelles observations valides sont arrivées pendant les différentes phases, d'où un delta net de 529 lignes malgré 531 doublons archivés.

| Contrôle | Avant | Après nettoyage stabilisé |
| --- | ---: | ---: |
| Lignes dans `weather_sensor_clean` | 552 | 23 |
| Champs obligatoires manquants | 0 | 0 |
| Comptages vélo manquants, optionnels | 552 | 23 |
| Mesures météo optionnelles manquantes | 0 | 0 |
| Observations postérieures à la collecte | 552 | 0 |
| Lignes excédentaires au grain `(sensor_gid, observed_at)` | 531 | 0 |
| Mesures hors plage et coordonnées invalides | 0 | 0 |
| Incohérences avec le référentiel capteur | 0 | 0 |

La quarantaine contient **531 événements** `DUPLICATE_SENSOR_OBSERVATION`; la liste d'exclusion Spark contient également 531 UUID. Le journal enregistre la correction des dates (552 événements lors du premier passage, puis 531 réimportés avant l'ajout des protections). Après redémarrage, Spark a retraité le JSONL sans réintroduire les événements exclus; le dernier contrôle a confirmé **23 lignes pour 23 clés métier** et zéro anomalie. La différence entre les contrôles successifs correspond à une nouvelle observation météo valide, pas à un doublon.

Le fichier versionné de 10 lignes reste une preuve facilement partageable du motif d'origine : un groupe de dix publications pour un seul capteur et instant, soit neuf doublons excédentaires.

## Synthèse pour la restitution orale

Le contrôle principal a montré que des identifiants d'événement uniques ne suffisent pas à identifier des mesures uniques : dix publications successives décrivaient la même observation météo du même capteur. Le défaut de fuseau expliquait aussi des observations apparemment postérieures à leur collecte. TP3 corrige l'interprétation temporelle avec le fuseau connu, rafraîchit les attributs depuis le référentiel officiel, puis conserve la publication la plus récente au grain métier retenu. Les lignes écartées restent consultables en quarantaine et les compteurs avant/après sont persistés pour rendre l'audit reproductible. Les comptages vélo manquants ne sont pas imputés, car la source disponible ne contient pas d'historique permettant de les reconstruire.