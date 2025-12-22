#!/bin/bash
set -e

echo "🚀 Démarrage de Zeppelin..."

# Vérifier les variables d'environnement
if [ -z "$MINIO_ACCESS_KEY" ] || [ -z "$MINIO_SECRET_KEY" ]; then
    echo "⚠️  WARNING: MINIO_ACCESS_KEY ou MINIO_SECRET_KEY non définis!"
fi

# Créer le répertoire de configuration
mkdir -p /zeppelin/conf

# Copier la configuration de l'interpréteur
echo "📋 Configuration de l'interpréteur Livy..."
cp /tmp/interpreter.json /zeppelin/conf/interpreter.json 2>/dev/null || {
    echo "⚠️  Échec copie interpreter.json, utilisation configuration par défaut"
}

echo "✅ Configuration prête!"
echo "📊 Zeppelin UI: http://0.0.0.0:8080"
echo "🔗 Livy URL: http://livy:8998"
echo ""

# Démarrer Zeppelin
exec /usr/bin/tini -- bin/zeppelin.sh
