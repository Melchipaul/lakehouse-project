# Configuration Zeppelin pour le Lakehouse

## Configuration initiale (à faire UNE SEULE FOIS)

### 1. Accéder à Zeppelin

Ouvrir : http://localhost:8081

### 2. Configurer l'interpréteur Spark

1. Cliquer sur votre nom (en haut à droite) → **"Interpreter"**
2. Chercher **"spark"** → Cliquer sur **"edit"** (icône crayon)

### 3. Modifier les propriétés

#### Propriété à modifier :
- **`spark.master`** : `spark://spark-master:7077`

#### Propriétés à ajouter (cliquer sur "+" pour chaque) :

**Packages Maven :**
```
spark.jars.packages = org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.6.1,org.projectnessie.nessie-integrations:nessie-spark-extensions-3.5_2.12:0.106.0,org.apache.hadoop:hadoop-aws:3.3.4
```

**Extensions SQL :**
```
spark.sql.extensions = org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,org.projectnessie.spark.extensions.NessieSparkSessionExtensions
```

**Catalogue Nessie :**
```
spark.sql.catalog.nessie = org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.nessie.uri = http://nessie:19120/api/v2
spark.sql.catalog.nessie.ref = main
spark.sql.catalog.nessie.warehouse = s3a://warehouse-dev/
spark.sql.catalog.nessie.catalog-impl = org.apache.iceberg.nessie.NessieCatalog
spark.sql.catalog.nessie.io-impl = org.apache.iceberg.aws.s3.S3FileIO
```

**Configuration S3 (MinIO) :**
```
spark.hadoop.fs.s3a.endpoint = http://minio:9000
spark.hadoop.fs.s3a.access.key = admin
spark.hadoop.fs.s3a.secret.key = mwVSgmj0BefSS9Ot
spark.hadoop.fs.s3a.path.style.access = true
spark.hadoop.fs.s3a.impl = org.apache.hadoop.fs.s3a.S3AFileSystem
spark.hadoop.fs.s3a.connection.ssl.enabled = false
```

### 4. Sauvegarder

Cliquer sur **"Save"** → **"OK"**

### 5. Vérification

Créer un notebook et tester :
```python
%pyspark

print(f"✅ Spark version: {spark.version}")
print(f"✅ Master: {spark.sparkContext.master}")
print(f"✅ App ID: {spark.sparkContext.applicationId}")
```

**Résultat attendu :**
- Master: `spark://spark-master:7077` ✅
- App ID: `app-...` (pas `local-...`) ✅

## Note sur les secrets

⚠️ La configuration contient des secrets (mots de passe MinIO). 

- Le volume `zeppelin-conf` est exclu du Git via `.gitignore`
- Pour la production, utiliser un secret manager (Vault, AWS Secrets Manager, etc.)
- Les secrets actuels sont pour l'environnement de développement local uniquement
