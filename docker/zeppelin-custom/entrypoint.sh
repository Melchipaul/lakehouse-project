#!/bin/bash
set -e

echo "🚀 Démarrage de Zeppelin..."

# Vérifier les variables d'environnement
if [ -z "$MINIO_ACCESS_KEY" ] || [ -z "$MINIO_SECRET_KEY" ]; then
    echo "⚠️  WARNING: MINIO_ACCESS_KEY ou MINIO_SECRET_KEY non définis!"
fi

# Configuration Livy
LIVY_URL="${ZEPPELIN_INTP_LIVY_URL:-http://livy:8998}"
SPARK_MASTER="${ZEPPELIN_INTP_LIVY_SPARK_MASTER:-spark://spark-master:7077}"

# Fonction pour patcher le fichier interpreter.json
patch_interpreter_config() {
    local config_file="/opt/zeppelin/conf/interpreter.json"
    if [ -f "$config_file" ]; then
        # Remplacer localhost:8998 par l'URL Livy configurée
        if grep -q "localhost:8998" "$config_file"; then
            sed -i "s|http://localhost:8998|${LIVY_URL}|g" "$config_file"
            echo "✅ Configuration Livy patchée: ${LIVY_URL}"
        fi
    fi
}

# Patcher en arrière-plan après que Zeppelin ait créé le fichier
(
    sleep 30
    patch_interpreter_config
) &

echo "📋 Configuration de l'interpréteur Livy..."
echo "✅ Configuration prête!"
echo "📊 Zeppelin UI: http://0.0.0.0:8080"
echo "🔗 Livy URL: ${LIVY_URL}"
echo ""

# Démarrer Zeppelin
exec /usr/bin/tini -- bin/zeppelin.sh
