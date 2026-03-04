# Target Projects

Projects managed by this DevOps workspace.

---

## 1. b4b-api (Main API)

**Path**: `/Users/trunghuynh/development/b4b-api/`
**GitHub**: https://github.com/finizi-app/b4b-api

### Stack
- **Backend**: FastAPI 0.116.1 (Python 3.11+)
- **Frontend**: Next.js 15.5.7 (App Router)
- **Database**: PostgreSQL 15+ with pgvector
- **Queue**: Celery 5.3.1 + Redis 7
- **Storage**: Google Cloud Storage
- **AI**: Google Generative AI (Gemini)

### Features
- Vietnamese E-Invoice Processing (XML compliant)
- Tax Portal Integration (GDTVN)
- Multi-Entity Management with RBAC
- AI-Powered Invoice Extraction
- Email Integration (OAuth 2.0)
- Payroll Management (S5-HKD compliant)

### CI/CD
| Workflow | Trigger | Environment |
|----------|---------|-------------|
| `deploy-staging-azure.yml` | Push to `develop` | Staging VM |
| `deploy-production-azure.yml` | Push to `master` | Production VM |

### Key Files
```
b4b-api/
├── .github/workflows/
│   ├── deploy-staging-azure.yml
│   └── deploy-production-azure.yml
├── docker-compose.staging.yml
├── docker-compose.production.yml
├── nginx.staging.conf
├── nginx.production.conf
├── nginx.production-http.conf
├── Dockerfile.backend
├── frontend/Dockerfile
└── docs/journals/deployment-azure-production.md
```

### Deployment Artifacts
- Backend image: `b4b_backend:staging|production`
- Frontend image: `b4b_frontend:staging|production`

### Production URLs
| Service | URL |
|---------|-----|
| Frontend | https://admin.prod.finizi.ai/ |
| Backend Health | https://admin.prod.finizi.ai/backend/health |
| Backend API | https://admin.prod.finizi.ai/backend/ |

### Staging URLs
| Service | URL |
|---------|-----|
| Frontend | http://admin.dev.finizi.ai/ |
| Backend Health | http://admin.dev.finizi.ai/backend/health |

### Database (Migrated from GCP 2026-03-03)
- Source: GCP Cloud SQL (34.124.143.192)
- Target: Azure PostgreSQL (b4b-staging-db.postgres.database.azure.com)
- 126 tables, 644K+ webhooks, 151K+ invoices

---

## 2. finizi_kiotviet_client

**Path**: `/Users/trunghuynh/development/finizi-dev/finizi_kiotviet_client/`

### Stack
- **Backend**: Python/FastAPI
- **Container**: Docker + Docker Compose
- **Proxy**: Nginx
- **Purpose**: KiotViet POS/ERP integration client

### Infrastructure
| Property | Value |
|----------|-------|
| VM Name | finizi_dev |
| IP | 52.163.118.135 |
| User | azureuser |
| OS | Ubuntu 22.04 LTS |
| App Dir | `/home/azureuser/kiotviet` |
| Ports | 80 (HTTP), 8010 (Alt), 8000 (Container) |

### CI/CD
| Workflow | Trigger | Target |
|----------|---------|--------|
| `deploy-azure.yml` | Push to `production` | Port 8010 |

### Deployment Scripts
| Script | Purpose |
|--------|---------|
| `deploy/deploy.sh` | Full deploy from local (5 steps) |
| `deploy/setup-vm.sh` | First-time VM setup (nginx, ufw) |
| `deploy/prepare-vm.sh` | Install docker, compose |
| `deploy/check-vm.sh` | Verify VM readiness (8 checks) |

### Quick Commands
```bash
# Deploy
./deploy/deploy.sh

# Check VM readiness
./deploy/check-vm.sh

# View logs
ssh azureuser@52.163.118.135 "cd ~/kiotviet && docker compose logs -f"

# Restart
ssh azureuser@52.163.118.135 "cd ~/kiotviet && docker compose restart"

# Health check
curl http://52.163.118.135:8010/health
```

### Endpoints
- Health: `http://52.163.118.135:8010/health`
- API Docs: `http://52.163.118.135:8010/docs`
- ReDoc: `http://52.163.118.135:8010/redoc`

---

## 3. fina-ai-agent

**Path**: `/Users/trunghuynh/development/finizi-dev/fina-ai-agent/`

### Stack
- AI agent framework

### Purpose
AI-powered financial assistant and automation.

### Status
Development phase.

---

## Project Dependencies

```
devops (this workspace)
    |
    +-- manages --> b4b-api (main API)
    |                  |
    |                  +-- uses --> finizi_kiotviet_client (integration)
    |                  |
    |                  +-- uses --> fina-ai-agent (AI features)
    |
    +-- infrastructure --> Azure VMs, PostgreSQL, Key Vault
```

## Shared Infrastructure

All projects use:
- **Azure PostgreSQL**: `b4b-staging-db.postgres.database.azure.com`
- **Azure Key Vault**: `kv-finizi-staging-2026` / `kv-finizi-prod-2026`
- **GCloud Service Account**: `b4b-finizi-app@finiziapp.iam.gserviceaccount.com`
