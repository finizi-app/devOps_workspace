# BMP (Odoo Patedeli) — Research & Redploy Plan — 2026-07-01

## Source Code Layout (on droplet `/opt/bmp/`)

```
/opt/bmp/
├── Dockerfile                        # FROM dockers.reach.com.vn/odoo/16e:latest
├── docker-compose.yml                # current (host network mode)
├── docker-compose-{cloud,inte,local,prd}.yml  # 4 variants
├── docker-compose.yml.bak*           # backups (3)
├── entrypoint.sh                     # starts cron + odoo based on env vars
├── requirements.txt                  # pandas, openai, paramiko, etc.
├── .gitlab-ci.yml                    # deploy_production stage
├── auto_create_merge_request.sh      # CI helper
├── README.md                         # GitLab default template
├── .git/                             # production branch
└── {base,tools,inventory,accounting,purchase,sale,api,mrp,pos}/   # Odoo custom modules
```

## Git Repository

| Property | Value |
|----------|-------|
| Remote | `https://gitlab.reach.com.vn/thanh/bmp.git` (private GitLab) |
| Branch (deployed) | `production` |
| Last commit | `a2befb7 update` |
| Odoo custom modules | 9 dirs (base, tools, inventory, accounting, purchase, sale, api, mrp, pos) |
| Working tree | ⚠️ dirty — `config/odoo-prod.conf`, `config/odoo.conf`, `docker-compose-prd.yml`, `docker-compose.yml` modified; 4 untracked backup files |

## Base Image

```
FROM dockers.reach.com.vn/odoo/16e:latest
```
- Private registry `dockers.reach.com.vn` (Reach Vietnam)
- **Image age: 3 years** (built 2023-04-26)
- Image size: 6.7 GB
- Contains Odoo 16.0 (released 2022, supported until 2027) + Python 3.7 venv
- Custom modules layer: 32 MB
- ⚠️ **3-year-old base = likely many unpatched CVEs** in Odoo core + Python 3.7 (EOL June 2023) + Debian/Ubuntu base

## Deploy Flow (current CI/CD)

`.gitlab-ci.yml` → `deploy_production` job:

```bash
ssh -tt -o StrictHostKeyChecking=no $SSH_PROD "
  cd /opt/bmp
  sudo git pull --no-edit https://oauth2:${project_access_token}@gitlab.reach.com.vn/thanh/bmp.git production
  sudo docker exec bmp-web-1 /opt/odoo/odoo-venv/bin/click-odoo-update \
       -c /etc/odoo/odoo-prod.conf -d patedeli --ignore-core-addons
  sudo docker restart bmp-web-1
"
```

Triggered by `DEPLOY_PRODUCTION` CI/CD variable.

## On-server backups (current)

| File | Size | Notes |
|------|------|-------|
| `/opt/bmp/docker-compose.yml` (current) | 566 | has host network mode (my fix) |
| `/opt/bmp/docker-compose.yml.bak-260607` | 966 | backup from 2026-06-07 |
| `/opt/bmp/docker-compose.yml.bak.20260628-0901` | 537 | pre-host-network backup |
| `/opt/bmp/docker-compose-{cloud,inte,local,prd}.yml` | 165-864 | deployment variants |
| `/opt/bmp/patedeli_full_backup_20250930_*.sql` | 2.4 GB | Odoo DB dump Sep 30 2025 |
| `/opt/bmp_patedeli_backup.sql` | 2.4 GB | older backup |
| `/opt/bmp_patedeli_clean_backup.sql` | 2.4 GB | clean backup |
| `/opt/metabase_*.db_backup.tar.gz` | 7 MB | Metabase DB backup |

## Security Issues Found

| # | Issue | Severity |
|---|-------|----------|
| 1 | **`SSHPASS_PROD` plaintext** in GitLab CI/CD env var | high — anyone with CI access can SSH as prod user |
| 2 | **`oauth2:${project_access_token}` in git URL** — token stored in clear in CI | medium |
| 3 | **3-year-old base image** (Odoo 16.0 + Python 3.7 EOL) | high — likely dozens of CVEs |
| 4 | **Plain DB password in `config/odoo.conf`** (`db_password = AVNS_...`) | medium — readable by anyone with shell |
| 5 | **sshpass** in deploy script — password in env | medium |
| 6 | **`apt-get update && apt-get install -y cron`** in Dockerfile — runs as root, no version pinning | low |
| 7 | **No version pinning** for `bmp:latest` — always pulls latest on rebuild | medium |
| 8 | **docker-compose variants** (`*-cloud.yml`, `*-prd.yml`) — unclear which is canonical | low |
| 9 | **Image is 3y old, container runtime is current** — possible Odoo incompatibility | low |
| 10 | **Dirty git working tree** — modifications not committed | low |

## Redploy Options

### Option A: Patch-in-place (fastest, lowest risk)
**What**: Keep current droplet, container, image. Just `git pull` + `docker restart` like CI does.
**Pros**: Zero downtime, no data migration, leverages existing CI
**Cons**: Doesn't address CVEs in base image, image still 3y old
**Time**: ~10 min
**Use when**: Need quick redeploy with custom module changes only

```bash
cd /opt/bmp
sudo git pull --no-edit https://oauth2:${project_access_token}@gitlab.reach.com.vn/thanh/bmp.git production
sudo docker restart bmp-web-1
```

### Option B: Rebuild image from source + redeploy (recommended)
**What**: Rebuild `bmp:latest` with current code, push to droplet, redeploy
**Pros**: Updated base image possible (if registry available), reproducible
**Cons**: Needs Docker on build machine, requires access to `dockers.reach.com.vn/odoo/16e:latest`
**Time**: ~1-2 hours
**Use when**: Want to update base image or rebuild cleanly

```bash
# On a build machine with Docker + access to reach.com.vn registry
git clone https://gitlab.reach.com.vn/thanh/bmp.git
cd bmp
docker build -t bmp:latest .
docker save bmp:latest | gzip > bmp-image.tar.gz

# On droplet
scp bmp-image.tar.gz deploy@droplet:/tmp/
ssh deploy@droplet "
  docker load < /tmp/bmp-image.tar.gz
  cd /opt/bmp && docker compose down && docker compose up -d
"
```

### Option C: Full rebuild from clean base
**What**: Destroy droplet, recreate from snapshot + apply security hardening from scratch
**Pros**: Clean slate, all hardening applied, modern image
**Cons**: Longest downtime (1-2h), risk of config drift
**Time**: ~2-4 hours
**Use when**: After security audit shows fundamental image issues, or moving to new image base

## Recommended Path

**Option B** — but with caveats:
1. **First**: snapshot current droplet (via doctl) before any rebuild
2. **Second**: rebuild image locally with security patches (if registry access available)
3. **Third**: test rebuild on local Docker first
4. **Fourth**: deploy to droplet with brief downtime (~5 min)
5. **Fifth**: verify Odoo recovers + Postgres connection + web UI

## Open Questions for Operator

1. **Do you have access to `dockers.reach.com.vn`** (private registry)? Need to pull `odoo/16e:latest`
2. **Is there a CI runner available** to build the image? Or local Docker?
3. **Should we add image rebuild to CI/CD**? Currently only `git pull` is in pipeline — image is built once and never refreshed
4. **Do you want to move away from `dockers.reach.com.vn/odoo/16e`** to official `odoo:16.0`? Pros: maintained by Odoo SA; Cons: may break custom modules
5. **Database backup strategy** — current backups are 2.4 GB SQL dumps in `/opt/`. Should be moved off-droplet (DO Spaces) and rotated