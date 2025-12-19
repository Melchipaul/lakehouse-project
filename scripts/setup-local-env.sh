#!/bin/bash

set -e

echo "==================================="
echo "Lakehouse Local Environment Setup"
echo "==================================="

ENV=${1:-dev}

echo ""
echo "Setting up ${ENV} environment..."

# Vérifier si .env existe déjà
if [ -f "docker/${ENV}/.env" ]; then
    read -p ".env file already exists. Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing .env file"
        exit 0
    fi
fi

# Vérifier que le template existe
if [ ! -f "docker/${ENV}/.env.example" ]; then
    echo "❌ Error: Template file docker/${ENV}/.env.example not found"
    exit 1
fi

# Copier le template
cp "docker/${ENV}/.env.example" "docker/${ENV}/.env"

echo ""
echo "Generating secure random passwords..."

# Générer les secrets
MINIO_PASSWORD=$(openssl rand -base64 12)
POSTGRES_PASSWORD=$(openssl rand -base64 16)
AIRFLOW_FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || openssl rand -base64 32)
AIRFLOW_SECRET_KEY=$(openssl rand -hex 32)
AIRFLOW_PASSWORD=$(openssl rand -base64 12)
GRAFANA_PASSWORD=$(openssl rand -base64 12)

# Remplir les valeurs dans le fichier .env
sed -i "s|^MINIO_ROOT_USER=.*|MINIO_ROOT_USER=admin|" "docker/${ENV}/.env"
sed -i "s|^MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=${MINIO_PASSWORD}|" "docker/${ENV}/.env"
sed -i "s|^POSTGRES_USER=.*|POSTGRES_USER=lakehouse|" "docker/${ENV}/.env"
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" "docker/${ENV}/.env"
sed -i "s|^AIRFLOW_FERNET_KEY=.*|AIRFLOW_FERNET_KEY=${AIRFLOW_FERNET_KEY}|" "docker/${ENV}/.env"
sed -i "s|^AIRFLOW_SECRET_KEY=.*|AIRFLOW_SECRET_KEY=${AIRFLOW_SECRET_KEY}|" "docker/${ENV}/.env"
sed -i "s|^AIRFLOW_ADMIN_USER=.*|AIRFLOW_ADMIN_USER=admin|" "docker/${ENV}/.env"
sed -i "s|^AIRFLOW_ADMIN_PASSWORD=.*|AIRFLOW_ADMIN_PASSWORD=${AIRFLOW_PASSWORD}|" "docker/${ENV}/.env"
sed -i "s|^GRAFANA_ADMIN_USER=.*|GRAFANA_ADMIN_USER=admin|" "docker/${ENV}/.env"
sed -i "s|^GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=${GRAFANA_PASSWORD}|" "docker/${ENV}/.env"

echo ""
echo "✓ Environment file created: docker/${ENV}/.env"
echo ""
echo "��� Credentials Summary:"
echo "================================"
echo "MinIO Console: http://localhost:9001"
echo "  Username: admin"
echo "  Password: ${MINIO_PASSWORD}"
echo ""
echo "Airflow: http://localhost:8082"
echo "  Username: admin"
echo "  Password: ${AIRFLOW_PASSWORD}"
echo ""
echo "Grafana: http://localhost:3001"
echo "  Username: admin"
echo "  Password: ${GRAFANA_PASSWORD}"
echo "================================"
echo ""
echo "⚠️  IMPORTANT: Save these credentials securely!"
echo "⚠️  The .env file is git-ignored and won't be committed"
echo ""
echo "To start the environment, run:"
echo "  cd docker/${ENV}"
echo "  docker-compose up -d"
