# Infrastructure

Azure and GCloud infrastructure details for Finizi deployments.

- **DigitalOcean** → [infrastructure-digitalocean.md](infrastructure-digitalocean.md)

---

## Azure Resources

### Subscription
- **Name**: Microsoft Azure Sponsorship
- **Resource Group**: `fina-ops`

---

## Production VM

| Property | Value |
|----------|-------|
| Name | vm-finizi-prod |
| Size | Standard_B4ms (4 vCPU, 16 GB) |
| Location | Southeast Asia |
| Public IP | `20.212.32.64` |
| Private IP | `10.0.0.6` |
| SSH User | `azureuser` |
| SSH Port | 22 |

### Open Ports
| Port | Service |
|------|---------|
| 22 | SSH |
| 80 | HTTP (nginx) |
| 443 | HTTPS (nginx) |
| 8001 | Backend (internal) |
| 3001 | Frontend (internal) |

### SSH Access
```bash
ssh azureuser@20.212.32.64
```

### Services Running (Docker)
| Service | Container | Port |
|---------|-----------|------|
| Backend API | b4b_prod_app | 8001 |
| Frontend | b4b_prod_frontend | 3001 |
| Redis | b4b_prod_redis | 6379 |
| Celery Worker | b4b_prod_worker | - |
| Celery Webhook | b4b_prod_webhook | - |
| Celery Beat | b4b_prod_beat | - |

### App Directory
```
/mnt/b4b-api/
├── docker-compose.production.yml
├── .env.production
├── nginx.production.conf
├── nginx.production-http.conf
├── credentials/
│   ├── service-account-key.json
│   └── finizi-ai-firebase-adminsdk-fbsvc-902fa2caea.json
└── data/
    └── tmp_data/
```

---

## Staging VM

| Property | Value |
|----------|-------|
| Name | finizi_dev |
| Public IP | `52.163.118.135` |
| Private IP | `10.0.0.4` |
| User | `azureuser` |
| OS | Ubuntu 22.04 LTS |
| Domain | admin.dev.finizi.ai |

### Open Ports
| Port | Service |
|------|---------|
| 22 | SSH |
| 80 | HTTP (nginx) |
| 8101 | Backend (internal) |
| 3101 | Frontend (internal) |

### SSH Access
```bash
ssh azureuser@52.163.118.135
```

### Services Running (Docker)
| Service | Container | Port |
|---------|-----------|------|
| Backend API | b4b_staging_app | 8101 |
| Frontend | b4b_staging_frontend | 3101 |
| Redis | b4b_staging_redis | 6379 (host) |
| Celery Worker | b4b_staging_worker | - |
| Celery Webhook | b4b_staging_queue_webhook | - |
| Celery Beat | b4b_staging_queue_beat | - |

### Notes
- Redis runs as host service (not Docker) on port 6379
- Using HTTP only (no SSL) - nginx HTTP fallback config
- Container restart policy: `unless-stopped`

---

## KiotViet Integration VM

| Property | Value |
|----------|-------|
| Name | finizi_dev |
| IP | `52.163.118.135` |
| User | `azureuser` |
| OS | Ubuntu 22.04 LTS |
| App Dir | `/home/azureuser/kiotviet` |

### Open Ports
| Port | Service |
|------|---------|
| 22 | SSH |
| 80 | HTTP (nginx) |
| 8010 | API (nginx proxy) |
| 8000 | Container (internal) |

### SSH Access
```bash
ssh azureuser@52.163.118.135
```

### Services Running (Docker)
| Service | Container | Port |
|---------|-----------|------|
| KiotViet API | kiotviet-api | 8000 |

### Nginx Config
- Rate limiting: 10 req/s (burst 20)
- Proxy: 8010 → 8000
- Logs: `/var/log/nginx/kiotviet-8010-*.log`

---

## Azure PostgreSQL

| Property | Value |
|----------|-------|
| Server | `b4b-staging-db.postgres.database.azure.com` |
| Location | Southeast Asia |
| Version | PostgreSQL 15 |
| Extensions | `vector` (pgvector) |

### Databases
| Database | Purpose |
|----------|---------|
| `finizi_b4b` | Staging/Development |
| `finizi_b4b_production` | Production |

### Connection
```bash
psql -h b4b-staging-db.postgres.database.azure.com \
     -U <username> \
     -d finizi_b4b_production
```

### Data Volume (Production)
| Table | Records |
|-------|---------|
| users | 34 |
| entities | 80 |
| vendors | 5,713 |
| products | 5,156 |
| documents | 74,213 |
| invoices | 151,493 |
| invoice_line_items | 161,385 |
| webhooks | 644,172 |
| **Total Tables** | **126** |

---

## Azure Key Vault

### Staging
| Property | Value |
|----------|-------|
| Name | `kv-finizi-staging-2026` |
| Resource Group | `fina-ops` |
| Secrets | ~67 (excludes *-PRODUCTION) |

### Production
| Property | Value |
|----------|-------|
| Name | `kv-finizi-prod-2026` |
| Resource Group | `fina-ops` |
| Secrets | ~67 |

### Key Secrets
- `DATABASE-URL` / `DATABASE-URL-PRODUCTION`
- `GCS-CREDENTIALS-BASE64`
- `FIREBASE-CREDENTIALS-BASE64`
- `OPENAI-API-KEY`
- `GOOGLE-API-KEY`

### Access
- GitHub Actions OIDC (Key Vault Secrets User role)
- Azure AD groups for user access

---

## Google Cloud

### Service Account
| Property | Value |
|----------|-------|
| Email | `b4b-finizi-app@finiziapp.iam.gserviceaccount.com` |
| Project | `finiziapp` |

### Services Used
- Google Cloud Storage (file uploads)
- Firebase (authentication)
- Google Generative AI (Gemini)

### Credentials
Stored in Key Vault as base64:
- `GCS-CREDENTIALS-BASE64`
- `FIREBASE-CREDENTIALS-BASE64`

### IAM Security (2026-03-07)
**Issue:** `firebase-adminsdk-fbsvc` had project-level `roles/iam.serviceAccountTokenCreator` - could impersonate any SA including owner-level SAs.

**Fix:** Added condition to limit TokenCreator to only `b4b-finizi-app` SA:
```
condition: resource.name.endsWith('b4b-finizi-app')
```

---

## Network Security

### NSG Rules (Production VM)
- SSH (22): Restricted to admin IPs
- HTTP (80): Open
- HTTPS (443): Open
- Internal ports (8001, 3001): VM-only

### Database Firewall
- Production VM IP (`20.212.32.64`) allowed

---

## DNS Configuration

| Domain | Type | Target | Environment |
|--------|------|--------|-------------|
| admin.prod.finizi.ai | A | `20.212.32.64` | Production |
| admin.dev.finizi.ai | A | `52.163.118.135` | Staging |

---

## SSL Certificates

Managed via Let's Encrypt certbot on VM.

### Certificate Path
```
/etc/letsencrypt/live/admin.prod.finizi.ai/
├── fullchain.pem
├── privkey.pem
└── cert.pem
```

### Renewal
Auto-renewal via certbot systemd timer.
