# Azure VM Staging Disk Cleanup - 2026-03-07

## Summary
Azure VM `finizi_dev` (52.163.118.135) had disk space issues causing Docker build failures. Resolved by:
1. Full Docker reinstall with data-root on larger partition (docker2)
2. GitHub workflow deployment of b4b staging + kiotviet-api production

## Problem
- Root partition (`/dev/root` 29GB) at 99% - "No space left on device" during frontend build
- Docker data-root was on small root partition
- Orphaned containerd snapshots in `/var/lib/docker2` (31GB)
- Corrupted container metadata causing "No such container" errors

## Resolution

### 1. Docker Reinstall
```bash
# Stop services
sudo systemctl stop docker docker.socket containerd

# Purge Docker
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker /var/lib/docker2 /var/lib/containerd /etc/docker /etc/containerd

# Reinstall
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure data-root on 50GB partition
sudo mkdir -p /etc/docker /var/lib/docker2
echo '{"data-root": "/var/lib/docker2"}' | sudo tee /etc/docker/daemon.json
sudo systemctl start docker
```

### 2. GitHub Workflow Deployments
- **b4b staging**: Triggered `deploy-staging-azure.yml` → workflow #342
- **kiotviet-api production**: Merged develop → production, pushed to trigger deploy

### 3. Manual Fixes
- Removed duplicate nginx config: `/etc/nginx/sites-available/kiotviet-8010`
- Created `.env` file with Key Vault secrets
- Built and started kiotviet-api container

### 4. Disk Cleanup
Freed ~8.5GB by pruning Docker build cache:
```bash
docker builder prune -af
docker image prune -af
```

## Disk Space After
| Partition | Size | Used | Free | Use% |
|-----------|------|------|------|------|
| `/` (root) | 29G | 20G | 9.9G | 66% |
| `/var/lib/docker2` | 49G | 6.8M | 47G | 1% |

## Containers Running
| Service | Container | Port | Status |
|---------|-----------|------|--------|
| Kiotviet API | kiotviet-api:prod | 8001 | healthy |
| B4B Backend | b4b_staging_app | 8101 | healthy |
| B4B Frontend | b4b_staging_frontend | 3101 | running |
| B4B Celery Worker | b4b_staging_queue_worker | - | running |
| B4B Celery Beat | b4b_staging_queue_beat | - | running |
| B4B Webhook | b4b_staging_queue_webhook_worker | - | running |
| B4B Dynamic Entity | b4b_staging_dynamic_entity_worker | - | healthy |

## Endpoints
- **Kiotviet API**: http://52.163.118.135:8010/health
- **B4B Backend**: http://52.163.118.135:8101/health
- **B4B Frontend**: http://52.163.118.135:3101/

## Notes
- Old containerd data at `/var/lib/containerd` (12GB) still exists on root - can be cleaned later
- GitHub workflow for kiotviet failed initially due to duplicate nginx config - resolved manually
- Azure Key Vault `kv-finizi-staging-2026` used for secrets
