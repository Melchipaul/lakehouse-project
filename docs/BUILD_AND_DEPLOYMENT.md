# 🏗️ Guide de Build et Déploiement - Projet Lakehouse

## 📋 Prérequis

- Docker 24.0+ avec BuildKit activé
- Docker Compose 2.0+
- **16 GB RAM minimum** disponibles pour Docker (stack complète 14 services)
- 30 GB d'espace disque libre

## 🌍 Multi-Environnements

Le projet supporte 3 environnements avec isolation totale :

| Environnement | Dossier | Ports | Ressources Spark |
|---------------|---------|-------|------------------|
| **DEV** | `docker/dev/` | Base (5432, 19000...) | 2 cores, 2g |
| **PREPROD** | `docker/preprod/` | +1000 (6432, 20000...) | 4 cores, 4g |
| **PROD** | `docker/prod/` | +2000 (7432, 21000...) | 8 cores, 8g |

## 🚀 Démarrage rapide

### 1. Préparation des credentials

```bash
# Choisir l'environnement
cd docker/dev      # ou preprod, prod

# Copier le template de configuration
cp .env.example .env

# Éditer .env et remplacer TOUS les CHANGEME_*
nano .env  # ou vim, code, etc.
```

### 2. Build des images custom (première fois)

⚠️ **Important**: Le build de Livy prend **15-25 minutes** car il compile depuis les sources.

```bash
# Build Livy (obligatoire)
docker compose build livy

# Build Zeppelin (optionnel, pour dark mode)
docker compose build zeppelin

# Build Superset (obligatoire pour connexion Dremio)
docker compose build superset
```

### 3. Lancement de la stack complète

```bash
# Lancer tous les 14 services en arrière-plan
docker compose up -d

# Suivre les logs en temps réel
docker compose logs -f

# Suivre uniquement Livy (pour vérifier le démarrage)
docker compose logs -f livy
```

## 🔍 Vérification du déploiement

### Services et healthchecks

```bash
# Vérifier l'état de tous les services (14 containers)
docker compose ps

# Vérifier les healthchecks
docker compose ps | grep -E "healthy|Up"
```

### Accès aux interfaces web (DEV)

| Service | URL | Credentials |
|---------|-----|-------------|
| **MinIO Console** | http://localhost:19001 | Voir `.env` |
| **Spark Master UI** | http://localhost:8080 | - |
| **Nessie API** | http://localhost:19120/api/v2 | - |
| **Livy REST API** | http://localhost:8998 | - |
| **Zeppelin Notebook** | http://localhost:8081 | - |
| **Dremio** | http://localhost:9047 | Créé au 1er lancement |
| **Airflow** | http://localhost:8082 | Voir `.env` |
| **Prometheus** | http://localhost:9090 | - |
| **Grafana** | http://localhost:3001 | Voir `.env` |
| **Superset** | http://localhost:8088 | Voir `.env` |

### Tests de connectivité

```bash
# Test PostgreSQL
docker exec dev-postgres pg_isready -U lakehouse

# Test MinIO
curl http://localhost:19000/minio/health/live

# Test Nessie
curl http://localhost:19120/api/v2/config

# Test Livy
curl http://localhost:8998/version

# Test Dremio
curl http://localhost:9047

# Test Airflow
curl http://localhost:8082/health

# Test Superset
curl http://localhost:8088/health

# Test Prometheus
curl http://localhost:9090/-/healthy

# Test Grafana
curl http://localhost:3001/api/health
```

## 🧪 Test de session Spark via Livy

### Créer une session interactive

```bash
# Créer une session Spark
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "kind": "pyspark",
    "conf": {
      "spark.executor.memory": "1g",
      "spark.driver.memory": "1g"
    }
  }'

# Récupérer l'ID de session (ex: 0)
SESSION_ID=0

# Vérifier l'état de la session
curl http://localhost:8998/sessions/$SESSION_ID
```

### Exécuter du code Spark

```bash
# Exemple: compter les lignes d'un DataFrame
curl -X POST http://localhost:8998/sessions/$SESSION_ID/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.range(0, 100).count()"
  }'

# Récupérer le résultat
STATEMENT_ID=0
curl http://localhost:8998/sessions/$SESSION_ID/statements/$STATEMENT_ID
```

### Test Iceberg + Nessie

```python
# Via Zeppelin ou via Livy
curl -X POST http://localhost:8998/sessions/$SESSION_ID/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"CREATE NAMESPACE IF NOT EXISTS nessie.demo\")"
  }'
```

## 🛠️ Commandes de maintenance

### Rebuild d'un service spécifique

```bash
# Rebuild Livy après modification du Dockerfile
docker compose build --no-cache livy
docker compose up -d livy

# Rebuild Zeppelin
docker compose build --no-cache zeppelin
docker compose up -d zeppelin
```

### Logs et debugging

```bash
# Logs de tous les services
docker compose logs

# Logs d'un service spécifique (dernières 100 lignes)
docker compose logs --tail=100 livy

# Suivre les logs en continu
docker compose logs -f livy spark-master

# Vérifier les variables d'environnement d'un container
docker exec dev-livy env | grep -E "SPARK|MINIO|LIVY"
```

### Restart et nettoyage

```bash
# Redémarrer un service
docker compose restart livy

# Redémarrer toute la stack
docker compose restart

# Arrêter proprement
docker compose down

# Arrêter ET supprimer les volumes (⚠️ perte de données)
docker compose down -v

# Nettoyer les images inutilisées
docker image prune -f
```

## 🐛 Troubleshooting

### Problème: "All masters are unresponsive"

**Cause**: Livy ne peut pas se connecter à Spark Master

**Solutions**:
```bash
# Vérifier que Spark Master est démarré
docker compose ps spark-master

# Vérifier les logs Spark Master
docker compose logs spark-master

# Vérifier la résolution DNS
docker exec dev-livy ping -c 3 spark-master

# Redémarrer dans l'ordre
docker compose restart spark-master
docker compose restart spark-worker
docker compose restart livy
```

### Problème: Credentials MinIO non injectés

**Cause**: Variables d'environnement manquantes

**Solutions**:
```bash
# Vérifier que .env existe et contient les credentials
cat docker/dev/.env | grep MINIO

# Vérifier l'injection dans le container
docker exec dev-livy cat /opt/livy/conf/spark-defaults.conf | grep s3a.access.key

# Relancer avec variables explicites
docker compose down
docker compose up -d
```

### Problème: Build Livy échoue

**Cause**: Timeout Maven ou manque de RAM

**Solutions**:
```bash
# Augmenter la RAM Docker (Docker Desktop > Settings > Resources)
# Minimum 6 GB recommandés pour le build

# Retry avec cache Docker
docker compose build livy

# Si échec persistant, build avec plus de verbosité
docker build --progress=plain -t lakehouse-livy:latest ../livy-custom/
```

### Problème: Port déjà utilisé

**Cause**: Un autre service utilise le même port

**Solutions**:
```bash
# Identifier le processus qui utilise le port (ex: 8998)
sudo lsof -i :8998

# Modifier le port dans .env
echo "LIVY_PORT=9998" >> .env

# Redémarrer
docker compose up -d
```

## 📊 Monitoring des ressources

```bash
# Voir la consommation CPU/RAM en temps réel
docker stats

# Voir uniquement les services lakehouse
docker stats $(docker ps --filter "name=dev-" --format "{{.Names}}")

# Espace disque utilisé par les volumes
docker system df -v
```

## 🔄 Mise à jour des versions

### Mettre à jour Spark

1. Modifier [docker-compose.yml](docker-compose.yml):
   ```yaml
   spark-master:
     image: apache/spark:3.5.5-python3  # Nouvelle version
   ```

2. Mettre à jour le Dockerfile Livy:
   ```dockerfile
   FROM apache/spark:3.5.5-python3
   ```

3. Rebuild et redéployer:
   ```bash
   docker compose down
   docker compose build --no-cache
   docker compose up -d
   ```

### Mettre à jour Iceberg/Nessie

Modifier [docker/livy-custom/spark-defaults.conf.template](../livy-custom/spark-defaults.conf.template):
```properties
spark.jars.packages  org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.8.0,...
```

Rebuild Livy:
```bash
docker compose build --no-cache livy
docker compose up -d livy
```

## 📦 Backup et restauration

### Backup des données

```bash
# Backup des volumes Docker
docker run --rm \
  -v dev-postgres-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/postgres-$(date +%Y%m%d).tar.gz /data

# Backup MinIO (via mc client)
docker exec dev-minio-init mc mirror myminio/warehouse-dev ./backups/warehouse-backup
```

### Restauration

```bash
# Restaurer PostgreSQL
docker run --rm \
  -v dev-postgres-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/postgres-20251221.tar.gz -C /data

# Redémarrer les services
docker compose restart postgres nessie
```

## 🎯 Next steps

1. **Configurer Dremio** → Créer source Nessie avec connexion MinIO
2. **Connecter Superset à Dremio** → URI: `dremio+flight://user:pass@dremio:32010/dremio?UseEncryption=false`
3. **Créer des tables Iceberg** → Via notebook Zeppelin ou API Livy
4. **Tester les branches Nessie** → Git-like versioning pour les données
5. **Configurer alertes Grafana** → Ajouter rules sur les métriques
6. **Créer DAGs Airflow** → Pipelines ETL automatisés

## 📚 Documentation supplémentaire

- [Architecture complète](./ARCHITECTURE.md)
- [Décisions d'architecture](./ARCHITECTURE_DECISIONS.md)
- [Configuration Zeppelin](./zeppelin-configuration.md)
- [Apache Livy REST API](https://livy.incubator.apache.org/docs/latest/rest-api.html)
- [Apache Iceberg Docs](https://iceberg.apache.org/)
- [Project Nessie Docs](https://projectnessie.org/)
- [Dremio Docs](https://docs.dremio.com/)
- [Airflow Docs](https://airflow.apache.org/docs/)
- [Superset Docs](https://superset.apache.org/docs/)

---

**Besoin d'aide ?** Vérifier les logs avec `docker compose logs -f` et consulter [ARCHITECTURE.md](./ARCHITECTURE.md#troubleshooting).
