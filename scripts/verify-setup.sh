#!/bin/bash
# ========================================
# Script de vérification de la stack Lakehouse
# ========================================

set -e

echo "🔍 Vérification de la structure du projet Lakehouse..."
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Compteurs
ERRORS=0
WARNINGS=0

# Fonction pour vérifier l'existence d'un fichier
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1 (MANQUANT)"
        ((ERRORS++))
    fi
}

# Fonction pour vérifier l'existence d'un répertoire
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
    else
        echo -e "${RED}✗${NC} $1/ (MANQUANT)"
        ((ERRORS++))
    fi
}

# Fonction pour vérifier un fichier avec avertissement
check_file_warn() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${YELLOW}⚠${NC} $1 (RECOMMANDÉ)"
        ((WARNINGS++))
    fi
}

echo "📁 Structure des fichiers..."
echo ""

# Docker
echo "🐳 Configuration Docker:"
check_file "docker/dev/docker-compose.yml"
check_file "docker/dev/.env.example"
check_file_warn "docker/dev/.env"
echo ""

# Livy
echo "🔥 Configuration Livy:"
check_dir "docker/livy-custom"
check_file "docker/livy-custom/Dockerfile"
check_file "docker/livy-custom/livy.conf"
check_file "docker/livy-custom/spark-defaults.conf.template"
check_file "docker/livy-custom/entrypoint.sh"
echo ""

# Livy config (legacy)
echo "📋 Configuration Livy (legacy - peut être obsolète):"
check_dir "docker/livy-config"
check_file "docker/livy-config/livy.conf"
check_file "docker/livy-config/spark-defaults.conf"
echo ""

# Zeppelin
echo "📓 Configuration Zeppelin:"
check_dir "docker/zeppelin-custom"
check_file "docker/zeppelin-custom/Dockerfile"
check_file_warn "docker/zeppelin-custom/interpreter.json"
echo ""

# PostgreSQL
echo "🐘 Configuration PostgreSQL:"
check_dir "config/postgres"
check_file "config/postgres/init.sql"
echo ""

# Documentation
echo "📚 Documentation:"
check_file "README.md"
check_file "docs/BUILD_AND_DEPLOYMENT.md"
check_file "docs/ARCHITECTURE_DECISIONS.md"
check_file_warn "docs/zeppelin-configuration.md"
echo ""

# Vérifications avancées
echo "🔬 Vérifications avancées..."
echo ""

# Vérifier que .env n'est pas dans Git
if [ -f ".gitignore" ]; then
    if grep -q "\.env$" .gitignore; then
        echo -e "${GREEN}✓${NC} .env est dans .gitignore"
    else
        echo -e "${RED}✗${NC} .env n'est PAS dans .gitignore (RISQUE SÉCURITÉ)"
        ((ERRORS++))
    fi
else
    echo -e "${YELLOW}⚠${NC} Pas de .gitignore trouvé"
    ((WARNINGS++))
fi

# Vérifier les credentials dans .env
if [ -f "docker/dev/.env" ]; then
    if grep -q "CHANGEME" docker/dev/.env; then
        echo -e "${YELLOW}⚠${NC} Des credentials CHANGEME sont encore présents dans .env"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓${NC} Credentials .env semblent configurés"
    fi
fi

# Vérifier que l'entrypoint est exécutable
if [ -f "docker/livy-custom/entrypoint.sh" ]; then
    if [ -x "docker/livy-custom/entrypoint.sh" ]; then
        echo -e "${GREEN}✓${NC} entrypoint.sh est exécutable"
    else
        echo -e "${YELLOW}⚠${NC} entrypoint.sh n'est pas exécutable (chmod +x recommandé)"
        ((WARNINGS++))
    fi
fi

echo ""
echo "================================================"
echo "Résumé:"
echo "================================================"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ Tout est OK !${NC}"
    echo ""
    echo "Prochaines étapes:"
    echo "1. cd docker/dev"
    echo "2. cp .env.example .env  # Si pas encore fait"
    echo "3. nano .env              # Configurer les credentials"
    echo "4. docker compose build   # Build des images"
    echo "5. docker compose up -d   # Lancer la stack"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS avertissement(s)${NC}"
    echo ""
    echo "La stack peut démarrer mais des configurations sont recommandées."
    exit 0
else
    echo -e "${RED}✗ $ERRORS erreur(s)${NC}"
    [ $WARNINGS -gt 0 ] && echo -e "${YELLOW}⚠ $WARNINGS avertissement(s)${NC}"
    echo ""
    echo "Corrigez les erreurs avant de continuer."
    exit 1
fi
