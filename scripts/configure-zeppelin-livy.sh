#!/bin/bash
set -e

echo "🔧 Configuration automatique de l'interpréteur Livy dans Zeppelin..."

# Attendre que Zeppelin soit prêt
echo "⏳ Attente de Zeppelin..."
for i in {1..30}; do
    if curl -s http://localhost:8081/api/version > /dev/null 2>&1; then
        echo "✅ Zeppelin est prêt"
        break
    fi
    sleep 2
done

# Configuration JSON de l'interpréteur Livy
cat > /tmp/livy-interpreter.json <<'EOF'
{
  "name": "livy",
  "group": "livy",
  "properties": {
    "zeppelin.livy.url": {
      "name": "zeppelin.livy.url",
      "value": "http://livy:8998",
      "type": "url"
    },
    "livy.spark.master": {
      "name": "livy.spark.master",
      "value": "spark://spark-master:7077",
      "type": "string"
    },
    "zeppelin.livy.session.create_timeout": {
      "name": "zeppelin.livy.session.create_timeout",
      "value": "120",
      "type": "number"
    },
    "zeppelin.livy.spark.sql.maxResult": {
      "name": "zeppelin.livy.spark.sql.maxResult",
      "value": "1000",
      "type": "number"
    }
  },
  "dependencies": [],
  "option": {
    "remote": true,
    "perNote": "shared",
    "perUser": "shared"
  }
}
EOF

# Configurer l'interpréteur via l'API
echo "📝 Configuration de l'interpréteur Livy..."
curl -s -X PUT \
  http://localhost:8081/api/interpreter/setting/livy \
  -H 'Content-Type: application/json' \
  -d @/tmp/livy-interpreter.json | jq -r '.status'

echo "✅ Configuration terminée!"
echo ""
echo "🎯 Vous pouvez maintenant utiliser %livy.spark dans vos notebooks"
echo "🌐 Ouvrir: http://localhost:8081"
