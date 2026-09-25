# Echantillon de donnees TP2

`weather_sensor_clean_sample.csv` contient les 10 derniers evenements propres exportes depuis PostgreSQL le 25/09/2026.

Cet echantillon est versionne dans Git pour permettre a une autre personne de voir un resultat concret sans recuperer les volumes Docker locaux. Le pipeline complet ne depend pas de ce fichier : au demarrage, il interroge Open-Meteo et produit de nouvelles donnees.

Colonnes :

- meteo : `observed_at`, `temperature_c`, `humidity_pct`, `wind_speed_kmh`, `precipitation_mm`
- capteur rapproche : `sensor_gid`, `sensor_ident`, `sensor_type`, `zone`, coordonnees et libelle
- traçabilite : `event_id`, `collected_at`, `processed_at`, `source`
