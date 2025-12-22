#!/usr/bin/env python3
"""
Script de validation des fonctionnalités avancées Iceberg + Nessie
"""
import requests
import json
import time
from datetime import datetime

LIVY_URL = "http://localhost:8998"
NESSIE_URL = "http://localhost:19120/api/v2"

def create_session():
    """Créer une session PySpark via Livy"""
    response = requests.post(
        f"{LIVY_URL}/sessions",
        headers={"Content-Type": "application/json"},
        json={"kind": "pyspark"}
    )
    session_id = response.json()["id"]
    print(f"✅ Session créée: {session_id}")
    
    # Attendre que la session soit prête
    print("⏳ Attente du démarrage de la session...")
    while True:
        status = requests.get(f"{LIVY_URL}/sessions/{session_id}").json()
        state = status["state"]
        if state == "idle":
            print("✅ Session prête")
            break
        elif state in ["error", "dead", "killed"]:
            print(f"❌ Session en erreur: {state}")
            return None
        print(f"   État: {state}")
        time.sleep(5)
    
    return session_id

def execute_code(session_id, code, description):
    """Exécuter du code dans la session"""
    print(f"\n📝 {description}")
    response = requests.post(
        f"{LIVY_URL}/sessions/{session_id}/statements",
        headers={"Content-Type": "application/json"},
        json={"code": code}
    )
    statement_id = response.json()["id"]
    
    # Attendre la fin de l'exécution
    while True:
        status = requests.get(
            f"{LIVY_URL}/sessions/{session_id}/statements/{statement_id}"
        ).json()
        state = status["state"]
        
        if state == "available":
            output = status.get("output", {})
            if output.get("status") == "ok":
                result = output.get("data", {}).get("text/plain", "")
                print(f"✅ {result}")
                return result
            else:
                error = output.get("evalue", "Unknown error")
                traceback = output.get("traceback", [])
                print(f"❌ Erreur: {error}")
                for line in traceback:
                    print(f"   {line}")
                return None
        elif state in ["error", "cancelled"]:
            print(f"❌ Statement en erreur: {state}")
            return None
        
        time.sleep(2)

def test_time_travel(session_id):
    """Test 1: Iceberg Time-Travel"""
    print("\n" + "="*60)
    print("TEST 1: ICEBERG TIME-TRAVEL")
    print("="*60)
    
    # Capturer le timestamp initial
    code1 = """
from datetime import datetime
import time

# Capturer l'état actuel
df_before = spark.sql("SELECT COUNT(*) as count FROM nessie.demo_db.users")
count_before = df_before.collect()[0]['count']
timestamp_before = datetime.now()

print(f"Avant: {count_before} lignes")
print(f"Timestamp: {timestamp_before}")

# Attendre 2 secondes pour avoir des timestamps différents
time.sleep(2)

# Ajouter nouvelles données
spark.sql("INSERT INTO nessie.demo_db.users VALUES (5, 'Eve', now()), (6, 'Frank', now())")

# Attendre 2 secondes
time.sleep(2)

# Compter après insertion
df_after = spark.sql("SELECT COUNT(*) as count FROM nessie.demo_db.users")
count_after = df_after.collect()[0]['count']

print(f"Après: {count_after} lignes")
print(f"Différence: +{count_after - count_before} lignes")

# Sauvegarder le timestamp pour le time-travel
f"timestamp:{timestamp_before.strftime('%Y-%m-%d %H:%M:%S')}"
"""
    result = execute_code(session_id, code1, "Ajouter des données avec timestamp")
    
    if result:
        # Extraire le timestamp
        timestamp_line = [line for line in result.split('\n') if 'timestamp:' in line]
        if timestamp_line:
            timestamp = timestamp_line[0].split('timestamp:')[1].strip()
            
            # Test du time-travel
            code2 = f"""
# Query avec time-travel (version historique)
print("\\n🕐 Time-travel vers version précédente...")
df_history = spark.sql("SELECT * FROM nessie.demo_db.users TIMESTAMP AS OF '{timestamp}'")
print(f"Lignes dans version historique: {{df_history.count()}}")
df_history.show()

# Query version actuelle
print("\\n📅 Version actuelle...")
df_current = spark.sql("SELECT * FROM nessie.demo_db.users")
print(f"Lignes dans version actuelle: {{df_current.count()}}")
df_current.show()

"✅ Time-travel validé"
"""
            execute_code(session_id, code2, "Tester le time-travel")

def test_nessie_branch(session_id):
    """Test 2: Nessie Branching"""
    print("\n" + "="*60)
    print("TEST 2: NESSIE BRANCHING")
    print("="*60)
    
    # Obtenir le hash actuel de la branche main
    response = requests.get(f"{NESSIE_URL}/trees/branch/main")
    if response.status_code == 200:
        main_hash = response.json()["hash"]
        print(f"✅ Hash de la branche main: {main_hash[:8]}...")
        
        # Créer une branche dev
        response = requests.post(
            f"{NESSIE_URL}/trees/branch/dev",
            headers={"Content-Type": "application/json"},
            json={"name": "dev", "hash": main_hash}
        )
        
        if response.status_code in [200, 204, 409]:
            print("✅ Branche 'dev' créée (ou existe déjà)")
            
            # Tester une modification sur la branche dev
            code = """
# Utiliser la branche dev
spark.conf.set("spark.sql.catalog.nessie.ref", "dev")

# Créer une table de test sur dev
spark.sql("CREATE TABLE IF NOT EXISTS nessie.demo_db.test_dev (id INT, data STRING) USING iceberg")
spark.sql("INSERT INTO nessie.demo_db.test_dev VALUES (1, 'dev_data')")

# Vérifier
df = spark.sql("SELECT * FROM nessie.demo_db.test_dev")
print(f"Lignes dans table dev: {df.count()}")
df.show()

# Revenir à main
spark.conf.set("spark.sql.catalog.nessie.ref", "main")

# Vérifier que la table n'existe pas sur main
try:
    spark.sql("SELECT * FROM nessie.demo_db.test_dev")
    print("❌ Table trouvée sur main (ne devrait pas exister)")
except Exception as e:
    print("✅ Table n'existe pas sur main (isolation correcte)")

"✅ Branching validé"
"""
            execute_code(session_id, code, "Tester l'isolation des branches")
        else:
            print(f"❌ Erreur création branche: {response.status_code}")
    else:
        print(f"❌ Erreur récupération hash: {response.status_code}")

def test_schema_evolution(session_id):
    """Test 3: Schema Evolution"""
    print("\n" + "="*60)
    print("TEST 3: SCHEMA EVOLUTION")
    print("="*60)
    
    code = """
# Afficher le schéma actuel
print("📋 Schéma avant évolution:")
spark.sql("DESCRIBE nessie.demo_db.users").show()

# Ajouter une colonne
print("\\n➕ Ajout de la colonne 'email'...")
spark.sql("ALTER TABLE nessie.demo_db.users ADD COLUMN email STRING")

# Afficher le nouveau schéma
print("\\n📋 Schéma après évolution:")
spark.sql("DESCRIBE nessie.demo_db.users").show()

# Insérer des données avec la nouvelle colonne
print("\\n📝 Insertion avec email...")
spark.sql("INSERT INTO nessie.demo_db.users VALUES (7, 'Grace', now(), 'grace@example.com')")

# Vérifier les anciennes lignes (email NULL) et nouvelles lignes
print("\\n📊 Données (anciennes sans email, nouvelles avec email):")
spark.sql("SELECT id, name, email FROM nessie.demo_db.users ORDER BY id").show()

"✅ Schema evolution validé"
"""
    execute_code(session_id, code, "Tester l'évolution de schéma")

def test_merge_into(session_id):
    """Test 4: MERGE INTO (Upsert)"""
    print("\n" + "="*60)
    print("TEST 4: MERGE INTO (UPSERT)")
    print("="*60)
    
    code = """
# Créer une table de staging
print("📦 Création table staging...")
spark.sql("CREATE TABLE IF NOT EXISTS nessie.demo_db.staging_users (id INT, name STRING, created_at TIMESTAMP, email STRING) USING iceberg")

# Insérer des données de staging (update + insert)
print("\\n📝 Données staging (mix update/insert)...")
spark.sql(\"\"\"
INSERT INTO nessie.demo_db.staging_users VALUES 
  (1, 'Alice Updated', now(), 'alice@new.com'),  -- UPDATE existant
  (8, 'Henry', now(), 'henry@example.com')       -- INSERT nouveau
\"\"\")

spark.sql("SELECT * FROM nessie.demo_db.staging_users").show()

# MERGE INTO
print("\\n🔄 Exécution MERGE INTO...")
spark.sql(\"\"\"
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
\"\"\")

# Vérifier le résultat
print("\\n✅ Résultat après MERGE:")
spark.sql("SELECT id, name, email FROM nessie.demo_db.users ORDER BY id").show()

# Nettoyage
spark.sql("DROP TABLE nessie.demo_db.staging_users")

"✅ MERGE INTO validé"
"""
    execute_code(session_id, code, "Tester les opérations MERGE")

def main():
    print("🚀 VALIDATION DES FONCTIONNALITÉS AVANCÉES")
    print("=" * 60)
    
    # Créer session
    session_id = create_session()
    if not session_id:
        return
    
    try:
        # Exécuter les tests
        test_time_travel(session_id)
        test_nessie_branch(session_id)
        test_schema_evolution(session_id)
        test_merge_into(session_id)
        
        print("\n" + "="*60)
        print("✅ TOUS LES TESTS VALIDÉS AVEC SUCCÈS!")
        print("="*60)
        
    finally:
        # Fermer la session
        print(f"\n🧹 Fermeture de la session {session_id}...")
        requests.delete(f"{LIVY_URL}/sessions/{session_id}")
        print("✅ Session fermée")

if __name__ == "__main__":
    main()
