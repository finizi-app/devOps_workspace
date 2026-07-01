# Báo Cáo Triển Khai Odoo (Patedeli BMP) — DO Droplet

**Date**: 2026-07-01
**Server**: DigitalOcean droplet `odoo-erp-multi-company` (ID 518827273)
**IP**: 146.190.104.85 (Singapore sgp1)
**OS**: Ubuntu 22.04 (kernel 5.19.0-46-generic)
**Uptime**: 80+ ngày (reboot 2026-04-11)

---

## 1. Kiến trúc triển khai

```
Internet
   ↓
Cloud Firewall (DO) — TCP 22, 80, 443, 2222 từ 0.0.0.0/0
   ↓
Droplet 146.190.104.85
   ├─ sshd :22 (fallback) + :2222 (primary)
   ├─ nginx :80 + :443 → reverse proxy
   │   ├─ bmp vhost (erp.patedeli.com, erp2.patedeli.com) → Odoo :8069
   │   ├─ 000-default-reject catch-all (TLS reject, since 2026-06-28)
   │   └─ ❌ analytics.patedeli.com (disabled, was Metabase)
   │   └─ ❌ workflow.patedeli.com, flow.finizi.{ai,app} (disabled, was n8n)
   └─ bmp-web-1 (Docker container, network_mode: host)
       ├─ Odoo 16.0 + Python 3.7 + custom modules
       ├─ Listen :8069 (HTTP) + :8072 (longpolling)
       ├─ Worker: 1 master + 4 HTTP + 1 gevent
       ├─ DB: managed Postgres cluster bmp-postgres-cluster-do-user-25362799-0.g.db.ondigitalocean.com:25060
       └─ Volumes:
           ├─ odoo-web-data:/var/lib/odoo (named volume)
           ├─ ./config:/etc/odoo (bind mount)
           └─ ./base, ./tools, ./inventory, ./accounting, ./purchase, ./sale, ./api, ./mrp, ./pos
```

### Components

| Component | Version | Source |
|-----------|---------|--------|
| Ubuntu OS | 22.04 (kernel 5.19.0-46-generic) | DO image |
| Docker | latest (DO default) | apt |
| nginx | 1.22.0 | apt |
| Odoo | 16.0-20230416 | `dockers.reach.com.vn/odoo/16e:latest` base |
| Python | 3.7 (in Odoo venv) | base image |
| Postgres | managed (DO) | DO managed cluster |
| sshd | OpenSSH | apt |

---

## 2. Source code & build

### Git repo
- **Remote**: `https://gitlab.reach.com.vn/thanh/bmp.git` (private GitLab)
- **Branch (deployed)**: `production`
- **Last commit**: `a2befb7 update`
- **Clone location**: `/opt/bmp/` on droplet

### Source structure
```
/opt/bmp/
├── Dockerfile                    # FROM dockers.reach.com.vn/odoo/16e:latest
├── docker-compose.yml            # current config (host network mode)
├── docker-compose-{cloud,inte,local,prd}.yml
├── docker-compose.yml.bak*       # 3 backups
├── entrypoint.sh                 # cron + odoo via env vars
├── requirements.txt              # pandas, openai, paramiko, etc.
├── .gitlab-ci.yml                # deploy_production job
├── auto_create_merge_request.sh  # CI helper
├── README.md
├── .git/                         # production branch (working tree dirty)
├── config/
│   ├── odoo.conf                 # main config (db, paths)
│   ├── odoo-prod.conf
│   ├── odoo-dev.conf
│   └── odoo.conf.backup
└── 9× custom Odoo modules: base, tools, inventory, accounting,
    purchase, sale, api, mrp, pos
```

### Docker image
- **Image name**: `bmp:latest` (locally built, 6.7 GB)
- **Built**: 2023-04-26 (3 năm trước)
- **Source**: Built from `dockers.reach.com.vn/odoo/16e:latest` + custom modules
- **Refresh**: Manual only (no image rebuild in CI/CD pipeline)

---

## 3. Deploy flow

### CI/CD (`.gitlab-ci.yml`)
Triggered bởi CI/CD variable `$DEPLOY_PRODUCTION`:

```bash
ssh -tt -o StrictHostKeyChecking=no $SSH_PROD "
  cd /opt/bmp
  sudo git pull --no-edit https://oauth2:${project_access_token}@gitlab.reach.com.vn/thanh/bmp.git production
  sudo docker exec bmp-web-1 /opt/odoo/odoo-venv/bin/click-odoo-update \
       -c /etc/odoo/odoo-prod.conf -d patedeli --ignore-core-addons
  sudo docker restart bmp-web-1
"
```

### Manual deploy (current method)
```bash
ssh -p 2222 -i ~/.ssh/patedeli-digitalocean deploy@146.190.104.85
cd /opt/bmp
sudo git pull --no-edit https://oauth2:${project_access_token}@gitlab.reach.com.vn/thanh/bmp.git production
sudo docker exec bmp-web-1 /opt/odoo/odoo-venv/bin/click-odoo-update -c /etc/odoo/odoo-prod.conf -d patedeli --ignore-core-addons
sudo docker restart bmp-web-1
```

### Image rebuild (only when needed)
```bash
# Trên build machine có Docker + access to reach.com.vn registry
git clone https://gitlab.reach.com.vn/thanh/bmp.git
cd bmp
docker build -t bmp:latest .
docker save bmp:latest | gzip > bmp-image.tar.gz

# Trên droplet
scp bmp-image.tar.gz deploy@droplet:/tmp/
ssh -p 2222 -i ~/.ssh/patedeli-digitalocean deploy@droplet "
  docker load < /tmp/bmp-image.tar.gz
  cd /opt/bmp && docker compose down && docker compose up -d
"
```

---

## 4. Configuration

### `/opt/bmp/docker-compose.yml` (current)
```yaml
version: "2"
services:
  web:
    image: bmp:latest
    network_mode: host          # since 2026-06-28, bypasses DO hypervisor block
#     ports:                    # disabled (host network doesn't need mapping)
#       - "8069:8069"
#       - "8072:8072"
    volumes:
      - odoo-web-data:/var/lib/odoo
      - ./config:/etc/odoo
      - ./base:/opt/odoo/bmp/base
      - ./tools:/opt/odoo/bmp/tools
      - ./inventory:/opt/odoo/bmp/inventory
      - ./accounting:/opt/odoo/bmp/accounting
      - ./purchase:/opt/odoo/bmp/purchase
      - ./sale:/opt/odoo/bmp/sale
      - ./api:/opt/odoo/bmp/api
      - ./mrp:/opt/odoo/bmp/mrp
      - ./pos:/opt/odoo/bmp/pos
volumes:
  odoo-web-data:
```

### `/opt/bmp/config/odoo.conf` (key fields)
```ini
db_user = doadmin
db_password = <redacted - in 1Password or /opt/bmp/config/odoo.conf on server>  # ⚠️ plain text
db_port = 25060
db_host = bmp-postgres-cluster-do-user-25362799-0.g.db.ondigitalocean.com
db_name = patedeli
db_sslmode = require
dbfilter = ^patedeli$
list_db = False
```

### Nginx `/etc/nginx/sites-enabled/bmp`
```nginx
upstream odoo-bmp { server 0.0.0.0:8069 weight=1 fail_timeout=0; }
upstream odoo-chat-bmp { server 0.0.0.0:8072 weight=1 fail_timeout=0; }
server {
    server_name erp.patedeli.com erp2.patedeli.com;
    client_max_body_size 2000m;
    # WebSocket upgrade + proxy to odoo-bmp
    location / { proxy_pass http://odoo-bmp; ... }
    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/erp.patedeli.com/fullchain.pem;
    ...
}
```

### Nginx `/etc/nginx/sites-enabled/000-default-reject` (since 2026-06-28)
```nginx
server {
    listen 80 default_server;
    listen 443 ssl default_server;
    server_name _;
    ssl_reject_handshake on;
    return 444;
}
```

---

## 5. Backup & recovery

### Backups on droplet
| File | Size | Notes |
|------|------|-------|
| `/opt/bmp/docker-compose.yml.bak-260607` | 966 | pre-n8n disable backup |
| `/opt/bmp/docker-compose.yml.bak.20260628-0901` | 537 | pre-host-network backup |
| `/opt/bmp/docker-compose.yml.bak.20260628-054617` | 537 | pre-n8n edit backup |
| `/opt/bmp_patedeli_backup.sql` | 2.4 GB | DB dump |
| `/opt/bmp_patedeli_clean_backup.sql` | 2.4 GB | clean DB dump |
| `/opt/bmp_database_backup.sql` | 541 B | metadata only |
| `/opt/bmp/patedeli_full_backup_20250930_*.sql` | 2.4 GB | Sep 30 2025 DB dump |

### Recovery toolkit (installed)
- `/root/ssh-recover` — primary (Recovery Console friendly)
- `/usr/local/sbin/ssh-recover` — in $PATH
- `/usr/local/share/ssh-recover/authorized_keys` — baseline keys (1 key: patedeli-digitalocean ed25519)
- Source: `scripts/ssh-recover-toolkit.sh` in repo

### Recovery scenarios

**1. SSH key lost/forgotten**
```bash
# Via DO Recovery Console
sudo /root/ssh-recover          # prompts for each step
# or non-interactive:
sudo /root/ssh-recover --yes
```

**2. sshd broken config**
```bash
# /root/ssh-recover step 2 resets sshd_config baseline
sudo /root/ssh-recover --yes
```

**3. Miner eating CPU**
```bash
# /root/ssh-recover step 3 kills high-CPU deploy processes
sudo /root/ssh-recover --yes
```

**4. Odoo not connecting DB**
- Already fixed via `network_mode: host`
- If regresses: check docker-compose.yml, recreate container

**5. cert expired** (erp2.patedeli.com currently expired)
```bash
sudo certbot renew --cert-name erp2.patedeli.com --force-renewal --dry-run  # test
sudo certbot renew --cert-name erp2.patedeli.com --force-renewal                # apply
```

---

## 6. Trạng thái hiện tại

| Service | Status | Notes |
|---------|--------|-------|
| sshd | ✅ active | :22 + :2222, key-only |
| nginx | ✅ active | :80 + :443, host network |
| bmp-web-1 | ✅ Up 2 weeks | Odoo 16.0, network_mode: host |
| Postgres managed | ✅ reachable | DO cluster (now via host network) |
| Cert `erp.patedeli.com` | ✅ valid (43d) | |
| Cert `erp2.patedeli.com` | ⚠️ EXPIRED (Feb 28) | certbot renewal failing |
| Cert `analytics.patedeli.com` | ❌ deleted | was Metabase entry point |
| Cert `workflow.patedeli.com` | ❌ deleted | was n8n |
| cron daemon | ✅ active | no malicious crontabs |
| docker | ✅ active | 1 container (bmp-web-1) |
| Disk | 52% used | 78G total, 40G used |
| Memory | 6.1G available / 7.8G total | normal |
| Load | 0.02 | idle |

### Listening ports
| Port | Service |
|------|---------|
| 22 | sshd (fallback) |
| 80 | nginx (HTTP) |
| 2222 | sshd (primary) |
| 443 | nginx (HTTPS) |
| 8069 | Odoo (Docker, host network) |
| 8072 | Odoo longpolling (Docker, host network) |

---

## 7. Tài liệu liên quan

- `docs/infrastructure-digitalocean.md` — infrastructure overview
- `docs/journals/2026-06-28-crypto-miner-reinfection-3.md` — incident #3
- `docs/journals/2026-06-28-erp-down-do-outbound-block.md` — DO block fix
- `docs/journals/2026-07-01-crypto-miner-reinfection-4.md` — incident #4 + stolen key
- `docs/journals/2026-07-01-bmp-redeploy-research.md` — repo research + redeploy options
- `docs/reports/incident-response-260701-2325-crypto-miner-cleanup.md` — full incident report
- `scripts/ssh-recover-toolkit.sh` — recovery script source

---

## 8. Tóm tắt

**Odoo Patedeli** đang chạy ổn định trên DO droplet, được triển khai qua GitLab CI/CD với sshpass-based deploy. Container `bmp-web-1` chạy Odoo 16.0 từ base image 3 năm tuổi, kết nối managed Postgres cluster. Frontend qua nginx reverse proxy với 2 domain `erp.patedeli.com` (valid) + `erp2.patedeli.com` (cert expired). Recovery toolkit `ssh-recover` đã deployed sẵn để xử lý sự cố SSH/firewall/miner trong tương lai.

**Risks chính**:
- Image 3 năm tuổi (Python 3.7 EOL) — chưa rebuild
- 2.4GB DB dumps trên droplet — chưa off-host
- `erp2.patedeli.com` cert expired
- Plain password trong `config/odoo.conf`
- `mdrfckr` RSA key có thể còn trong operator's local backups (auditor cần check)
- DB password trong `config/odoo.conf` plain text — should move to env var