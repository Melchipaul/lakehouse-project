# Architecture Lakehouse - Documentation Technique

## 🏗️ Vue d'Ensemble

Stack moderne de Data Lakehouse complète (14 services) combinant Apache Iceberg, Nessie, Spark, Dremio, Airflow, et une suite de monitoring/BI.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              USER INTERFACES                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│  Zeppelin    │  Dremio    │  Airflow   │  Superset  │  Grafana   │  MinIO      │
│  :8081       │  :9047     │  :8082     │  :8088     │  :3001     │  :19001     │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
            ┌───────────────────────────┼───────────────────────────┐
            ▼                           ▼                           ▼
┌───────────────────────┐  ┌─────────────────────────┐  ┌───────────────────────┐
│   ORCHESTRATION       │  │   COMPUTE & EXECUTION   │  │   SQL QUERY ENGINE    │
├───────────────────────┤  ├─────────────────────────┤  ├───────────────────────┤
│  Apache Airflow 2.10  │  │     Apache Livy         │  │    Dremio OSS         │
│  - Webserver          │  │   REST API for Spark    │  │  - Nessie Source      │
│  - Scheduler          │  │        :8998            │  │  - Arrow Flight       │
│        :8082          │  │                         │  │    :9047, :32010      │
└───────────────────────┘  │  ┌───────────────────┐  │  └───────────────────────┘
                           │  │ Spark 3.5.4       │  │
                           │  │ Master + Worker   │  │
                           │  │ :7077, :8080      │  │
                           │  └───────────────────┘  │
                           └─────────────────────────┘
                                        │
            ┌───────────────────────────┼───────────────────────────┐
            ▼                           ▼                           ▼
┌───────────────────────┐  ┌─────────────────────────┐  ┌───────────────────────┐
│   CATALOG & METADATA  │  │    STORAGE LAYER        │  │     MONITORING        │
├───────────────────────┤  ├─────────────────────────┤  ├───────────────────────┤
│  Nessie (Git-like)    │  │  MinIO (S3-compatible)  │  │  Prometheus :9090     │
│  + Iceberg 1.7.0      │  │  API: :19000            │  │  + Postgres Exporter  │
│       :19120          │  │  Console: :19001        │  │                       │
│                       │  │                         │  │  Grafana :3001        │
│  Backend:             │  │  Buckets:               │  │  - Dashboards         │
│  PostgreSQL 17 :5432  │  │  - warehouse-{env}/     │  │  - Alerting           │
└───────────────────────┘  └─────────────────────────┘  └───────────────────────┘
```

---

## 📦 Composants

### **1. Apache Spark 3.5.4** (Compute Engine)
- **Rôle** : Moteur de traitement distribué
- **Mode** : Standalone cluster (1 master + 1 worker)
- **URL Master** : `spark://spark-master:7077`
- **UI** : http://localhost:8080
- **Configurations** :
  - Iceberg catalog integration
  - S3A filesystem (MinIO)
  - Nessie catalog REST API

### **2. Apache Livy** (REST API)
- **Rôle** : Interface REST pour soumettre des jobs Spark
- **Version** : master (compilé avec Spark 3.5)
- **Port** : 8998
- **Fonctionnalités** :
  - Gestion de sessions Spark interactives
  - Injection automatique des credentials MinIO
  - Support Scala, Python, R

### **3. Apache Iceberg 1.7.0** (Table Format)
- **Rôle** : Format de table transactionnel avec schema evolution
- **Fonctionnalités** :
  - Time-travel (requêtes sur versions historiques)
  - Schema evolution (ajout/suppression colonnes)
  - ACID transactions
  - Partition evolution
  - Hidden partitioning
- **Catalog** : Nessie REST catalog
- **Storage** : MinIO (S3-compatible)

### **4. Project Nessie 0.106+** (Data Catalog)
- **Rôle** : Catalog Git-like pour Iceberg tables
- **Port** : 19120
- **Fonctionnalités** :
  - Branches isolées (dev, staging, prod)
  - Tags sur snapshots
  - Merge entre branches
  - Audit trail complet
- **Backend** : PostgreSQL 17
- **API** : REST v2 (`/api/v2`)

### **5. MinIO** (Object Storage)
- **Rôle** : Stockage S3-compatible pour data files
- **Ports** :
  - API : 19000
  - Console : 19001
- **Buckets** :
  - `lakehouse-dev/` : Données applicatives
  - `warehouse-dev/` : Warehouse Iceberg
- **Credentials** : Injectés via `.env` (non versionné)

### **6. PostgreSQL 17** (Metadata Backend)
- **Rôle** : Backend pour Nessie catalog
- **Port** : 5432
- **Database** : `lakehouse`
- **Tables** : Metadata Nessie (branches, commits, tables)

### **7. Apache Zeppelin 0.12.0** (Notebook UI)
- **Rôle** : Interface notebook pour data exploration
- **Port** : 8081
- **Interpréteurs** :
  - `%livy.spark` : Scala via Livy
  - `%livy.pyspark` : Python via Livy
  - `%livy.sql` : SQL via Livy
- **Configuration** : Automatique via REST API

### **8. Dremio OSS** (SQL Query Engine)
- **Rôle** : Moteur SQL pour requêtes interactives sur Iceberg
- **Ports** :
  - UI : 9047
  - ODBC/JDBC : 31010
  - Arrow Flight : 32010
- **Fonctionnalités** :
  - Requêtes SQL optimisées sur Iceberg
  - Connexion native à Nessie catalog
  - Arrow Flight pour Superset/BI tools
  - Réflexions (cache/accélération)
- **Configuration Nessie** :
  - Endpoint: `http://nessie:19120/api/v2`
  - S3 Endpoint: `minio:9000` (sans http://)
  - Path Style Access: `true`

### **9. Apache Airflow 2.10.4** (Orchestration)
- **Rôle** : Orchestration de workflows data
- **Port** : 8082
- **Composants** :
  - Webserver (UI)
  - Scheduler (exécution DAGs)
- **Backend** : PostgreSQL (database `airflow`)
- **Fonctionnalités** :
  - DAGs Python pour pipelines ETL
  - Scheduling et monitoring
  - Intégration Spark via Livy operators

### **10. Prometheus** (Metrics Collection)
- **Rôle** : Collecte et stockage de métriques
- **Port** : 9090
- **Targets configurés** :
  - `prometheus:9090` (self-monitoring)
  - `postgres-exporter:9187` (PostgreSQL metrics)
  - `minio:9000/minio/v2/metrics/cluster` (MinIO metrics)

### **11. Grafana** (Dashboards)
- **Rôle** : Visualisation des métriques
- **Port** : 3001
- **Provisioning automatique** :
  - Datasource Prometheus préconfigurée
  - Dashboard "Lakehouse Overview" inclus
- **Métriques affichées** :
  - État des services
  - Connexions PostgreSQL
  - Stockage MinIO

### **12. Apache Superset** (BI & Visualization)
- **Rôle** : Business Intelligence et dashboards data
- **Port** : 8088
- **Connexion Dremio** :
  - Driver: `sqlalchemy-dremio` + `pyarrow`
  - URI: `dremio+flight://user:pass@dremio:32010/dremio?UseEncryption=false`
- **Backend** : PostgreSQL (database `superset`)

---

## 🔐 Sécurité & Credentials

### **Architecture de Sécurité**

```
.env (local, git-ignoré)
  ├─ MINIO_ROOT_PASSWORD=***
  └─ POSTGRES_PASSWORD=***
        │
        ▼
docker-compose.yml (variables)
  ├─ environment:
  │    MINIO_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
        │
        ▼
Conteneur Livy
  ├─ Environment variables
  ├─ entrypoint.sh (injection runtime)
  └─ spark-defaults.conf (credentials injectés)
```

### **Protection Multi-Niveaux**

1. **Niveau Git** : `.env` dans `.gitignore` → jamais commité
2. **Niveau Docker** : Variables d'environnement (pas de hardcoding)
3. **Niveau Runtime** : Injection par `sed` dans entrypoint
4. **Template** : `.env.example` versionné (documentation)

### **Rotation des Credentials**

```bash
# 1. Éditer .env
nano docker/dev/.env

# 2. Rebuild services concernés
cd docker/dev
docker compose build livy zeppelin

# 3. Redémarrer
docker compose restart livy zeppelin
```

---

## 🔄 Flux de Données

### **Écriture de Données**

```
1. Zeppelin Notebook
   └─ Code Scala/Python

2. Livy REST API
   └─ Soumet job Spark

3. Spark Session
   ├─ Connexion Nessie catalog
   ├─ Résolution table Iceberg
   └─ Écriture transactionnelle

4. Iceberg
   ├─ Génération snapshot
   ├─ Écriture Parquet files → MinIO
   └─ Update metadata files

5. Nessie
   ├─ Commit metadata
   ├─ Update branch pointer
   └─ Audit trail dans PostgreSQL
```

### **Lecture de Données**

```
1. Requête SQL
   └─ SELECT * FROM nessie.demo_db.users

2. Nessie Catalog
   ├─ Résolution branche (main/dev)
   └─ Récupération metadata table

3. Iceberg
   ├─ Lecture manifest files
   ├─ Détermination data files
   └─ Optimisation pruning (partition/predicate)

4. Spark
   ├─ Lecture Parquet depuis MinIO
   ├─ Filtrage/Aggregation
   └─ Retour résultats
```

### **Time-Travel Query**

```sql
SELECT * FROM nessie.demo_db.users 
TIMESTAMP AS OF '2025-12-22 10:30:00'
```

```
1. Parser timestamp
2. Nessie → récupération snapshot ID à ce timestamp
3. Iceberg → lecture manifest correspondant
4. MinIO → lecture data files historiques
5. Retour données version passée
```

---

## 🌿 Branching avec Nessie

### **Workflow de Développement**

```
main (production)
  │
  ├─ snapshot_v1
  ├─ snapshot_v2
  └─ snapshot_v3 (HEAD)
       │
       └─── dev (branche développement)
             ├─ snapshot_dev1 (test feature A)
             ├─ snapshot_dev2 (test feature B)
             └─ snapshot_dev3 (validation)
                   │
                   └─ MERGE → main (après validation)
```

### **Commandes Nessie**

```scala
// Créer branche
spark.sql("CREATE BRANCH dev IN nessie FROM main")

// Basculer sur branche
spark.conf.set("spark.sql.catalog.nessie.ref", "dev")

// Merge branche
// Via API Nessie REST
```

---

## 📊 Métriques & Monitoring

### **Stack Monitoring**

| Composant | Rôle | Port |
|-----------|------|------|
| **Prometheus** | Collecte métriques | 9090 |
| **Grafana** | Dashboards | 3001 |
| **Postgres Exporter** | Métriques PostgreSQL | 9187 |

### **Dashboard Grafana "Lakehouse Overview"**

Le dashboard inclut :
- État des services (Prometheus, PostgreSQL, MinIO)
- Nombre de connexions PostgreSQL actives
- Métriques stockage MinIO
- Uptime des services

### **URLs de Monitoring**

| Service | URL | Métriques |
|---------|-----|-----------|
| **Prometheus** | http://localhost:9090 | Targets, alertes, queries |
| **Grafana** | http://localhost:3001 | Dashboards, alertes |
| Spark Master UI | http://localhost:8080 | Jobs, stages, executors |
| MinIO Console | http://localhost:19001 | Buckets, objects, bandwidth |
| Livy UI | http://localhost:8998/ui | Sessions actives |
| Nessie API | http://localhost:19120/api/v2 | Branches, commits |
| **Dremio** | http://localhost:9047 | Jobs, sources, reflections |
| **Airflow** | http://localhost:8082 | DAGs, runs, logs |
| **Superset** | http://localhost:8088 | Dashboards, datasets |

### **Logs Importants**

```bash
# Livy
docker compose logs livy -f

# Spark Master
docker compose logs spark-master -f

# Nessie
docker compose logs nessie -f
```

---

## 🚀 Déploiement

### **Prérequis**

- Docker 24+
- Docker Compose 2.20+
- **16 GB RAM minimum** (stack complète 14 services)
- 30 GB espace disque

### **Multi-Environnements**

| Environnement | Dossier | Ports | Buckets |
|---------------|---------|-------|---------|
| **DEV** | `docker/dev/` | Base | warehouse-dev |
| **PREPROD** | `docker/preprod/` | +1000 | warehouse-preprod |
| **PROD** | `docker/prod/` | +2000 | warehouse-prod |

### **Installation**

```bash
# 1. Cloner le repo
git clone https://github.com/Melchipaul/lakehouse-project.git

# 2. Choisir l'environnement
cd lakehouse-project/docker/dev      # ou preprod, prod

# 3. Créer .env
cp .env.example .env
nano .env  # Remplir TOUS les CHANGEME_*

# 4. Build des images custom
docker compose build livy zeppelin superset

# 5. Démarrer la stack (14 services)
docker compose up -d

# 6. Vérifier les services
docker compose ps
```

### **Vérification Santé**

```bash
# All services healthy
docker compose ps | grep -E "healthy|Up"

# Tests de connectivité
curl http://localhost:8998/version         # Livy
curl http://localhost:19120/api/v2/config  # Nessie
curl http://localhost:9047                 # Dremio
curl http://localhost:8082/health          # Airflow
curl http://localhost:8088/health          # Superset
curl http://localhost:9090/-/healthy       # Prometheus
curl http://localhost:3001/api/health      # Grafana
curl http://localhost:19000/minio/health/live
```

---

## 🔧 Configuration Avancée

### **Tuning Spark**

```properties
# spark-defaults.conf
spark.executor.memory=2g
spark.driver.memory=1g
spark.sql.adaptive.enabled=true
spark.sql.adaptive.coalescePartitions.enabled=true
```

### **Tuning Iceberg**

```sql
-- Compaction
ALTER TABLE nessie.demo_db.users 
SET TBLPROPERTIES (
  'write.parquet.compression-codec'='snappy',
  'write.metadata.compression-codec'='gzip'
);

-- Expiration snapshots
CALL nessie.system.expire_snapshots(
  table => 'demo_db.users',
  older_than => TIMESTAMP '2025-12-01 00:00:00',
  retain_last => 5
);
```

---

## 📚 Références

- [Apache Iceberg Documentation](https://iceberg.apache.org/)
- [Project Nessie Documentation](https://projectnessie.org/)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)
- [Apache Livy Documentation](https://livy.incubator.apache.org/)
- [MinIO Documentation](https://min.io/docs/)
- [Dremio Documentation](https://docs.dremio.com/)
- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [Apache Superset Documentation](https://superset.apache.org/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

---

## 🐛 Troubleshooting

### **Problème : Connexion Nessie échoue**

```bash
# Vérifier Nessie
curl http://localhost:19120/api/v2/config

# Vérifier PostgreSQL
docker compose exec postgres psql -U lakehouse -d lakehouse -c "\dt"
```

### **Problème : Dremio ne voit pas les tables Nessie**

```
Configuration source Nessie dans Dremio :
- Nessie Endpoint: http://nessie:19120/api/v2
- AWS Root Path: /warehouse-dev
- S3 Endpoint: minio:9000 (SANS http://)
- fs.s3a.path.style.access = true
```

### **Problème : Superset 500 Error**

```bash
# Vérifier les logs
docker compose logs superset

# Le driver Dremio nécessite l'image custom
docker compose build superset
docker compose up -d superset
```

### **Problème : Grafana "No data"**

```bash
# Vérifier Prometheus targets
curl http://localhost:9090/api/v1/targets

# Vérifier la datasource Grafana
# La datasource doit avoir uid: prometheus
```

### **Problème : MinIO inaccessible**

```bash
# Vérifier buckets
docker compose exec minio mc alias set local http://localhost:9000 admin <password>
docker compose exec minio mc ls local/
```

### **Problème : Out of Memory Spark**

```yaml
# docker-compose.yml - Augmenter ressources worker
spark-worker:
  environment:
    SPARK_WORKER_MEMORY: 4g  # Augmenter selon environnement
```

---

**Dernière mise à jour** : 22 décembre 2025  
**Version Stack** : Spark 3.5.4 | Iceberg 1.7.0 | Nessie latest | Dremio OSS | Airflow 2.10.4 | Superset latest
