# 🏗️ Projet Lakehouse - Stack Data Moderne Complète

Architecture Data Lakehouse moderne de fin 2025 avec Apache Iceberg, Nessie, Spark, et une suite complète d'outils Data.

> 🎯 **Stack complète : Ingestion → Traitement → Requêtage → Visualisation → Monitoring**  
> Configuration Infrastructure as Code 100% reproductible avec CI/CD intégré.

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Docker Network: {env}-lakehouse                        │
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

## 📦 Stack Technologique (14 Services)

| Composant | Version | Rôle | Port DEV |
|-----------|---------|------|----------|
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

## 🚀 Démarrage Rapide

### Prérequis

- Docker 24.0+ avec BuildKit
- Docker Compose 2.0+
- **16 GB RAM** minimum
- 30 GB d'espace disque libre

### Installation en 3 étapes

```bash
# 1. Configurer les credentials
cp envs/.env.example envs/.env.dev
nano envs/.env.dev  # Modifier les valeurs

# 2. Build des images custom (première fois uniquement)
docker compose --env-file envs/.env.dev build

# 3. Lancer la stack
docker compose --env-file envs/.env.dev up -d
```

### ✅ Vérification

```bash
# Tous les services doivent être "healthy"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep dev
```

## 🌐 Accès aux Interfaces (DEV)

| Service | URL | Credentials |
|---------|-----|-------------|
| **Zeppelin** | http://localhost:8081 | - |
| **Dremio** | http://localhost:9047 | Créé au 1er lancement |
| **Airflow** | http://localhost:8082 | Voir `envs/.env.dev` |
| **Grafana** | http://localhost:3001 | Voir `envs/.env.dev` |
| **Superset** | http://localhost:8088 | Voir `envs/.env.dev` |
| **MinIO Console** | http://localhost:19001 | Voir `envs/.env.dev` |
| **Prometheus** | http://localhost:9090 | - |
| **Spark Master** | http://localhost:8080 | - |
| **Nessie** | http://localhost:19120 | - |
| **Livy** | http://localhost:8998 | - |

## 🌍 Multi-Environnements & CI/CD

### Architecture Unifiée

Un seul `docker-compose.yml` paramétré pour tous les environnements :

```bash
# DEV
docker compose --env-file envs/.env.dev up -d

# PREPROD  
docker compose --env-file envs/.env.preprod up -d

# PROD
docker compose --env-file envs/.env.prod up -d
```

### Ports par Environnement

| Service | DEV | PREPROD | PROD |
|---------|-----|---------|------|
| PostgreSQL | 5432 | 6432 | 7432 |
| MinIO Console | 19001 | 20001 | 21001 |
| Nessie | 19120 | 20120 | 21120 |
| Zeppelin | 8081 | 9081 | 10081 |
| Dremio | 9047 | 10047 | 11047 |
| Airflow | 8082 | 9082 | 10082 |
| Prometheus | 9090 | 10090 | 11090 |
| Grafana | 3001 | 4001 | 5001 |
| Superset | 8088 | 9088 | 10088 |

### Workflow Git CI/CD

```
┌─────────────┐      merge PR      ┌──────────────┐      merge PR      ┌─────────────┐
│ branche dev │  ───────────────►  │branche preprod│  ───────────────►  │ branche prod │
│   (code)    │                    │ (auto-deploy) │                    │ (auto-deploy)│
└─────────────┘                    └──────────────┘                    └─────────────┘
       │                                  │                                   │
       ▼                                  ▼                                   ▼
   🚀 Deploy                         🚀 Deploy                           🚀 Deploy
   envs/.env.dev                     envs/.env.preprod                   envs/.env.prod
```

**GitHub Actions** déclenche automatiquement le déploiement via self-hosted runner quand on push/merge sur une branche.

### Configuration du Self-Hosted Runner

Le runner doit tourner sur la machine de déploiement :

```bash
# Télécharger le runner
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -o actions-runner-linux-x64-2.321.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-linux-x64-2.321.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.321.0.tar.gz

# Configurer (récupérer le token sur GitHub > Settings > Actions > Runners > New)
./config.sh --url https://github.com/Melchipaul/lakehouse-project --token YOUR_TOKEN

# Lancer
./run.sh
```

## 📁 Structure du Projet

```
lakehouse-project/
├── docker-compose.yml          # 🎯 Unique, paramétré par .env
├── envs/
│   ├── .env.example            # Template (versionné)
│   ├── .env.dev                # Config DEV (gitignored)
│   ├── .env.preprod            # Config PREPROD (gitignored)
│   └── .env.prod               # Config PROD (gitignored)
├── docker/
│   ├── livy-custom/            # Dockerfile Livy
│   ├── superset-custom/        # Dockerfile Superset
│   └── zeppelin-custom/        # Dockerfile Zeppelin
├── config/
│   ├── postgres/init.sql
│   ├── prometheus/prometheus.yml
│   ├── grafana/provisioning/
│   └── superset/superset_config.py
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD GitHub Actions
└── docs/
    ├── BUILD_AND_DEPLOYMENT.md
    ├── ARCHITECTURE_DECISIONS.md
    └── zeppelin-configuration.md
```

## 💡 Exemples d'Utilisation

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
        amount DECIMAL(10,2)
    ) USING iceberg
    LOCATION 's3a://warehouse-dev/demo/sales'
""")

# Insérer et lire
spark.sql("INSERT INTO nessie.demo.sales VALUES (1, 'Laptop', 999.99)")
spark.sql("SELECT * FROM nessie.demo.sales").show()
```

### Versioning Git-like avec Nessie

```python
# Créer une branche
spark.sql("CREATE BRANCH IF NOT EXISTS feature IN nessie")

# Travailler sur la branche
spark.sql("USE REFERENCE feature IN nessie")
spark.sql("INSERT INTO nessie.demo.sales VALUES (2, 'Mouse', 29.99)")

# Revenir sur main - modifications isolées
spark.sql("USE REFERENCE main IN nessie")
spark.sql("SELECT * FROM nessie.demo.sales").show()  # Pas de Mouse !
```

## 🛠️ Commandes Utiles

```bash
# Démarrer
docker compose --env-file envs/.env.dev up -d

# Arrêter
docker compose --env-file envs/.env.dev down

# Logs
docker compose --env-file envs/.env.dev logs -f [service]

# Rebuild une image
docker compose --env-file envs/.env.dev build --no-cache livy

# Status
docker compose --env-file envs/.env.dev ps
```

## 🔐 Sécurité

- ✅ Fichiers `.env` **gitignored** (jamais committés)
- ✅ Template `.env.example` documenté
- ✅ Volumes et networks isolés par environnement
- ✅ Restart policies configurables (`unless-stopped` en PROD)

## 📚 Documentation

- 📖 **[BUILD_AND_DEPLOYMENT.md](docs/BUILD_AND_DEPLOYMENT.md)** → Guide complet
- 🏗️ **[ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md)** → Choix techniques
- 📓 **[zeppelin-configuration.md](docs/zeppelin-configuration.md)** → Config Zeppelin

## 🐛 Troubleshooting

### Services qui ne démarrent pas

```bash
# Vérifier les logs
docker compose --env-file envs/.env.dev logs [service]

# Redémarrer un service
docker compose --env-file envs/.env.dev restart [service]
```

### Images custom non trouvées

```bash
# Rebuilder
docker compose --env-file envs/.env.dev build livy zeppelin superset
```

## 📝 Licence

MIT

---

**Stack complète prête à l'emploi !** 🚀

```bash
cp envs/.env.example envs/.env.dev
docker compose --env-file envs/.env.dev up -d
```

**14 services** | **3 environnements** | **CI/CD intégré** | **100% reproductible**
