# 🚀 Quick Start Guide - Lakehouse Project

## ⚡ Démarrage en 5 minutes

### Étape 1: Vérification 🔍

```bash
cd lakehouse-project
./scripts/verify-setup.sh
```

**✅ Attendu**: Tout vert, 0 erreurs

---

### Étape 2: Configuration 🔐

```bash
cd docker/dev
cp .env.example .env

# Éditer les credentials (OBLIGATOIRE)
nano .env  # ou code .env
```

**⚠️ À modifier**:
- `POSTGRES_PASSWORD=CHANGEME_SECURE_PASSWORD` → Votre password
- `MINIO_ROOT_PASSWORD=CHANGEME_SECURE_PASSWORD` → Votre password

---

### Étape 3: Build 🏗️

```bash
# Build Livy (⏱️ 15-25 min - 1 seule fois)
docker compose build livy

# Build Zeppelin (⏱️ 2-3 min - si nécessaire)
docker compose build zeppelin
```

**☕ Prenez un café pendant le build de Livy**

---

### Étape 4: Lancement 🚀

```bash
docker compose up -d
```

**Attendre 2-3 minutes** pour que tous les services soient healthy.

---

### Étape 5: Vérification ✅

```bash
# Vérifier l'état des services
docker compose ps

# Tester Livy
curl http://localhost:8998/version

# Tester Nessie
curl http://localhost:19120/api/v2/config

# Tester MinIO
curl http://localhost:19000/minio/health/live
```

**Tous les tests doivent réussir !**

---

## 🌐 Interfaces disponibles

Ouvrir dans votre navigateur:

| Interface | URL | Usage |
|-----------|-----|-------|
| 📓 Zeppelin | http://localhost:8081 | Notebooks interactifs |
| ⚡ Spark UI | http://localhost:8080 | Monitoring Spark Cluster |
| 🗄️ MinIO | http://localhost:19001 | Console S3 (credentials: voir `.env`) |
| 🔥 Livy API | http://localhost:8998 | REST API Spark |
| 📦 Nessie API | http://localhost:19120/api/v2 | Catalog API |

---

## 💻 Premier test avec Livy

### Créer une session Spark

```bash
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind": "pyspark"}'
```

**Réponse attendue**: `{"id":0,"state":"starting",...}`

### Exécuter du code

```bash
# Attendre que la session soit "idle" (30-60 sec)
curl http://localhost:8998/sessions/0

# Exécuter du code Python Spark
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{"code": "spark.range(0, 100).count()"}'

# Récupérer le résultat
curl http://localhost:8998/sessions/0/statements/0
```

---

## 📊 Premier test Iceberg + Nessie (via Zeppelin)

1. Ouvrir http://localhost:8081
2. Créer un nouveau notebook
3. Exécuter:

```python
%pyspark

# Créer un namespace
spark.sql("CREATE NAMESPACE IF NOT EXISTS nessie.demo")

# Créer une table Iceberg
spark.sql("""
    CREATE TABLE nessie.demo.test (
        id BIGINT,
        name STRING,
        timestamp TIMESTAMP
    ) USING iceberg
""")

# Insérer des données
spark.sql("""
    INSERT INTO nessie.demo.test VALUES
    (1, 'Alice', CURRENT_TIMESTAMP),
    (2, 'Bob', CURRENT_TIMESTAMP)
""")

# Lire
spark.sql("SELECT * FROM nessie.demo.test").show()
```

**Résultat attendu**:
```
+---+-----+--------------------+
| id| name|           timestamp|
+---+-----+--------------------+
|  1|Alice|2025-12-21 10:30:...|
|  2|  Bob|2025-12-21 10:30:...|
+---+-----+--------------------+
```

---

## 🔧 Commandes utiles

### Voir les logs

```bash
# Tous les services
docker compose logs -f

# Livy uniquement
docker compose logs -f livy

# Spark Master uniquement
docker compose logs -f spark-master
```

### Redémarrer un service

```bash
docker compose restart livy
docker compose restart spark-master
```

### Arrêter la stack

```bash
docker compose down

# ⚠️ Avec suppression des données
docker compose down -v
```

---

## 🐛 Problèmes fréquents

### ❌ "Connexion refused" sur Livy (8998)

**Solution**: Attendre 1-2 minutes après `docker compose up`

```bash
docker compose logs -f livy
```

Attendre le message: `✅ Configuration ready!`

---

### ❌ Build Livy échoue (Maven timeout)

**Solution**: Augmenter RAM Docker

1. Docker Desktop → Settings → Resources
2. RAM: minimum **6 GB**
3. Retry:
   ```bash
   docker compose build --no-cache livy
   ```

---

### ❌ "All masters are unresponsive"

**Solution**: Redémarrer Spark Cluster

```bash
docker compose restart spark-master
sleep 10
docker compose restart spark-worker
sleep 10
docker compose restart livy
```

---

## 📚 Documentation complète

- 📖 [README.md](../README.md) → Vue d'ensemble
- 🏗️ [ARCHITECTURE_DECISIONS.md](ARCHITECTURE_DECISIONS.md) → Choix techniques
- 📘 [BUILD_AND_DEPLOYMENT.md](BUILD_AND_DEPLOYMENT.md) → Guide complet
- 📓 [zeppelin-configuration.md](zeppelin-configuration.md) → Config Zeppelin

---

## 🎉 Prêt !

Votre lakehouse moderne est opérationnel !

**Next steps**:
1. Explorer Zeppelin (notebooks)
2. Tester les branches Nessie (versioning Git-like)
3. Créer des tables Iceberg sur MinIO
4. Expérimenter avec PySpark/SQL

**Besoin d'aide ?** Consultez [BUILD_AND_DEPLOYMENT.md](BUILD_AND_DEPLOYMENT.md) 📖
