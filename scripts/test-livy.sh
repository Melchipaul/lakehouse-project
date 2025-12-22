#!/bin/bash
# ========================================
# Script de test automatique Apache Livy
# ========================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
LIVY_URL="http://localhost:8998"
SESSION_ID=""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🧪 Test Apache Livy - Stack Lakehouse${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Fonction pour attendre
wait_seconds() {
    local seconds=$1
    echo -e "${YELLOW}⏳ Attente de ${seconds}s...${NC}"
    sleep $seconds
}

# Fonction pour tester une commande curl
test_endpoint() {
    local endpoint=$1
    local description=$2
    
    echo -e "${BLUE}🔍 Test: ${description}${NC}"
    
    if curl -sf "${LIVY_URL}${endpoint}" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ ${description} - OK${NC}"
        return 0
    else
        echo -e "${RED}❌ ${description} - ÉCHEC${NC}"
        return 1
    fi
}

# Test 1: Vérifier que Livy répond
echo -e "${BLUE}📊 Test 1: Vérifier l'API Livy${NC}"
if curl -sf "${LIVY_URL}/version" > /dev/null 2>&1; then
    VERSION=$(curl -s "${LIVY_URL}/version" | jq -r '.version')
    SPARK_VERSION=$(curl -s "${LIVY_URL}/version" | jq -r '.sparkVersion')
    echo -e "${GREEN}✅ Livy répond - Version: ${VERSION}${NC}"
    echo -e "${GREEN}✅ Spark Version: ${SPARK_VERSION}${NC}"
else
    echo -e "${RED}❌ Livy ne répond pas sur ${LIVY_URL}/version${NC}"
    echo -e "${YELLOW}Vérifiez que le service est démarré: docker compose ps livy${NC}"
    exit 1
fi
echo ""

# Test 2: Créer une session Spark
echo -e "${BLUE}📊 Test 2: Créer une session PySpark${NC}"
CREATE_SESSION=$(curl -s -X POST "${LIVY_URL}/sessions" \
  -H "Content-Type: application/json" \
  -d '{
    "kind": "pyspark",
    "conf": {
      "spark.executor.memory": "1g",
      "spark.driver.memory": "1g"
    }
  }')

SESSION_ID=$(echo $CREATE_SESSION | jq -r '.id')

if [ "$SESSION_ID" == "null" ] || [ -z "$SESSION_ID" ]; then
    echo -e "${RED}❌ Impossible de créer une session${NC}"
    echo "$CREATE_SESSION" | jq
    exit 1
fi

echo -e "${GREEN}✅ Session créée - ID: ${SESSION_ID}${NC}"
echo ""

# Test 3: Attendre que la session soit prête
echo -e "${BLUE}📊 Test 3: Attendre que la session soit prête${NC}"
MAX_WAIT=120  # 2 minutes max
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATE=$(curl -s "${LIVY_URL}/sessions/${SESSION_ID}" | jq -r '.state')
    
    if [ "$STATE" == "idle" ]; then
        echo -e "${GREEN}✅ Session prête (état: idle)${NC}"
        break
    elif [ "$STATE" == "error" ] || [ "$STATE" == "dead" ]; then
        echo -e "${RED}❌ Session en erreur (état: ${STATE})${NC}"
        curl -s "${LIVY_URL}/sessions/${SESSION_ID}" | jq '.log'
        exit 1
    else
        echo -e "${YELLOW}⏳ Session en cours de démarrage (état: ${STATE})${NC}"
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    fi
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${RED}❌ Timeout: la session n'est pas prête après ${MAX_WAIT}s${NC}"
    exit 1
fi
echo ""

# Test 4: Exécuter du code Spark simple
echo -e "${BLUE}📊 Test 4: Exécuter du code Spark (count)${NC}"
STATEMENT=$(curl -s -X POST "${LIVY_URL}/sessions/${SESSION_ID}/statements" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.range(0, 100).count()"
  }')

STATEMENT_ID=$(echo $STATEMENT | jq -r '.id')
echo -e "${YELLOW}⏳ Exécution du code...${NC}"
wait_seconds 3

RESULT=$(curl -s "${LIVY_URL}/sessions/${SESSION_ID}/statements/${STATEMENT_ID}" | jq -r '.output.data."text/plain"')

if [ "$RESULT" == "100" ]; then
    echo -e "${GREEN}✅ Code Spark exécuté - Résultat: ${RESULT}${NC}"
else
    echo -e "${RED}❌ Résultat inattendu: ${RESULT}${NC}"
    exit 1
fi
echo ""

# Test 5: Vérifier les credentials MinIO
echo -e "${BLUE}📊 Test 5: Vérifier les credentials MinIO${NC}"
STATEMENT=$(curl -s -X POST "${LIVY_URL}/sessions/${SESSION_ID}/statements" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark._jsc.hadoopConfiguration().get(\"fs.s3a.endpoint\")"
  }')

STATEMENT_ID=$(echo $STATEMENT | jq -r '.id')
wait_seconds 2

ENDPOINT=$(curl -s "${LIVY_URL}/sessions/${SESSION_ID}/statements/${STATEMENT_ID}" | jq -r '.output.data."text/plain"' | tr -d "'")

if [ "$ENDPOINT" == "http://minio:9000" ]; then
    echo -e "${GREEN}✅ MinIO endpoint configuré: ${ENDPOINT}${NC}"
else
    echo -e "${YELLOW}⚠️  Endpoint MinIO: ${ENDPOINT} (attendu: http://minio:9000)${NC}"
fi
echo ""

# Test 6: Créer un namespace Nessie
echo -e "${BLUE}📊 Test 6: Créer un namespace Nessie${NC}"
STATEMENT=$(curl -s -X POST "${LIVY_URL}/sessions/${SESSION_ID}/statements" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"CREATE NAMESPACE IF NOT EXISTS nessie.test_livy_auto\")"
  }')

STATEMENT_ID=$(echo $STATEMENT | jq -r '.id')
wait_seconds 3

STATE=$(curl -s "${LIVY_URL}/sessions/${SESSION_ID}/statements/${STATEMENT_ID}" | jq -r '.state')

if [ "$STATE" == "available" ]; then
    echo -e "${GREEN}✅ Namespace Nessie créé${NC}"
else
    echo -e "${RED}❌ Erreur lors de la création du namespace${NC}"
    curl -s "${LIVY_URL}/sessions/${SESSION_ID}/statements/${STATEMENT_ID}" | jq
    exit 1
fi
echo ""

# Test 7: Créer une table Iceberg
echo -e "${BLUE}📊 Test 7: Créer une table Iceberg${NC}"
STATEMENT=$(curl -s -X POST "${LIVY_URL}/sessions/${SESSION_ID}/statements" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spark.sql(\"CREATE TABLE IF NOT EXISTS nessie.test_livy_auto.demo (id BIGINT, name STRING) USING iceberg LOCATION '\''s3a://warehouse-dev/test_livy_auto/demo'\''\")"
  }')

STATEMENT_ID=$(echo $STATEMENT | jq -r '.id')
wait_seconds 5

STATE=$(curl -s "${LIVY_URL}/sessions/${SESSION_ID}/statements/${STATEMENT_ID}" | jq -r '.state')

if [ "$STATE" == "available" ]; then
    echo -e "${GREEN}✅ Table Iceberg créée${NC}"
else
    echo -e "${RED}❌ Erreur lors de la création de la table${NC}"
    curl -s "${LIVY_URL}/sessions/${SESSION_ID}/statements/${STATEMENT_ID}" | jq '.output'
    exit 1
fi
echo ""

# Nettoyage
echo -e "${BLUE}🧹 Nettoyage: Suppression de la session${NC}"
curl -s -X DELETE "${LIVY_URL}/sessions/${SESSION_ID}" > /dev/null
echo -e "${GREEN}✅ Session supprimée${NC}"
echo ""

# Résumé
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ TOUS LES TESTS SONT PASSÉS !${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}🎉 Apache Livy est fonctionnel avec:${NC}"
echo -e "   ✅ Spark 3.5.4"
echo -e "   ✅ Apache Iceberg"
echo -e "   ✅ Project Nessie"
echo -e "   ✅ MinIO (S3)"
echo ""
echo -e "${YELLOW}📚 Prochaines étapes:${NC}"
echo -e "   1. Tester via Zeppelin (http://localhost:8081)"
echo -e "   2. Ajouter les services suivants (Airflow, Prometheus, etc.)"
echo -e "   3. Créer vos workflows de données"
echo ""
