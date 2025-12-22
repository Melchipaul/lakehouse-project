# 🧪 Guide de test Apache Livy

## Objectif
Vérifier que Apache Livy fonctionne correctement avec Spark 3.5.4, Iceberg 1.7.0 et Nessie 0.106.0.

---

## 📋 Prérequis

Assurez-vous que la stack est démarrée :

```bash
cd docker/dev
docker compose ps
```

Tous les services doivent être **UP** et **healthy** :
- ✅ postgres (healthy)
- ✅ minio (healthy)
- ✅ nessie (healthy)
- ✅ spark-master (running)
- ✅ spark-worker (running)
- ✅ livy (healthy)
- ✅ zeppelin (healthy)

---

## 🔍 Test 1 : Vérifier que Livy démarre

### Vérifier les logs

```bash
docker compose logs livy | tail -50
```

**Attendu** :
```
🚀 Starting Apache Livy...
📝 Injecting MinIO credentials into spark-defaults.conf...
✅ Configuration ready!
📊 Livy Server: http://0.0.0.0:8998
🔗 Spark Master: spark://spark-master:7077
```

### Tester l'API version

```bash
curl -s http://localhost:8998/version | jq
```

**Attendu** :
```json
{
  "version": "0.9.0-incubating-SNAPSHOT",
  "sparkVersion": "3.5.4",
  "user": "spark",
  "url": "http://livy:8998"
}
```

### Vérifier les sessions actives

```bash
curl -s http://localhost:8998/sessions | jq
```

**Attendu** :
```json
{
  "from": 0,
  "total": 0,
  "sessions": []
}
```

---

## 🎯 Test 2 : Créer une session Spark

### Créer une session PySpark

```bash
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "kind": "pyspark",
    "conf": {
      "spark.executor.memory": "1g",
      "spark.driver.memory": "1g"
    }
  }' | jq
```

**Attendu** :
```json
{
  "id": 0,
  "name": null,
  "appId": null,
  "owner": null,
  "proxyUser": null,
  "state": "starting",
  "kind": "pyspark",
  "appInfo": {
    "driverLogUrl": null,
    "sparkUiUrl": null
  },
  "log": ["..."]
}
```

### Attendre que la session soit prête

```bash
# Vérifier l'état toutes les 5 secondes
watch -n 5 'curl -s http://localhost:8998/sessions/0 | jq ".state"'
```

**États possibles** :
- `"starting"` → En cours de démarrage
- `"idle"` → ✅ Prête à recevoir du code
- `"error"` → ❌ Problème de démarrage

---

## 🚀 Test 3 : Exécuter du code Spark basique

### Test simple : Compter de 0 à 100

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.range(0, 100).count()"
  }' | jq
```

**Attendu** :
```json
{
  "id": 0,
  "code": "spark.range(0, 100).count()",
  "state": "waiting",
  "output": null,
  "progress": 0.0,
  "started": 0,
  "completed": 0
}
```

### Récupérer le résultat

```bash
curl -s http://localhost:8998/sessions/0/statements/0 | jq
```

**Attendu** :
```json
{
  "id": 0,
  "code": "spark.range(0, 100).count()",
  "state": "available",
  "output": {
    "status": "ok",
    "execution_count": 0,
    "data": {
      "text/plain": "100"
    }
  },
  "progress": 1.0
}
```

✅ **Résultat : 100** → Spark fonctionne !

---

## 🗄️ Test 4 : Tester la connectivité MinIO (S3)

### Lire les credentials S3

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.conf.get(\"spark.hadoop.fs.s3a.access.key\")"
  }' | jq
```

### Tester l'accès à MinIO

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark._jsc.hadoopConfiguration().get(\"fs.s3a.endpoint\")"
  }' | jq
```

**Attendu** : `"http://minio:9000"`

---

## 📚 Test 5 : Tester Iceberg + Nessie

### Vérifier que Iceberg est chargé

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"SHOW CURRENT NAMESPACE\").show()"
  }' | jq
```

### Créer un namespace Nessie

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"CREATE NAMESPACE IF NOT EXISTS nessie.test_livy\")"
  }' | jq
```

### Créer une table Iceberg

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"\"\"\n    CREATE TABLE IF NOT EXISTS nessie.test_livy.demo (\n        id BIGINT,\n        name STRING,\n        timestamp TIMESTAMP\n    ) USING iceberg\n    LOCATION '\''s3a://warehouse-dev/test_livy/demo'\''\n\"\"\")"
  }' | jq
```

### Insérer des données

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"\"\"\n    INSERT INTO nessie.test_livy.demo VALUES\n    (1, '\''Alice'\'', CURRENT_TIMESTAMP),\n    (2, '\''Bob'\'', CURRENT_TIMESTAMP),\n    (3, '\''Charlie'\'', CURRENT_TIMESTAMP)\n\"\"\")"
  }' | jq
```

### Lire les données

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"SELECT * FROM nessie.test_livy.demo\").show()"
  }' | jq
```

**Attendu** : 3 lignes avec Alice, Bob, Charlie

---

## 🌿 Test 6 : Tester le versioning Nessie

### Créer une branche

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"CREATE BRANCH IF NOT EXISTS dev IN nessie\")"
  }' | jq
```

### Basculer sur la branche dev

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"USE REFERENCE dev IN nessie\")"
  }' | jq
```

### Modifier les données dans dev

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"INSERT INTO nessie.test_livy.demo VALUES (4, '\''David'\'', CURRENT_TIMESTAMP)\")"
  }' | jq
```

### Revenir sur main et vérifier l'isolation

```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"USE REFERENCE main IN nessie\")"
  }' | jq

# Vérifier qu'on a toujours 3 lignes (pas 4)
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"SELECT COUNT(*) FROM nessie.test_livy.demo\").show()"
  }' | jq
```

**Attendu** : `3` (David n'est que dans la branche dev)

---

## 🧹 Test 7 : Nettoyage

### Supprimer la session

```bash
curl -X DELETE http://localhost:8998/sessions/0 | jq
```

### Vérifier qu'il n'y a plus de sessions

```bash
curl -s http://localhost:8998/sessions | jq
```

---

## ✅ Checklist de validation

- [ ] Livy démarre sans erreur
- [ ] API `/version` retourne Spark 3.5.4
- [ ] Session PySpark se crée (état `idle`)
- [ ] Code Spark basique s'exécute (count)
- [ ] Credentials MinIO sont injectés
- [ ] Iceberg + Nessie fonctionnent
- [ ] Création de namespace/table réussie
- [ ] Insertion et lecture de données OK
- [ ] Branching Nessie fonctionne
- [ ] Isolation des branches validée

---

## 🐛 Troubleshooting

### Session reste en "starting"

```bash
# Vérifier les logs Livy
docker compose logs livy --tail=100

# Vérifier que Spark Master est accessible
docker exec dev-livy ping -c 3 spark-master

# Vérifier les logs Spark Master
docker compose logs spark-master --tail=50
```

### Erreur "UnknownHostException: minio"

```bash
# Vérifier la résolution DNS
docker exec dev-livy ping -c 3 minio

# Vérifier que MinIO est up
curl http://localhost:19000/minio/health/live
```

### Erreur Iceberg/Nessie

```bash
# Vérifier que Nessie répond
curl http://localhost:19120/api/v2/config

# Vérifier les packages Maven dans spark-defaults.conf
docker exec dev-livy cat /opt/livy/conf/spark-defaults.conf | grep jars.packages
```

---

## 📊 Tests via Spark Master UI

Pendant qu'une session Livy est active, visitez :
- http://localhost:8080 (Spark Master UI)
- Vous devriez voir l'application Livy dans "Running Applications"

---

## 🎯 Prochaine étape

Si tous les tests passent ✅, Livy est fonctionnel !

Vous pouvez alors :
1. Tester via Zeppelin (http://localhost:8081)
2. Ajouter les services suivants (Airflow, Prometheus, etc.)
3. Créer vos workflows de données

---

**Besoin d'aide ?** Consultez [BUILD_AND_DEPLOYMENT.md](BUILD_AND_DEPLOYMENT.md) pour plus de détails.
