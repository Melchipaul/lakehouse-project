# Guide de Démonstration Zeppelin - Fonctionnalités Avancées

🌐 **URL Zeppelin**: http://localhost:8081

## Configuration Automatique

✅ **La configuration Spark (Iceberg + Nessie + MinIO) est injectée automatiquement au démarrage de Zeppelin.**

Les credentials MinIO sont variabilisés et passés automatiquement via les variables d'environnement au serveur Livy, qui gère les sessions Spark pour Zeppelin.

**Aucune configuration manuelle n'est nécessaire dans l'interface UI.**

Vous pouvez commencer immédiatement à utiliser les notebooks!

---

## 📝 Paragraphes du Notebook

Copier-coller ces paragraphes dans votre notebook Zeppelin:

---

### Paragraphe 1: Vérification de la Connexion

```scala
%livy.spark
// Vérifier la connexion au catalogue Nessie
spark.sql("SHOW DATABASES IN nessie").show()

// Vérifier la table existante
spark.sql("SELECT * FROM nessie.demo_db.users LIMIT 5").show()
```

**Résultat attendu**: Liste des bases de données et quelques lignes de la table users

---

### Paragraphe 2: 🕐 Time-Travel Iceberg

```scala
%livy.spark
import org.apache.spark.sql.functions._
import java.time.LocalDateTime

// Capturer l'état actuel
val countBefore = spark.sql("SELECT COUNT(*) as count FROM nessie.demo_db.users").collect()(0).getLong(0)
val timestampBefore = LocalDateTime.now()
println(s"📊 Avant: $countBefore lignes")
println(s"⏰ Timestamp: $timestampBefore")

// Attendre un peu
Thread.sleep(2000)

// Ajouter de nouvelles données
spark.sql("""
  INSERT INTO nessie.demo_db.users 
  VALUES 
    (100, 'Zeppelin User 1', now()), 
    (101, 'Zeppelin User 2', now())
""")

Thread.sleep(2000)

// Compter après
val countAfter = spark.sql("SELECT COUNT(*) as count FROM nessie.demo_db.users").collect()(0).getLong(0)
println(s"📊 Après: $countAfter lignes (+${countAfter - countBefore})")

// Time-travel vers la version précédente
println(s"\n🕐 Time-travel vers $timestampBefore...")
val timestampStr = timestampBefore.toString.replace("T", " ")
val dfHistory = spark.sql(s"SELECT * FROM nessie.demo_db.users TIMESTAMP AS OF '$timestampStr'")
println(s"   Version historique: ${dfHistory.count()} lignes")

val dfCurrent = spark.sql("SELECT * FROM nessie.demo_db.users")
println(s"   Version actuelle: ${dfCurrent.count()} lignes")

println("✅ Time-travel validé!")
```

**Résultat attendu**: 
- Avant: X lignes
- Après: X+2 lignes
- Time-travel montre X lignes (version historique)
- Version actuelle: X+2 lignes

---

### Paragraphe 3: 📊 Visualisation Time-Travel

```scala
%livy.spark
// Comparer les versions avec un graphique
val timestampStr = timestampBefore.toString.replace("T", " ")

val dfHistory = spark.sql(s"SELECT 'Historique' as version, COUNT(*) as count FROM nessie.demo_db.users TIMESTAMP AS OF '$timestampStr'")
val dfCurrent = spark.sql("SELECT 'Actuelle' as version, COUNT(*) as count FROM nessie.demo_db.users")

dfHistory.union(dfCurrent).show()
```

**Cliquer sur le bouton graphique (📊) et choisir Bar Chart**:
- Keys: `version`
- Values: `count`

---

### Paragraphe 4: 🌿 Nessie Branching

```scala
%livy.spark
// Basculer sur une branche dev
spark.conf.set("spark.sql.catalog.nessie.ref", "dev")
println("📍 Branche active: dev")

// Créer une table de test sur dev
spark.sql("CREATE TABLE IF NOT EXISTS nessie.demo_db.test_dev (id INT, data STRING) USING iceberg")
spark.sql("INSERT INTO nessie.demo_db.test_dev VALUES (1, 'dev_data'), (2, 'dev_test')")

val dfDev = spark.sql("SELECT * FROM nessie.demo_db.test_dev")
println(s"✅ Table sur dev: ${dfDev.count()} lignes")
dfDev.show()

// Revenir à main
spark.conf.set("spark.sql.catalog.nessie.ref", "main")
println("📍 Retour sur branche: main")

// Vérifier isolation
try {
  spark.sql("SELECT * FROM nessie.demo_db.test_dev")
  println("❌ Table visible sur main (erreur isolation)")
} catch {
  case e: Exception => 
    println("✅ Table non visible sur main (isolation OK)")
}

println("✅ Branching validé!")
```

**Résultat attendu**: 
- Table créée sur dev avec 2 lignes
- Table invisible sur main (isolation confirmée)

---

### Paragraphe 5: 🔄 Schema Evolution

```scala
%livy.spark
// Schéma avant
println("📋 Schéma avant:")
spark.sql("DESCRIBE nessie.demo_db.users").select("col_name", "data_type").show(truncate=false)

// Ajouter une colonne
println("\n➕ Ajout de la colonne 'email'...")
spark.sql("ALTER TABLE nessie.demo_db.users ADD COLUMN IF NOT EXISTS email STRING")

// Schéma après
println("📋 Schéma après:")
spark.sql("DESCRIBE nessie.demo_db.users").select("col_name", "data_type").show(truncate=false)

// Insérer avec la nouvelle colonne
spark.sql("INSERT INTO nessie.demo_db.users VALUES (102, 'Schema Test', now(), 'schema@test.com')")

// Afficher les données
println("\n📊 Données (anciennes: email NULL, nouvelles: email rempli):")
spark.sql("SELECT id, name, email FROM nessie.demo_db.users WHERE id >= 100 ORDER BY id").show()

println("✅ Schema evolution validé!")
```

**Résultat attendu**:
- Colonne `email` ajoutée au schéma
- Anciennes lignes: email = NULL
- Nouvelles lignes: email rempli

---

### Paragraphe 6: 🔀 MERGE INTO (Upsert)

```scala
%livy.spark
// Créer table de staging
println("📦 Création table staging...")
spark.sql("DROP TABLE IF EXISTS nessie.demo_db.staging_users")
spark.sql("CREATE TABLE nessie.demo_db.staging_users (id INT, name STRING, created_at TIMESTAMP, email STRING) USING iceberg")

// Données staging (update + insert)
spark.sql("""
  INSERT INTO nessie.demo_db.staging_users VALUES 
    (100, 'Zeppelin User 1 UPDATED', now(), 'updated@example.com'),
    (103, 'New Merged User', now(), 'merged@example.com')
""")

println("\n📝 Données staging:")
spark.sql("SELECT * FROM nessie.demo_db.staging_users").show()

// MERGE INTO
println("\n🔄 Exécution MERGE INTO...")
spark.sql("""
  MERGE INTO nessie.demo_db.users AS target
  USING nessie.demo_db.staging_users AS source
  ON target.id = source.id
  WHEN MATCHED THEN 
    UPDATE SET 
      target.name = source.name,
      target.email = source.email
  WHEN NOT MATCHED THEN
    INSERT (id, name, created_at, email) 
    VALUES (source.id, source.name, source.created_at, source.email)
""")

// Résultat
println("\n✅ Résultat MERGE:")
spark.sql("SELECT id, name, email FROM nessie.demo_db.users WHERE id IN (100, 103) ORDER BY id").show()

// Nettoyage
spark.sql("DROP TABLE nessie.demo_db.staging_users")

println("✅ MERGE INTO validé!")
```

**Résultat attendu**:
- ID 100: nom et email mis à jour
- ID 103: nouvelle ligne insérée

---

### Paragraphe 7: 📈 Visualisation Finale - Historique Complet

```scala
%livy.spark
// Afficher toutes les modifications
spark.sql("""
  SELECT 
    id,
    name,
    CASE 
      WHEN email IS NULL THEN 'Ancien'
      ELSE 'Nouveau'
    END as type,
    email
  FROM nessie.demo_db.users
  WHERE id >= 100
  ORDER BY id
""").show()
```

**Créer un graphique**:
- Type: Table
- Affiche: id, name, type, email

---

## 🎯 Résumé des Validations

✅ **Time-Travel**: Requêtes sur versions historiques  
✅ **Branching**: Isolation dev/main  
✅ **Schema Evolution**: Ajout colonne email  
✅ **MERGE INTO**: Upserts (updates + inserts)

---

## 🔍 Commandes Utiles

### Lister toutes les tables
```scala
%livy.spark
spark.sql("SHOW TABLES IN nessie.demo_db").show()
```

### Voir l'historique Iceberg
```scala
%livy.spark
spark.sql("SELECT * FROM nessie.demo_db.users.history").show(truncate=false)
```

### Voir les snapshots
```scala
%livy.spark
spark.sql("SELECT * FROM nessie.demo_db.users.snapshots").show(truncate=false)
```

### API Nessie - Lister les branches
```scala
%livy.spark
import scala.io.Source
import scala.util.parsing.json._

val url = "http://nessie:19120/api/v2/trees"
val response = Source.fromURL(url).mkString
println(response)
```

---

## 📚 Prochaines Étapes

1. **Monitoring**: Ajouter Grafana pour visualiser les métriques
2. **CI/CD**: Pipeline automatisé de tests
3. **Documentation**: Architecture complète du lakehouse
4. **Extensions**: Ajouter Trino, Metabase, ou Airflow

---

## 🐛 Troubleshooting

### Problème de connexion Nessie
```scala
%livy.spark
// Tester la connexion
spark.sql("SHOW DATABASES IN nessie").show()
```

### Problème MinIO
```bash
# Vérifier MinIO
docker compose exec minio mc alias set local http://localhost:9000 admin minio_secure_2025
docker compose exec minio mc ls local/warehouse-dev/
```

### Redémarrer Zeppelin
```bash
docker compose restart zeppelin
```
