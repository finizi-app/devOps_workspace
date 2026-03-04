# Deployment Guide

CI/CD procedures and workflows for Finizi deployments.

---

## Overview

Deployments use GitHub Actions with OIDC authentication to Azure Key Vault for secrets management.

### Environments
| Environment | Branch | Domain | Key Vault | VM IP |
|-------------|--------|--------|-----------|-------|
| Staging | `develop` | admin.dev.finizi.ai | kv-finizi-staging-2026 | 52.163.118.135 |
| Production | `master` | admin.prod.finizi.ai | kv-finizi-prod-2026 | 20.212.32.64 |

### Credential Handling
Production workflow automatically:
1. Fetches base64-encoded credentials from Key Vault:
   - `GCS-CREDENTIALS-BASE64` (Google Cloud Storage)
   - `FIREBASE-CREDENTIALS-BASE64` (Firebase Auth)
2. Decodes and saves to `/mnt/b4b-api/credentials/`
3. App uses paths `/app/credentials/...` (not `./credentials/`)

### Key Fixes Applied (2026-03-03)
| Issue | Fix |
|-------|-----|
| Staging/Production shared Key Vault | Created separate `kv-finizi-prod-2026` |
| Health check used domain (DNS not ready) | Changed to `localhost:8101/health` |
| SCP copied entire repo (slow) | Switched to git clone/pull on VM |
| Redis no persistence | Added `--appendonly yes` |
| App starts before Redis ready | Added `depends_on: redis: condition: service_healthy` |
| No HTTP fallback nginx | Created `nginx.production-http.conf` |
| Workers missing tmp_data volume | Added `./data/tmp_data:/tmp` |

---

## GitHub Actions Workflows

### Staging Deployment
**File**: `.github/workflows/deploy-staging-azure.yml`
**Trigger**: Push to `develop` branch

**Steps**:
1. Checkout code
2. Azure Login (OIDC)
3. Fetch secrets from Key Vault
4. Copy `.env.staging` to VM
5. Git pull on VM
6. Build Docker images
7. Run migrations (Alembic)
8. Health check
9. Update nginx
10. Slack notification

### Production Deployment
**File**: `.github/workflows/deploy-production-azure.yml`
**Trigger**: Push to `master` branch

**Additional Steps**:
- Fetches credentials from Key Vault (base64 encoded)
- Saves credentials to `/mnt/b4b-api/credentials/`
- Uses HTTP fallback nginx if SSL not ready

---

## Required GitHub Secrets

### Azure Authentication (OIDC)
| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Azure AD App Client ID |
| `AZURE_TENANT_ID` | Azure Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |

### Staging VM
| Secret | Value |
|--------|-------|
| `AZURE_VM_HOST` | Staging VM IP |
| `AZURE_VM_USER` | `azureuser` |
| `AZURE_SSH_KEY` | Private SSH key |

### Production VM
| Secret | Value |
|--------|-------|
| `AZURE_VM_HOST_PROD` | `20.212.32.64` |
| `AZURE_VM_USER_PROD` | `azureuser` |
| `AZURE_SSH_KEY_PROD` | Private SSH key |

### Notifications
| Secret | Description |
|--------|-------------|
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications |

---

## Deployment Process

### 1. Code Merge
```bash
# Create PR to develop (staging) or master (production)
gh pr create --base develop --head feature/xxx
```

### 2. Automatic Deployment
After merge, GitHub Actions automatically:
1. Builds Docker images on VM
2. Runs database migrations
3. Restarts containers
4. Verifies health check

### 3. Verification
```bash
# Check deployment status
curl https://admin.prod.finizi.ai/backend/health
```

---

## Manual Deployment

### SSH to VM
```bash
ssh azureuser@20.212.32.64
cd /mnt/b4b-api
```

### Pull Latest Code
```bash
git fetch origin master
git checkout master
git pull origin master
```

### Build Images
```bash
# Backend
docker build -t b4b_backend:production . -f Dockerfile.backend

# Frontend
docker build -t b4b_frontend:production . -f ./frontend/Dockerfile \
  --build-arg NEXT_PUBLIC_API_BASE_URL=https://admin.prod.finizi.ai/backend \
  --build-arg API_URL_INTERNAL=http://app:8000 \
  --build-arg NEXT_PUBLIC_FIREBASE_API_KEY=${FIREBASE_API_KEY} \
  --build-arg NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=finizi-ai.firebaseapp.com \
  --build-arg NEXT_PUBLIC_FIREBASE_PROJECT_ID=finizi-ai \
  --build-arg NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=finizi-ai.appspot.com \
  --build-arg NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=117315126053 \
  --build-arg NEXT_PUBLIC_FIREBASE_APP_ID=1:117315126053:web:finizi-web-app
```

### Run Migrations
```bash
docker exec b4b_prod_app uv run alembic upgrade heads
```

### Restart Services
```bash
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml up -d
```

### Health Check
```bash
curl http://localhost:8001/health
```

---

## Rollback

### Option 1: Revert Commit
```bash
# Revert the merge commit
git revert -m 1 HEAD
git push origin master
```

### Option 2: Manual Rollback
```bash
# On VM
cd /mnt/b4b-api
git log --oneline -5  # Find previous good commit
git checkout <commit-hash>

# Rebuild and restart
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml up -d
```

### Option 3: Database Rollback
```bash
# Rollback last migration
docker exec b4b_prod_app uv run alembic downgrade -1
```

---

## Troubleshooting

### Container Not Starting
```bash
# Check logs
docker compose -f docker-compose.production.yml logs app

# Check container status
docker compose -f docker-compose.production.yml ps
```

### Database Connection Issues
```bash
# Test connection
docker exec b4b_prod_app uv run python -c "from app.core.database import engine; engine.connect()"

# Check DATABASE_URL
docker exec b4b_prod_app env | grep DATABASE
```

### Nginx Issues
```bash
# Test config
sudo nginx -t

# Reload nginx
sudo nginx -s reload

# Check logs
sudo tail -f /var/log/nginx/error.log
```

### SSL Certificate Issues
```bash
# Check certificate
sudo certbot certificates

# Renew manually
sudo certbot renew

# Use HTTP fallback
sudo cp /mnt/b4b-api/nginx.production-http.conf /etc/nginx/sites-enabled/b4b-production
sudo nginx -s reload
```

### Disk Space
```bash
# Check disk usage
df -h

# Clean Docker
docker system prune -af
docker volume prune -f
```

---

## Monitoring

### Container Health
```bash
docker compose -f docker-compose.production.yml ps
```

### Application Logs
```bash
# All services
docker compose -f docker-compose.production.yml logs -f

# Specific service
docker compose -f docker-compose.production.yml logs -f app
docker compose -f docker-compose.production.yml logs -f worker
```

### Nginx Access Logs
```bash
sudo tail -f /var/log/nginx/access.log
```

---

## KiotViet Client Deployment

### VM Details
| Property | Value |
|----------|-------|
| IP | `52.163.118.135` |
| User | `azureuser` |
| App Dir | `/home/azureuser/kiotviet` |
| Port | 8010 |

### Quick Deploy
```bash
cd /Users/trunghuynh/development/finizi-dev/finizi_kiotviet_client
./deploy/deploy.sh
```

### First-Time Setup
```bash
# 1. Check VM readiness
./deploy/check-vm.sh

# 2. Prepare VM (if needed)
scp deploy/prepare-vm.sh azureuser@52.163.118.135:~/~
ssh azureuser@52.163.118.135 'sudo ~/prepare-vm.sh'

# 3. Setup nginx and firewall
scp deploy/setup-vm.sh azureuser@52.163.118.135:~/kiotviet/
ssh azureuser@52.163.118.135 'sudo ~/kiotviet/setup-vm.sh'
```

### GitHub Actions
**File**: `.github/workflows/deploy-azure.yml`
**Trigger**: Push to `production` branch

**Required Secret**:
| Secret | Value |
|--------|-------|
| `SSH_PRIVATE_KEY` | Content of `~/.ssh/id_rsa` |

### Verification
```bash
# Health check
curl http://52.163.118.135:8010/health

# API docs
open http://52.163.118.135:8010/docs
```

### Logs & Management
```bash
# View logs
ssh azureuser@52.163.118.135 "cd ~/kiotviet && docker compose logs -f"

# Restart
ssh azureuser@52.163.118.135 "cd ~/kiotviet && docker compose restart"

# Check status
ssh azureuser@52.163.118.135 "cd ~/kiotviet && docker compose ps"
```

### Troubleshooting
| Issue | Command |
|-------|---------|
| Container not running | `ssh azureuser@52.163.118.135 "docker ps"` |
| Nginx error | `ssh azureuser@52.163.118.135 "sudo nginx -t"` |
| Port blocked | Check Azure NSG rules for port 8010 |

---

## Maintenance

### Before Deployment
1. Check disk space: `df -h`
2. Check container status: `docker compose ps`
3. Backup database (production)

### After Deployment
1. Verify health endpoint
2. Check error logs
3. Monitor for 5-10 minutes

### Regular Tasks
- Weekly: Review Docker image cleanup
- Monthly: Review SSL certificate expiry
- Quarterly: Review and rotate secrets
