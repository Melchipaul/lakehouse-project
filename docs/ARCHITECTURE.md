# Architecture Lakehouse - Documentation Technique

## 🏗️ Vue d'Ensemble

Stack moderne de Data Lakehouse combinant Apache Iceberg, Nessie, Spark, et MinIO pour un data lake transactionnel avec versioning Git-like.

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACES                          │
├─────────────────────────────────────────────────────────────────┤
│  Zeppelin Notebooks      │  MinIO Console  │  Spark UI          │
│  http://localhost:8081   │  :19001         │  :8080             │
└─────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                     COMPUTE & EXECUTION                         │
├─────────────────────────────────────────────────────────────────┤
│                        Apache Livy                              │
│                    REST API for Spark                           │
│                    http://localhost:8998                        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐       │
│  │         Apache Spark 3.5.4 (Standalone)             │       │
│  │  ┌──────────────┐  ┌──────────────┐                │       │
│  │  │ Spark Master │  │ Spark Worker │                │       │
│  │  │   :7077      │  │   :8081      │                │       │
│  │  └──────────────┘  └──────────────┘                │       │
│  └─────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
┌───────────────────────────────┐  ┌──────────────────────────────┐
│      CATALOG & METADATA       │  │    STORAGE LAYER             │
├───────────────────────────────┤  ├──────────────────────────────┤
│     Project Nessie 0.106+     │  │    MinIO (S3-compatible)     │
│   Git-like Data Catalog       │  │                              │
│   http://localhost:19120      │  │  API:     :19000             │
│                               │  │  Console: :19001             │
│  ┌─────────────────────────┐  │  │                              │
│  │   Apache Iceberg 1.7.0  │  │  │  Buckets:                    │
│  │   Table Format          │  │  │  - lakehouse-dev/            │
│  └─────────────────────────┘  │  │  - warehouse-dev/            │
│                               │  │                              │
│  Backend: PostgreSQL 17       │  │  Warehouse location:         │
│            :5432              │  │  s3a://warehouse-dev/        │
└───────────────────────────────┘  └──────────────────────────────┘
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

### **URLs de Monitoring**

| Service | URL | Métriques |
|---------|-----|-----------|
| Spark Master UI | http://localhost:8080 | Jobs, stages, executors |
| Spark Worker UI | http://localhost:8081 | Memory, cores, tasks |
| MinIO Console | http://localhost:19001 | Buckets, objects, bandwidth |
| Livy UI | http://localhost:8998/ui | Sessions actives |
| Nessie API | http://localhost:19120/api/v2 | Branches, commits |

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
- 8 GB RAM minimum
- 20 GB espace disque

### **Installation**

```bash
# 1. Cloner le repo
git clone https://github.com/Melchipaul/lakehouse-project.git
cd lakehouse-project/docker/dev

# 2. Créer .env
cp .env.example .env
nano .env  # Remplir MINIO_ROOT_PASSWORD et POSTGRES_PASSWORD

# 3. Démarrer la stack
docker compose up -d

# 4. Vérifier les services
docker compose ps

# 5. Initialiser les données
./../../scripts/init-lakehouse.sh

# 6. Configurer Zeppelin
./../../scripts/configure-zeppelin-livy.sh
```

### **Vérification Santé**

```bash
# All services healthy
docker compose ps | grep healthy

# Tester Spark
curl http://localhost:8080

# Tester Livy
curl http://localhost:8998/version

# Tester Nessie
curl http://localhost:19120/api/v2/trees

# Tester MinIO
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

---

## 🐛 Troubleshooting

### **Problème : Connexion Nessie échoue**

```bash
# Vérifier Nessie
curl http://localhost:19120/api/v2/config

# Vérifier PostgreSQL
docker compose exec postgres psql -U lakehouse -d lakehouse -c "\dt"
```

### **Problème : MinIO inaccessible**

```bash
# Vérifier buckets
docker compose exec minio mc alias set local http://localhost:9000 admin <password>
docker compose exec minio mc ls local/
```

### **Problème : Out of Memory Spark**

```yaml
# docker-compose.yml
spark-worker:
  environment:
    SPARK_WORKER_MEMORY: 4g  # Augmenter
```

---

**Dernière mise à jour** : 22 décembre 2025  
**Version Stack** : Spark 3.5.4 | Iceberg 1.7.0 | Nessie 0.106+
