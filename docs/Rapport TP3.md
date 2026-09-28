# TP3 — Audit qualité et nettoyage des données

## Objectif et périmètre

Le TP3 contrôle les événements météorologiques enrichis chargés par le TP2
dans `public.weather_sensor_clean`. La table `public.sensor`, créée au TP1,
sert de référence pour les attributs du capteur. L'audit ne modifie rien ; le
nettoyage est séparé, transactionnel et réexécutable.

La cartographie complète des traitements se trouve dans
[Cartographie TP3](Cartographie%20TP3.md). Le périmètre est la table finale
PostgreSQL : les rejets qui n'entrent jamais dans cette table (par exemple un
JSON illisible) doivent être suivis dans les logs du pipeline et ne sont pas
comptés par l'audit SQL.

## Matrice des contrôles qualité

| Dimension | Contrôle | Règle attendue | Gravité | Traitement |
| --- | --- | --- | --- | --- |
| Complétude | Champs obligatoires | Identifiants, dates, source et métadonnées du capteur non nuls/non vides | Haute | Les contraintes SQL empêchent les NULL ; les métadonnées sont restaurées depuis `sensor` si la FK est valide. |
| Complétude | Météo facultative | Température, humidité et vent peuvent être absents | Information | Absence mesurée mais non imputée. |
| Unicité | `event_id` | Un identifiant par événement | Haute | Clé primaire ; contrôle défensif par regroupement. |
| Validité | Température | Valeur finie entre -90 et 60 °C | Moyenne | Valeur hors plage/non finie mise à NULL. |
| Validité | Humidité | Entre 0 et 100 % | Moyenne | Valeur hors plage mise à NULL. |
| Validité | Vent | Valeur finie supérieure ou égale à 0 km/h | Moyenne | Valeur négative/non finie mise à NULL. |
| Validité | Précipitations | Valeur finie supérieure ou égale à 0 mm | Moyenne | Valeur négative/non finie substituée par 0, exigé par le schéma cible. |
| Validité | Coordonnées et comptage | Latitude [-90, 90], longitude [-180, 180], comptage ≥ 0 | Haute/moyenne | Coordonnées restaurées depuis `sensor`; le `CHECK` du comptage bloque les valeurs négatives. |
| Cohérence | Métadonnées du capteur | `ident`, type, zone, coordonnées et libellé concordent avec `sensor_gid` | Haute | Remplacement par la valeur canonique de `sensor`. |
| Intégrité | Référence capteur | Chaque événement référence un `sensor.gid` existant | Critique | Clé étrangère ; les orphelins ne peuvent pas être enregistrés. |

Les plages de température servent de garde-fou général, pas de seuil
climatologique bordelais. Chaque valeur météo est traitée séparément ; aucune
valeur manquante n'est transformée artificiellement en moyenne.

## Exécution

Prérequis : le conteneur PostgreSQL `Velib-Bordeaux` est démarré et le
pipeline TP2 a déjà créé et alimenté `weather_sensor_clean`. Le reste des
services TP2 peut être arrêté si l'on souhaite auditer uniquement la base.
Depuis la racine :

```powershell
python .\scripts\setup_tp3.py
```

Le script exécute dans l'ordre :

1. l'audit SQL avant nettoyage ;
2. le nettoyage transactionnel ;
3. le même audit après nettoyage.

Les résultats datés sont enregistrés dans `reports/tp3/` :

- `quality_before_<date>.csv` ;
- `cleaning_actions_<date>.csv` ;
- `quality_after_<date>.csv`.

Comparer `issue_count` dans les deux audits. Le nombre de lignes vérifiées
figure dans `checked_rows`. Les anomalies sont comptées par contrôle ; une
même ligne peut apparaître dans plusieurs contrôles et il ne faut donc pas
additionner ces comptes pour annoncer un nombre de lignes distinctes.

Les scripts SQL peuvent aussi être exécutés séparément via le client
PostgreSQL du Compose TP1 :

- [tp3_audit.sql](../database/sql/tp3_audit.sql) ;
- [tp3_clean.sql](../database/sql/tp3_clean.sql).

## Décisions et traçabilité

- Les anomalies météo hors domaine sont rendues inconnues (`NULL`) plutôt
  que supprimées : l'événement et ses autres mesures restent exploitables.
- Les précipitations négatives sont remplacées par zéro, conformément au
  `NOT NULL DEFAULT 0` du schéma TP2. Le nombre de corrections est conservé
  dans le résultat du nettoyage.
- Les attributs capteur copiés dans la table d'événements sont dénormalisés
  pour l'analyse ; en cas d'écart, `sensor_gid` désigne la ligne canonique.
- Les événements sans capteur ne sont pas supprimés silencieusement : la FK
  les empêche d'entrer dans la table.
- Les champs météo optionnels absents ne sont pas imputés.
- Une source vide ou composée d'espaces est signalée en complétude, mais n'est
  pas remplacée automatiquement : le système ne doit pas deviner la provenance.

Le nettoyage ne supprime pas les événements et n'invente pas de valeurs
météorologiques. Chaque exécution produit un nouveau jeu de résultats datés ;
les fichiers précédents sont conservés.

## Résultats

Exécution réelle sur la base du projet le **28 septembre 2026** :

- **59 événements** contrôlés avant et après nettoyage ;
- **11 contrôles** exécutés ;
- **0 anomalie** détectée avant nettoyage et **0 après** ;
- les **6 règles de correction** ont chacune corrigé **0 ligne**.

Cela signifie que les données auditées étaient déjà conformes aux contrôles
implémentés ; aucune correction artificielle n'a été appliquée. Les fichiers
bruts de cette exécution sont disponibles :

- [Audit avant nettoyage](../reports/tp3/quality_before_20260928T084027.537201Z.csv) ;
- [Actions de nettoyage](../reports/tp3/cleaning_actions_20260928T084027.537201Z.csv) ;
- [Audit après nettoyage](../reports/tp3/quality_after_20260928T084027.537201Z.csv).

Les nombres futurs dépendront des événements présents à l'exécution. Le script
conserve chaque nouveau résultat avec son horodatage, sans écraser ces
fichiers.

## Synthèse pour la restitution orale

> Nous avons audité la table finale produite par le pipeline TP2 selon cinq
> dimensions : complétude, unicité, validité, cohérence et intégrité. Les
> clés et contraintes SQL protègent déjà plusieurs invariants. Nous avons
> conservé les événements, neutralisé uniquement les mesures hors domaine,
> réaligné les métadonnées capteur sur la référence du TP1 et mesuré les
> contrôles avant et après. Les CSV horodatés permettent de montrer les
> anomalies observées et l'effet exact des corrections, sans inventer de
> résultats.
