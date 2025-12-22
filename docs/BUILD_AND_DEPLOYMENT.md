# 🏗️ Guide de Build et Déploiement - Projet Lakehouse

## 📋 Prérequis

- Docker 24.0+ avec BuildKit activé
- Docker Compose 2.0+
- **16 GB RAM minimum** disponibles pour Docker (stack complète 14 services)
- 30 GB d'espace disque libre

## 🚀 Démarrage Rapide

### 1. Configurer les credentials

```bash
# Copier le template
cp envs/.env.example envs/.env.dev

# Éditer et remplacer les valeurs
nano envs/.env.dev
```

### 2. Build des images custom

⚠️ **Le build de Livy prend 15-25 minutes** (compilation Maven)

```bash
docker compose --env-file envs/.env.dev build
```

### 3. Lancer la stack

```bash
docker compose --env-file envs/.env.dev up -d
```

## 🌍 Multi-Environnements

### Usage

```bash
# DEV
docker compose --env-file envs/.env.dev up -d

# PREPROD
docker compose --env-file envs/.env.preprod up -d

# PROD
docker compose --env-file envs/.env.prod up -d
```

### Ports par environnement

| Service | DEV | PREPROD | PROD |
|---------|-----|---------|------|
| PostgreSQL | 5432 | 6432 | 7432 |
| MinIO Console | 19001 | 20001 | 21001 |
| Nessie | 19120 | 20120 | 21120 |
| Zeppelin | 8081 | 9081 | 10081 |
| Dremio | 9047 | 10047 | 11047 |
| Airflow | 8082 | 9082 | 10082 |
| Prometheus | 9090 | 10090 | 11090 |
| Grafana | 3001 | 4001 | 5001 |
| Superset | 8088 | 9088 | 10088 |

### Différences par environnement

| Aspect | DEV | PREPROD | PROD |
|--------|-----|---------|------|
| Restart policy | `no` | `unless-stopped` | `unless-stopped` |
| Spark cores | 2 | 4 | 8 |
| Spark memory | 2g | 4g | 8g |
| Prometheus retention | 15d | 15d | 30d |

## 🔍 Vérification du déploiement

```bash
# Vérifier l'état
docker ps --format "table {{.Names}}\t{{.Status}}" | grep dev

# Tests de connectivité
curl http://localhost:8998/version         # Livy
curl http://localhost:19120/api/v2/config  # Nessie
curl http://localhost:9047                 # Dremio
curl http://localhost:8082/health          # Airflow
curl http://localhost:8088/health          # Superset
curl http://localhost:9090/-/healthy       # Prometheus
curl http://localhost:3001/api/health      # Grafana
```

## 🔄 CI/CD avec GitHub Actions

### Architecture

Le projet utilise un **self-hosted runner** pour déployer automatiquement :

```
[Push sur dev] → GitHub Actions → Self-hosted runner → docker compose up
[Merge sur preprod] → GitHub Actions → Self-hosted runner → docker compose up
[Merge sur prod] → GitHub Actions → Self-hosted runner → docker compose up
```

### Configurer le runner

```bash
# Télécharger
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -o actions-runner-linux-x64-2.321.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-linux-x64-2.321.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.321.0.tar.gz

# Configurer (token depuis GitHub > Settings > Actions > Runners)
./config.sh --url https://github.com/YOUR_USER/lakehouse-project --token YOUR_TOKEN

# Lancer comme service
sudo ./svc.sh install
sudo ./svc.sh start
```

### Workflow Git

1. **Développer sur `dev`** :
   ```bash
   git checkout dev
   # ... modifications ...
   git commit -m "feat: nouvelle fonctionnalité"
   git push
   # → Déploiement automatique en DEV
   ```

2. **Promouvoir en PREPROD** :
   ```bash
   # Créer une PR: dev → preprod
   # Après merge → Déploiement automatique en PREPROD
   ```

3. **Promouvoir en PROD** :
   ```bash
   # Créer une PR: preprod → prod
   # Après merge → Déploiement automatique en PROD
   ```

## 🛠️ Maintenance

### Rebuild d'un service

```bash
docker compose --env-file envs/.env.dev build --no-cache livy
docker compose --env-file envs/.env.dev up -d livy
```

### Logs

```bash
# Tous les services
docker compose --env-file envs/.env.dev logs -f

# Un service spécifique
docker compose --env-file envs/.env.dev logs -f livy
```

### Nettoyage

```bash
# Arrêter
docker compose --env-file envs/.env.dev down

# Arrêter + supprimer volumes (⚠️ perte données)
docker compose --env-file envs/.env.dev down -v
```

## 🐛 Troubleshooting

### Livy ne démarre pas

```bash
# Vérifier les logs
docker compose --env-file envs/.env.dev logs livy

# Redémarrer dans l'ordre
docker compose --env-file envs/.env.dev restart spark-master spark-worker livy
```

### Images custom non trouvées

```bash
# Rebuilder les images
docker compose --env-file envs/.env.dev build livy zeppelin superset
```

### Port déjà utilisé

Modifier le port dans `envs/.env.dev` et redémarrer.

## 📚 Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Architecture complète
- [ARCHITECTURE_DECISIONS.md](./ARCHITECTURE_DECISIONS.md) - Choix techniques
- [zeppelin-configuration.md](./zeppelin-configuration.md) - Config Zeppelin
