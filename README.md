# 🏗️ Projet Lakehouse - Stack Data Moderne Complète

Architecture Data Lakehouse moderne de fin 2025 avec Apache Iceberg, Nessie, Spark, et une suite complète d'outils Data.

> 🎯 **Stack complète : Ingestion → Traitement → Requêtage → Visualisation → Monitoring**  
> Configuration Infrastructure as Code 100% reproductible avec credentials externalisés.

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Docker Network: dev_lakehouse                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐      │
│  │  PostgreSQL  │   │    MinIO     │   │    Nessie    │   │  Prometheus  │      │
│  │      17      │   │   (S3-like)  │   │  (Catalog)   │   │  (Metrics)   │      │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘      │
│         │                  │                  │                  │               │
│         └──────────────────┴─────────┬────────┴──────────────────┘               │
│                                      │                                            │
│  ┌───────────────────────────────────▼─────────────────────────────────────────┐ │
│  │                   Spark 3.5.4 Cluster (Standalone)                          │ │
│  │         ┌─────────────┐              ┌─────────────┐                        │ │
│  │         │   Master    │◄────────────►│   Worker    │                        │ │
│  │         └─────────────┘              └─────────────┘                        │ │
│  └───────────────────────────────────▲─────────────────────────────────────────┘ │
│                                      │                                            │
│  ┌───────────────────────────────────┴─────────────────────────────────────────┐ │
│  │                    Apache Livy (Custom Build - REST API)                    │ │
│  │           Compilé avec profil Spark 3.5 + Iceberg 1.7.0 + Nessie            │ │
│  └───────────────────────────────────▲─────────────────────────────────────────┘ │
│                                      │                                            │
│    ┌─────────────┐     ┌─────────────┴───────────┐     ┌─────────────┐          │
│    │   Zeppelin  │     │         Airflow         │     │   Dremio    │          │
│    │  (Notebook) │     │    (Orchestration)      │     │ (SQL Query) │          │
│    └─────────────┘     └─────────────────────────┘     └──────┬──────┘          │
│                                                               │                  │
│    ┌─────────────────────────────────────────────────────────┴───────────────┐  │
│    │                         Visualization Layer                              │  │
│    │         ┌─────────────┐                    ┌─────────────┐              │  │
│    │         │   Grafana   │                    │  Superset   │              │  │
│    │         │ (Monitoring)│                    │    (BI)     │              │  │
│    │         └─────────────┘                    └─────────────┘              │  │
│    └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## 📦 Stack Technologique (Décembre 2025)

| Composant | Version | Rôle | Port |
|-----------|---------|------|------|
| **Apache Spark** | 3.5.4 | Moteur de traitement distribué | 7077, 8080 |
| **Apache Livy** | custom | REST API pour Spark | 8998 |
| **Apache Iceberg** | 1.7.0 | Format de table lakehouse | - |
| **Nessie** | latest | Catalogue Git-like avec versioning | 19120 |
| **MinIO** | latest | Stockage objet S3-compatible | 19000, 19001 |
| **PostgreSQL** | 17 | Backend metadata | 5432 |
| **Zeppelin** | 0.12.0 | Interface notebook (dark mode) | 8081 |
| **Dremio OSS** | latest | SQL Query Engine | 9047, 31010, 32010 |
| **Airflow** | 2.10.4 | Orchestration de workflows | 8082 |
| **Prometheus** | latest | Collecte de métriques | 9090 |
| **Grafana** | latest | Dashboards monitoring | 3001 |
| **Superset** | latest | BI & Data Visualization | 8088 |

### Packages Maven intégrés

- `iceberg-spark-runtime-3.5_2.12:1.7.0`
- `nessie-spark-extensions-3.5_2.12:0.106.0`
- `hadoop-aws:3.3.4`
- `software.amazon.awssdk:bundle:2.20.18`

## 🚀 Démarrage Rapide

### Prérequis

- Docker 24.0+ avec BuildKit
- Docker Compose 2.0+
- **16 GB RAM** minimum (stack complète de 14 services)
- 30 GB d'espace disque libre

### Installation en 4 étapes

#### 1. Vérifier la structure du projet

```bash
# À la racine du projet
./scripts/verify-setup.sh
```

#### 2. Configurer les credentials

```bash
cd docker/dev
cp .env.example .env

# Éditer .env et remplacer TOUS les CHANGEME_SECURE_PASSWORD
nano .env  # ou vim, code, etc.
```

#### 3. Build des images custom

```bash
# Build Livy (15-25 min - nécessite compilation)
docker compose build livy

# Build Zeppelin
docker compose build zeppelin

# Build Superset (avec drivers Dremio)
docker compose build superset
```

#### 4. Lancer la stack

```bash
# Démarrer tous les services (14 containers)
docker compose up -d

# Suivre les logs
docker compose logs -f

# Vérifier l'état
docker compose ps
```

### ✅ Vérification du déploiement

```bash
# Tous les services doivent être "healthy" ou "Up"
docker compose ps

# Tests de connectivité
curl http://localhost:8998/version         # Livy
curl http://localhost:19120/api/v2/config  # Nessie
curl http://localhost:9047                 # Dremio
curl http://localhost:8082/health          # Airflow
curl http://localhost:8088/health          # Superset
curl http://localhost:9090/-/healthy       # Prometheus
curl http://localhost:3001/api/health      # Grafana
```

## 🌐 Accès aux Interfaces

| Service | URL | Credentials |
|---------|-----|-------------|
| **MinIO Console** | http://localhost:19001 | Voir `.env` (MINIO_ROOT_*) |
| **Spark Master UI** | http://localhost:8080 | - |
| **Nessie UI** | http://localhost:19120 | - |
| **Livy REST API** | http://localhost:8998 | - |
| **Zeppelin** | http://localhost:8081 | - |
| **Dremio** | http://localhost:9047 | Créé au 1er lancement |
| **Airflow** | http://localhost:8082 | Voir `.env` (AIRFLOW_*) |
| **Prometheus** | http://localhost:9090 | - |
| **Grafana** | http://localhost:3001 | Voir `.env` (GRAFANA_*) |
| **Superset** | http://localhost:8088 | Voir `.env` (SUPERSET_*) |

## 📚 Documentation complète

- 📖 **[BUILD_AND_DEPLOYMENT.md](docs/BUILD_AND_DEPLOYMENT.md)** → Guide complet de build et troubleshooting
- 🏗️ **[ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md)** → Réponses techniques et choix d'architecture
- 📓 **[zeppelin-configuration.md](docs/zeppelin-configuration.md)** → Configuration Zeppelin → Livy

## 💡 Exemples d'utilisation

### Via API Livy (REST)

```bash
# Créer une session Spark
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind": "pyspark"}'

# Exécuter du code Spark (session 0)
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{"code": "spark.range(0, 100).count()"}'
```

### Via Zeppelin Notebook

```python
%pyspark

# Créer un namespace Iceberg
spark.sql("CREATE NAMESPACE IF NOT EXISTS nessie.demo")

# Créer une table
spark.sql("""
    CREATE TABLE nessie.demo.sales (
        id BIGINT,
        product STRING,
        amount DECIMAL(10,2),
        sale_date DATE
    ) USING iceberg
    LOCATION 's3a://warehouse-dev/demo/sales'
""")

# Insérer des données
spark.sql("""
    INSERT INTO nessie.demo.sales VALUES
    (1, 'Laptop', 999.99, CURRENT_DATE),
    (2, 'Mouse', 29.99, CURRENT_DATE),
    (3, 'Keyboard', 79.99, CURRENT_DATE)
""")

# Lire les données
spark.sql("SELECT * FROM nessie.demo.sales").show()
```

### Versionning Git-like avec Nessie

```python
# Créer une branche de développement
spark.sql("CREATE BRANCH IF NOT EXISTS dev IN nessie")

# Basculer sur la branche dev
spark.sql("USE REFERENCE dev IN nessie")

# Faire des modifications (elles sont isolées dans 'dev')
spark.sql("INSERT INTO nessie.demo.sales VALUES (4, 'Monitor', 299.99, CURRENT_DATE)")

# Revenir sur main pour vérifier l'isolation
spark.sql("USE REFERENCE main IN nessie")
spark.sql("SELECT COUNT(*) FROM nessie.demo.sales").show()  # 3 lignes

# Merger dev → main si tests OK
# (via Nessie API ou CLI)
```

## 🌍 Multi-Environnements

Le projet supporte 3 environnements avec **isolation totale** (ports différents, volumes séparés) :

| Env | Dossier | Ports | Buckets | Ressources |
|-----|---------|-------|---------|------------|
| **DEV** | `docker/dev/` | Base | warehouse-dev | 2 cores, 2g |
| **PREPROD** | `docker/preprod/` | +1000 | warehouse-preprod | 4 cores, 4g |
| **PROD** | `docker/prod/` | +2000 | warehouse-prod | 8 cores, 8g |

### Démarrer un environnement

```bash
# DEV (défaut)
cd docker/dev && docker compose up -d

# PREPROD (ports décalés +1000)
cd docker/preprod && docker compose up -d

# PROD (ports décalés +2000)
cd docker/prod && docker compose up -d
```

### Ports par environnement

| Service | DEV | PREPROD | PROD |
|---------|-----|---------|------|
| MinIO Console | 19001 | 20001 | 21001 |
| Spark Master | 8080 | 9080 | 10080 |
| Nessie | 19120 | 20120 | 21120 |
| Livy | 8998 | 9998 | 10998 |
| Zeppelin | 8081 | 9081 | 10081 |
| Dremio | 9047 | 10047 | 11047 |
| Airflow | 8082 | 9082 | 10082 |
| Prometheus | 9090 | 10090 | 11090 |
| Grafana | 3001 | 4001 | 5001 |
| Superset | 8088 | 9088 | 10088 |

### Différences PROD

- ✅ `restart: unless-stopped` sur tous les services
- ✅ Rétention Prometheus : 30 jours
- ✅ Accès anonyme Grafana désactivé
- ✅ Config Airflow non exposée
- ✅ Plus de ressources Spark (8 cores, 8g)

## 📁 Structure du projet

```
lakehouse-project/
├── docker/
│   ├── dev/                    # 🟢 Développement
│   │   ├── docker-compose.yml
│   │   ├── .env
│   │   └── .env.example
│   ├── preprod/                # 🟡 Pré-production
│   │   ├── docker-compose.yml
│   │   ├── .env
│   │   └── .env.example
│   ├── prod/                   # 🔴 Production
│   │   ├── docker-compose.yml
│   │   ├── .env
│   │   └── .env.example
│   ├── livy-custom/
│   │   ├── Dockerfile
│   │   ├── livy.conf
│   │   ├── spark-defaults.conf.template
│   │   └── entrypoint.sh
│   ├── zeppelin-custom/
│   │   ├── Dockerfile
│   │   └── interpreter.json
│   └── superset-custom/
│       └── Dockerfile
├── config/
│   ├── postgres/init.sql       # Init bases de données
│   ├── prometheus/prometheus.yml
│   ├── grafana/provisioning/   # Datasources & dashboards
│   └── superset/superset_config.py
├── docs/
│   ├── BUILD_AND_DEPLOYMENT.md
│   ├── ARCHITECTURE_DECISIONS.md
│   └── zeppelin-configuration.md
├── scripts/
│   ├── verify-setup.sh         # Vérification structure
│   └── setup-local-env.sh
├── .gitignore                  # ⚠️ .env est gitignored
└── README.md
```

## 🔐 Sécurité et credentials

### ✅ Bonne pratique implémentée

- ✅ Fichier `.env` **gitignored** (jamais committé)
- ✅ Template `.env.example` documenté
- ✅ Injection dynamique via entrypoint (Livy)
- ✅ Variables d'environnement Docker Compose

### ⚠️ Important

**Ce projet est configuré pour le développement local.**

Pour la production:
- Utiliser des secrets managers (Vault, AWS Secrets Manager, etc.)
- Activer l'authentification sur tous les services
- Configurer SSL/TLS
- Isoler les réseaux (VPC, subnets)
- Implémenter des politiques de backup
- Monitoring et alerting (Prometheus, Grafana)

## 🛠️ Commandes utiles

### Rebuild après modifications

```bash
# Rebuild Livy
docker compose build --no-cache livy
docker compose up -d livy

# Rebuild Zeppelin
docker compose build --no-cache zeppelin
docker compose up -d zeppelin
```

### Logs et debugging

```bash
# Logs de tous les services
docker compose logs -f

# Logs d'un service spécifique
docker compose logs -f livy

# Vérifier les variables d'environnement
docker exec dev-livy env | grep -E "SPARK|MINIO|LIVY"
```

### Nettoyage

```bash
# Arrêter les services
docker compose down

# Arrêter + supprimer les volumes (⚠️ perte de données)
docker compose down -v

# Nettoyer les images inutilisées
docker image prune -f
```

## 🐛 Troubleshooting

### Problème: Build Livy échoue

```bash
# Augmenter RAM Docker (minimum 6 GB)
# Docker Desktop > Settings > Resources

# Retry avec logs verbeux
docker build --progress=plain -t lakehouse-livy:latest docker/livy-custom/
```

### Problème: "All masters are unresponsive"

```bash
# Vérifier que Spark Master est démarré
docker compose ps spark-master

# Redémarrer dans l'ordre
docker compose restart spark-master
docker compose restart spark-worker
docker compose restart livy
```

### Problème: Credentials MinIO non injectés

```bash
# Vérifier .env
cat docker/dev/.env | grep MINIO

# Vérifier l'injection
docker exec dev-livy cat /opt/livy/conf/spark-defaults.conf | grep s3a.access.key

# Relancer si nécessaire
docker compose down
docker compose up -d
```

**Plus de détails** → [BUILD_AND_DEPLOYMENT.md](docs/BUILD_AND_DEPLOYMENT.md)

## 🎯 Fonctionnalités clés

- ✅ **Lakehouse moderne**: Iceberg 1.7.0 + Nessie (Git-like versioning)
- ✅ **REST API Spark**: Livy custom avec Spark 3.5.4
- ✅ **SQL Engine**: Dremio OSS pour requêtes interactives
- ✅ **Orchestration**: Airflow 2.10.4 pour pipelines data
- ✅ **Monitoring**: Prometheus + Grafana avec dashboards préconfigurés
- ✅ **BI**: Superset connecté à Dremio (via Flight)
- ✅ **Notebooks**: Zeppelin avec dark mode
- ✅ **Credentials sécurisés**: 100% externalisés, jamais committés
- ✅ **Infrastructure as Code**: Reproductible sur n'importe quelle machine
- ✅ **Multi-stage build**: Images Docker optimisées
- ✅ **Healthchecks**: Détection automatique des problèmes

## 📊 Monitoring & Métriques

### Dashboard Grafana

Le projet inclut un dashboard préconfigé avec :
- État des services (Prometheus, PostgreSQL, MinIO)
- Métriques PostgreSQL (connexions, requêtes)
- Métriques MinIO (stockage)

**Accès**: http://localhost:3001 → Dashboard "Lakehouse Overview"

### Prometheus Targets

| Target | Endpoint | Métriques |
|--------|----------|-----------|
| Prometheus | localhost:9090 | Self-monitoring |
| PostgreSQL | postgres-exporter:9187 | Connexions, requêtes |
| MinIO | minio:9000/minio/v2/metrics/cluster | Stockage, buckets |

## 🔗 Intégrations

### Dremio → Nessie → MinIO

Dremio est configuré pour accéder aux tables Iceberg via Nessie :

```
Source Nessie dans Dremio:
- Endpoint: http://nessie:19120/api/v2
- AWS Root Path: /warehouse-dev
- S3 Endpoint: minio:9000 (sans http://)
- Path Style Access: true
```

### Superset → Dremio

Superset se connecte à Dremio pour visualiser les données :

```
SQLAlchemy URI:
dremio+flight://user:password@dremio:32010/dremio?UseEncryption=false
```

## 🚧 Roadmap

- [ ] CI/CD avec GitHub Actions
- [ ] Tests d'intégration automatisés
- [ ] Support Kubernetes (Helm charts)
- [x] ~~Environnements preprod/prod~~
- [x] ~~Monitoring avec Prometheus + Grafana~~
- [ ] Support Spark 4.x quand mature

## 📝 Licence

MIT

## 🤝 Contribution

Les contributions sont les bienvenues ! Ouvrez une issue ou créez une pull request.

---

**Stack complète prête à l'emploi !** 🚀

```bash
cd docker/dev
cp .env.example .env
# Éditer .env avec vos credentials
docker compose build
docker compose up -d
```

**14 services** | **Lakehouse moderne** | **100% reproductible**
