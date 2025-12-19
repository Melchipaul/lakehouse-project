# ��� Lakehouse Open-Source

Lakehouse moderne basé sur Apache Iceberg, Nessie, MinIO et Spark.

## ��� Architecture
```
┌─────────────────────────────────────────────────────┐
│                   Apache Zeppelin                    │
│              (Notebooks multi-langage)               │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│              Apache Spark 3.5.3                      │
│         (Spark Master + Workers)                     │
└──────────┬─────────────────────┬────────────────────┘
           │                     │
     ┌─────▼─────┐        ┌─────▼─────┐
     │  Nessie   │        │   MinIO   │
     │ (Catalog) │        │ (Storage) │
     └─────┬─────┘        └───────────┘
           │
     ┌─────▼─────┐
     │PostgreSQL │
     │ (Metadata)│
     └───────────┘
```

## ��� Stack Technique

| Composant | Version | Rôle |
|-----------|---------|------|
| **Apache Spark** | 3.5.3 | Moteur de calcul distribué |
| **Apache Iceberg** | 1.6.1 | Format de table lakehouse |
| **Project Nessie** | 0.106.0 | Catalogue de données versionné (Git pour data) |
| **MinIO** | latest | Stockage objet S3-compatible |
| **PostgreSQL** | 17 | Base de données pour métadonnées |
| **Apache Zeppelin** | 0.12.0 | Notebooks multi-langage (Python, Scala, SQL) |

## ��� Structure du Projet
```
lakehouse-project/
├── docker/
│   └── dev/
│       ├── docker-compose.yml    # Orchestration services
│       └── .env                  # Variables d'environnement
├── config/
│   ├── postgres/
│   │   └── init.sql             # Initialisation bases de données
│   ├── spark/
│   │   └── spark-defaults.conf  # Configuration Spark
│   └── zeppelin/                # Configuration Zeppelin (à venir)
└── README.md
```

## ��� Prérequis

- Docker & Docker Compose
- Git
- 8 GB RAM minimum
- Ports disponibles : 5432, 7077, 8080-8081, 19000-19001, 19120

## ��� Démarrage Rapide

### 1. Cloner le projet
```bash
git clone https://github.com/VOTRE-USERNAME/lakehouse-project.git
cd lakehouse-project
```

### 2. Configurer les variables d'environnement
```bash
cd docker/dev
cp .env.example .env
# Éditer .env si nécessaire
```

### 3. Démarrer l'infrastructure
```bash
docker-compose up -d
```

### 4. Vérifier le statut
```bash
docker-compose ps
```

Tous les services doivent être **Up** (sauf minio-init qui doit être **Exited (0)**).

## ��� Accès aux Interfaces

| Service | URL | Identifiants |
|---------|-----|--------------|
| **Zeppelin** | http://localhost:8081 | anonymous (pas de mot de passe) |
| **Spark Master UI** | http://localhost:8080 | - |
| **MinIO Console** | http://localhost:19001 | admin / `<voir .env>` |
| **Nessie API** | http://localhost:19120/api/v2 | - |
| **PostgreSQL** | localhost:5432 | lakehouse / `<voir .env>` |

## ��� Configuration Zeppelin (Première utilisation)

### 1. Accéder à Zeppelin
Ouvrir http://localhost:8081

### 2. Configurer l'interpréteur Spark
1. Cliquer sur **anonymous** (en haut à droite) → **Interpreter**
2. Chercher **"spark"** et cliquer sur **"edit"**
3. Modifier :
   - `master` : `spark://spark-master:7077`
   - Ajouter les propriétés suivantes (cliquer sur le bouton **"+"**) :
```properties
spark.jars.packages=org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.6.1,org.projectnessie.nessie-integrations:nessie-spark-extensions-3.5_2.12:0.106.0,org.apache.hadoop:hadoop-aws:3.3.4

spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,org.projectnessie.spark.extensions.NessieSparkSessionExtensions

spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.nessie.uri=http://nessie:19120/api/v2
spark.sql.catalog.nessie.ref=main
spark.sql.catalog.nessie.warehouse=s3a://warehouse-dev/
spark.sql.catalog.nessie.catalog-impl=org.apache.iceberg.nessie.NessieCatalog
spark.sql.catalog.nessie.io-impl=org.apache.iceberg.aws.s3.S3FileIO

spark.hadoop.fs.s3a.endpoint=http://minio:9000
spark.hadoop.fs.s3a.access.key=admin
spark.hadoop.fs.s3a.secret.key=<VOIR_VOTRE_.ENV>
spark.hadoop.fs.s3a.path.style.access=true
spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem
spark.hadoop.fs.s3a.connection.ssl.enabled=false
```

4. Cliquer sur **"Save"** → **"OK"**

## ��� Test de Base

Créer un notebook Zeppelin et exécuter :
```python
%pyspark

# Tester la connexion Spark
print(f"✅ Spark version: {spark.version}")
print(f"✅ Master: {spark.sparkContext.master}")

# Créer une base de données
spark.sql("CREATE DATABASE IF NOT EXISTS nessie.demo")

# Créer une table Iceberg
spark.sql("""
CREATE TABLE nessie.demo.test (
    id INT,
    name STRING,
    timestamp TIMESTAMP
)
USING iceberg
""")

# Insérer des données
spark.sql("""
INSERT INTO nessie.demo.test VALUES 
(1, 'Alice', current_timestamp()),
(2, 'Bob', current_timestamp())
""")

# Lire les données
spark.sql("SELECT * FROM nessie.demo.test").show()
```

## ���️ Commandes Utiles
```bash
# Voir les logs d'un service
docker-compose logs -f zeppelin

# Redémarrer un service
docker-compose restart zeppelin

# Arrêter l'infrastructure
docker-compose down

# Arrêter et supprimer les volumes (⚠️ perte de données)
docker-compose down -v

# Reconstruire les images
docker-compose up -d --build
```

## ��� Problèmes Connus

### Zeppelin : "Interpreter pyspark not found"
**Solution** : Configurer l'interpréteur Spark via l'interface (voir section Configuration).

### Permission Denied sur Windows
**Solution** : Ce projet fonctionne mieux sur Linux/macOS. Sur Windows, utiliser WSL2.

### Spark Worker ne se connecte pas au Master
**Solution** : Vérifier que les services sont dans le même réseau Docker :
```bash
docker network ls
docker network inspect dev_lakehouse
```

## ��� Ressources

- [Apache Iceberg](https://iceberg.apache.org/)
- [Project Nessie](https://projectnessie.org/)
- [Apache Spark](https://spark.apache.org/)
- [Apache Zeppelin](https://zeppelin.apache.org/)
- [MinIO](https://min.io/)

## ��� Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.

## ��� Licence

MIT

## ✨ État du Projet

**Version actuelle** : 0.1.0 (Développement)

**Testé sur** :
- ✅ Fedora (recommandé)
- ⚠️ Windows (problèmes de permissions Docker)
- ��� macOS (non testé)

**Prochaines étapes** :
- [ ] Configuration automatique Zeppelin
- [ ] Ajout d'Apache Airflow pour l'orchestration
- [ ] Ajout de Dremio pour le query engine
- [ ] Scripts d'exemple et tutoriels
- [ ] Tests end-to-end
