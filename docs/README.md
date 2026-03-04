# DevOps Operations Center

Working directory for DevOps agentic operations managing infrastructure and deployments for Finizi projects.

## Purpose

This workspace manages:
- Azure VM infrastructure (staging/production)
- CI/CD pipelines via GitHub Actions
- Database operations (PostgreSQL)
- SSL/DNS configuration
- Monitoring and maintenance

## Target Projects

| Project | Path | Description |
|---------|------|-------------|
| b4b-api | `/Users/trunghuynh/development/b4b-api/` | Main API - Node.js/TypeScript + FastAPI |
| finizi_kiotviet_client | `/Users/trunghuynh/development/finizi-dev/finizi_kiotviet_client/` | KiotViet integration (Python/FastAPI) |
| fina-ai-agent | `/Users/trunghuynh/development/finizi-dev/fina-ai-agent/` | AI agent project |

## Quick Links

- [Target Projects](./target-projects.md) - Projects managed by this workspace
- [Infrastructure](./infrastructure.md) - Azure VM, PostgreSQL, GCloud details
- [Deployment Guide](./deployment-guide.md) - CI/CD procedures and workflows

## Environment URLs

### Production
- Frontend: https://admin.prod.finizi.ai/
- Backend: https://admin.prod.finizi.ai/backend/
- Health: https://admin.prod.finizi.ai/backend/health

### Staging
- Frontend: https://admin.dev.finizi.ai/
- Backend: https://admin.dev.finizi.ai/backend/
- Health: https://admin.dev.finizi.ai/backend/health

## Key Files

| File | Purpose |
|------|---------|
| `plans/` | Implementation plans and reports |
| `docs/` | DevOps documentation |
| `.claude/` | Agent skills and rules |

## Common Operations

### SSH to Production VM
```bash
ssh azureuser@20.212.32.64
```

### Check Service Status
```bash
# On VM
docker compose -f /mnt/b4b-api/docker-compose.production.yml ps
```

### View Logs
```bash
# On VM
docker compose -f /mnt/b4b-api/docker-compose.production.yml logs -f app
```

### Trigger Deployment
- Push to `master` branch triggers production deployment
- Push to `develop` branch triggers staging deployment

## Secrets Management

- **Staging Key Vault**: `kv-finizi-staging-2026`
- **Production Key Vault**: `kv-finizi-prod-2026`
- **Location**: Azure `fina-ops` resource group

## Monitoring

### Journal Monitor
Check for new devops tasks in b4b deployment journal:
```bash
./scripts/check-deployment-journal.sh
```

### Cron Setup (Optional)
```bash
# Every 30 minutes
*/30 * * * * /Users/trunghuynh/development/finizi-dev/devops/scripts/check-deployment-journal.sh
```

## Contact & Resources

- **GitHub**: https://github.com/finizi-app/b4b-api
- **Deployment Journal**: `/Users/trunghuynh/development/b4b-api/docs/journals/deployment-azure-production.md`
