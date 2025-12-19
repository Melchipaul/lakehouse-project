# Ports utilisés - Environnement DEV

## Services principaux
- **MinIO Console** : http://localhost:9011
- **MinIO API** : http://localhost:9010
- **PostgreSQL** : localhost:5432
- **Nessie** : http://localhost:19120
- **Dremio** : http://localhost:9047
- **Spark Master UI** : http://localhost:8080
- **Spark Master** : localhost:7077
- **Zeppelin** : http://localhost:8081
- **Airflow** : http://localhost:8082
- **Prometheus** : http://localhost:9090
- **Grafana** : http://localhost:3001

## Notes
- Si un port est déjà utilisé, modifiez le fichier `.env`
- Le port 9000 est souvent utilisé par d'autres services (PHP, Portainer, etc.)
- Les ports 9010-9011 sont choisis pour éviter les conflits
