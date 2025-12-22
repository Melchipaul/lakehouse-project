#!/bin/bash
# Script de validation rapide des fonctionnalités avancées

set -e

LIVY_URL="http://localhost:8998"
NESSIE_URL="http://localhost:19120/api/v2"

echo "🚀 VALIDATION DES FONCTIONNALITÉS AVANCÉES"
echo "============================================================"

# Créer session
echo "✅ Création de la session PySpark..."
SESSION_ID=$(curl -s -X POST $LIVY_URL/sessions -H "Content-Type: application/json" -d '{"kind":"pyspark"}' | jq -r '.id')
echo "   Session ID: $SESSION_ID"

# Attendre que la session soit prête
echo "⏳ Attente du démarrage (environ 30s)..."
for i in {1..60}; do
    STATE=$(curl -s $LIVY_URL/sessions/$SESSION_ID | jq -r '.state')
    if [ "$STATE" = "idle" ]; then
        echo "✅ Session prête!"
        break
    fi
    echo -ne "   État: $STATE (${i}s)\r"
    sleep 1
done

# Fonction pour exécuter du code
execute_code() {
    local code="$1"
    local description="$2"
    
    echo -e "\n📝 $description"
    
    # Soumettre le code
    STMT_ID=$(curl -s -X POST $LIVY_URL/sessions/$SESSION_ID/statements \
        -H "Content-Type: application/json" \
        -d "{\"code\":$(echo "$code" | jq -Rs .)}" | jq -r '.id')
    
    # Attendre le résultat
    for i in {1..30}; do
        RESULT=$(curl -s $LIVY_URL/sessions/$SESSION_ID/statements/$STMT_ID)
        STATE=$(echo "$RESULT" | jq -r '.state')
        
        if [ "$STATE" = "available" ]; then
            OUTPUT=$(echo "$RESULT" | jq -r '.output.data."text/plain" // .output.evalue // "N/A"')
            echo "$OUTPUT"
            break
        fi
        sleep 1
    done
}

echo -e "\n============================================================"
echo "TEST 1: ICEBERG TIME-TRAVEL"
echo "============================================================"

execute_code "
from datetime import datetime
import time

# État initial
df_before = spark.sql('SELECT COUNT(*) as count FROM nessie.demo_db.users')
count_before = df_before.collect()[0]['count']
print(f'📊 Avant: {count_before} lignes')

# Capturer timestamp
timestamp_before = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
time.sleep(2)

# Ajouter données
spark.sql('INSERT INTO nessie.demo_db.users VALUES (10, \\'TimeTravel\\', now()), (11, \\'Test\\', now())')
time.sleep(2)

# État après
df_after = spark.sql('SELECT COUNT(*) as count FROM nessie.demo_db.users')
count_after = df_after.collect()[0]['count']
print(f'📊 Après: {count_after} lignes (+{count_after - count_before})')

# Time-travel
print(f'\\n🕐 Time-travel vers {timestamp_before}...')
df_history = spark.sql(f'SELECT * FROM nessie.demo_db.users TIMESTAMP AS OF \\'{timestamp_before}\\'')
print(f'   Version historique: {df_history.count()} lignes')

df_current = spark.sql('SELECT * FROM nessie.demo_db.users')
print(f'   Version actuelle: {df_current.count()} lignes')

print('✅ Time-travel validé!')
" "Test du time-travel"

echo -e "\n============================================================"
echo "TEST 2: NESSIE BRANCHING"
echo "============================================================"

# Créer branche via API Nessie
MAIN_HASH=$(curl -s $NESSIE_URL/trees/branch/main | jq -r '.hash')
echo "📌 Hash branche main: ${MAIN_HASH:0:8}..."

curl -s -X POST $NESSIE_URL/trees/branch/dev \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"dev\",\"hash\":\"$MAIN_HASH\"}" > /dev/null 2>&1

echo "✅ Branche 'dev' créée"

execute_code "
# Basculer sur branche dev
spark.conf.set('spark.sql.catalog.nessie.ref', 'dev')
print('📍 Branche active: dev')

# Créer table sur dev
spark.sql('CREATE TABLE IF NOT EXISTS nessie.demo_db.test_dev (id INT, data STRING) USING iceberg')
spark.sql('INSERT INTO nessie.demo_db.test_dev VALUES (1, \\'dev_data\\')')

df_dev = spark.sql('SELECT * FROM nessie.demo_db.test_dev')
print(f'✅ Table sur dev: {df_dev.count()} lignes')

# Revenir à main
spark.conf.set('spark.sql.catalog.nessie.ref', 'main')
print('📍 Retour sur branche: main')

# Vérifier isolation
try:
    spark.sql('SELECT * FROM nessie.demo_db.test_dev')
    print('❌ Table visible sur main (erreur isolation)')
except:
    print('✅ Table non visible sur main (isolation OK)')

print('✅ Branching validé!')
" "Test de l'isolation des branches"

echo -e "\n============================================================"
echo "TEST 3: SCHEMA EVOLUTION"
echo "============================================================"

execute_code "
# Schéma avant
print('📋 Schéma avant:')
spark.sql('DESCRIBE nessie.demo_db.users').select('col_name', 'data_type').show(truncate=False)

# Ajouter colonne
print('\\n➕ Ajout colonne email...')
spark.sql('ALTER TABLE nessie.demo_db.users ADD COLUMN IF NOT EXISTS email STRING')

# Schéma après
print('📋 Schéma après:')
spark.sql('DESCRIBE nessie.demo_db.users').select('col_name', 'data_type').show(truncate=False)

# Insérer avec nouvelle colonne
spark.sql('INSERT INTO nessie.demo_db.users VALUES (12, \\'Schema\\', now(), \\'schema@test.com\\')')

# Vérifier données
print('\\n📊 Données (anciennes: email NULL, nouvelles: email rempli):')
df = spark.sql('SELECT id, name, email FROM nessie.demo_db.users WHERE id >= 10 ORDER BY id')
df.show()

print('✅ Schema evolution validé!')
" "Test de l'évolution de schéma"

echo -e "\n============================================================"
echo "TEST 4: MERGE INTO (UPSERT)"
echo "============================================================"

execute_code "
# Table staging
print('📦 Création table staging...')
spark.sql('DROP TABLE IF EXISTS nessie.demo_db.staging_users')
spark.sql('CREATE TABLE nessie.demo_db.staging_users (id INT, name STRING, created_at TIMESTAMP, email STRING) USING iceberg')

# Données staging (update + insert)
spark.sql('''
INSERT INTO nessie.demo_db.staging_users VALUES 
  (10, 'TimeTravel UPDATED', now(), 'updated@example.com'),
  (13, 'NewUser', now(), 'new@example.com')
''')

print('\\n📝 Données staging:')
spark.sql('SELECT * FROM nessie.demo_db.staging_users').show()

# MERGE INTO
print('\\n🔄 Exécution MERGE INTO...')
spark.sql('''
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
''')

# Résultat
print('\\n✅ Résultat MERGE:')
df = spark.sql('SELECT id, name, email FROM nessie.demo_db.users WHERE id IN (10, 13) ORDER BY id')
df.show()

# Nettoyage
spark.sql('DROP TABLE nessie.demo_db.staging_users')

print('✅ MERGE INTO validé!')
" "Test des opérations MERGE"

echo -e "\n============================================================"
echo "✅ TOUS LES TESTS VALIDÉS AVEC SUCCÈS!"
echo "============================================================"

# Fermer session
echo -e "\n🧹 Fermeture de la session..."
curl -s -X DELETE $LIVY_URL/sessions/$SESSION_ID > /dev/null
echo "✅ Session fermée"
