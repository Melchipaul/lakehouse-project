# Lakehouse Project

Architecture Data Lakehouse moderne avec Iceberg, Nessie, Spark et MinIO.

## 🏗️ Architecture
```
┌─────────────┐
│  Zeppelin   │ ← Interface utilisateur (notebooks)
└──────┬──────┘
       │
┌──────▼──────┐
│    Spark    │ ← Moteur de traitement distribué
│   Cluster   │
└──────┬──────┘
       │
┌──────▼──────┐     ┌──────────┐
│   Nessie    │ ← → │  MinIO   │ ← Stockage objet (S3)
│  (Catalog)  │     │  (Data)  │
└──────┬──────┘     └──────────┘
       │
┌──────▼──────┐
│ PostgreSQL  │ ← Métadonnées Nessie
└─────────────┘
```

## 📦 Stack technologique

| Composant | Version | Rôle |
|-----------|---------|------|
| Apache Spark | 3.5.3 | Moteur de traitement distribué |
| Apache Iceberg | 1.6.1 | Format de table |
| Nessie | latest | Catalogue de données avec Git-like versioning |
| MinIO | latest | Stockage objet S3-compatible |
| PostgreSQL | 17 | Base de données pour métadonnées |
| Zeppelin | 0.12.0 | Interface notebook |

## 🚀 Démarrage rapide

### Prérequis

- Docker Desktop installé
- Docker Compose installé
- Ports disponibles : 5432, 8080, 8081, 7077, 9000, 9001, 19120

### Installation

1. **Cloner le projet**
```bash
git clone <votre-repo>
cd lakehouse-project
```

2. **Créer les variables d'environnement**
```bash
cp docker/dev/.env.example docker/dev/.env
# Modifier si nécessaire
```

3. **Démarrer la stack**
```bash
cd docker/dev
docker-compose up -d
```

4. **Vérifier le déploiement**
```bash
docker-compose ps
```

Tous les services doivent être "Up (healthy)".

### Configuration initiale

**Zeppelin - À configurer UNE SEULE FOIS :**

Suivre le guide : [docs/zeppelin-configuration.md](docs/zeppelin-configuration.md)

## 🌐 Accès aux interfaces

| Service | URL | Identifiants |
|---------|-----|--------------|
| Zeppelin | http://localhost:8081 | - |
| Spark Master UI | http://localhost:8080 | - |
| MinIO Console | http://localhost:9001 | admin / mwVSgmj0BefSS9Ot |
| Nessie API | http://localhost:19120 | - |

## 📚 Exemples d'utilisation

### Créer une table Iceberg
```python
%pyspark

# Créer une table
spark.sql("""
    CREATE TABLE nessie.sales (
        id BIGINT,
        product STRING,
        amount DECIMAL(10,2),
        sale_date DATE
    ) USING iceberg
""")

# Insérer des données
spark.sql("""
    INSERT INTO nessie.sales VALUES
    (1, 'Laptop', 999.99, CURRENT_DATE),
    (2, 'Mouse', 29.99, CURRENT_DATE)
""")

# Lire les données
spark.sql("SELECT * FROM nessie.sales").show()
```

### Versionning avec Nessie
```python
# Créer une branche
spark.sql("CREATE BRANCH IF NOT EXISTS dev IN nessie")

# Utiliser la branche
spark.sql("USE REFERENCE dev IN nessie")

# Faire des modifications...
# Merger dans main si besoin
```

## 📁 Structure du projet
```
lakehouse-project/
├── docker/
│   ├── dev/
│   │   ├── docker-compose.yml
│   │   └── .env
│   └── zeppelin-custom/
│       ├── Dockerfile
│       └── spark-defaults.conf
├── config/
│   └── postgres/
│       └── init.sql
├── docs/
│   └── zeppelin-configuration.md
├── .gitignore
└── README.md
```

## 🛠️ Build de l'image Zeppelin custom

Si vous modifiez la configuration :
```bash
cd docker/zeppelin-custom
docker build -t lakehouse-zeppelin:latest .

cd ../dev
docker-compose down
docker-compose up -d
```

## 🧹 Nettoyage
```bash
# Arrêter les services
docker-compose down

# Supprimer les volumes (ATTENTION : perte de données)
docker-compose down -v
```

## 🔒 Sécurité

⚠️ **Ce projet est conçu pour le développement local.**

Pour la production :
- Utiliser des secrets managers (Vault, AWS Secrets Manager)
- Configurer l'authentification sur tous les services
- Activer SSL/TLS
- Isoler les réseaux
- Configurer les politiques de rétention

## 📝 Licence

MIT

## 🤝 Contribution

Les contributions sont les bienvenues ! Créez une issue ou une pull request.
