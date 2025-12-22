#!/bin/bash
# ========================================
# Entrypoint Livy avec injection credentials
# ========================================

set -e

echo "🚀 Starting Apache Livy..."

# Vérifier que les credentials MinIO sont fournis
if [ -z "$MINIO_ACCESS_KEY" ] || [ -z "$MINIO_SECRET_KEY" ]; then
    echo "⚠️  WARNING: MINIO_ACCESS_KEY or MINIO_SECRET_KEY not set!"
    echo "   S3A connectivity will fail. Please set these environment variables."
fi

# Injecter les credentials dans spark-defaults.conf
echo "📝 Injecting MinIO credentials into spark-defaults.conf..."
sed -e "s|__MINIO_ACCESS_KEY__|${MINIO_ACCESS_KEY:-changeme}|g" \
    -e "s|__MINIO_SECRET_KEY__|${MINIO_SECRET_KEY:-changeme}|g" \
    ${LIVY_HOME}/conf/spark-defaults.conf.template > ${LIVY_HOME}/conf/spark-defaults.conf

echo "✅ Configuration ready!"
echo "📊 Livy Server: http://0.0.0.0:8998"
echo "🔗 Spark Master: ${SPARK_MASTER:-spark://spark-master:7077}"
echo ""

# Lancer Livy
exec ${LIVY_HOME}/bin/livy-server
