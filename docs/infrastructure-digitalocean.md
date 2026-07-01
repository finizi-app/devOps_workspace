# DigitalOcean Infrastructure

Patedeli Odoo ERP server on DigitalOcean.

---

## Droplet

| Property | Value |
|----------|-------|
| Name | `odoo-erp-multi-company` |
| ID | `518827273` |
| Region | `sgp1` (Singapore) |
| IP | `146.190.104.85` |
| OS | Ubuntu |
| Disk | 78G (50G used, 65%) |
| RAM | 7.8 GB |
| Internal IP | `10.15.0.5` (eth0), `10.104.0.2` (eth1) |

### SSH Access

| Property | Value |
|----------|-------|
| Port | `2222` (primary), `22` (fallback) |
| User | `deploy` (sudo, NOPASSWD) |
| Auth | **password + key** (both enabled since 2026-06-28) |
| Primary key | `~/.ssh/patedeli-digitalocean` (ed25519, generated 2026-06-28, fingerprint `5+YH/71U8mGF7XFBmQW/Yf4K3/zegA3Vh24H4rOehk8`) |
| ~~Legacy key~~ | ~~`ssh-rsa mdrfckr`~~ **REMOVED 2026-07-01** — confirmed compromised, attacker used it from `136.243.92.210` (DE). Operator must delete the matching private key from `~/.ssh/`, password manager, and any CI/CD configs. |
| Root password | rotated 2026-06-28 (was `Kafe@20188`) |
| Deploy password | rotated 2026-06-28 (was `Deploy2026!`) — see 1Password "Patedeli DO Infra" |

```bash
# Recommended (key)
ssh -p 2222 -i ~/.ssh/patedeli-digitalocean deploy@146.190.104.85

# Password (fallback — get from 1Password)
sshpass -p '<from 1Password>' ssh -p 2222 -o PubkeyAuthentication=no deploy@146.190.104.85

# Or via ~/.ssh/config alias
#   Host patedeli-do
#     HostName 146.190.104.85
#     Port 2222
#     User deploy
#     IdentityFile ~/.ssh/patedeli-digitalocean
#     IdentitiesOnly yes
# Then: ssh patedeli-do
```

---

## Cloud Firewall

| Property | Value |
|----------|-------|
| ID | `2fb2e4d7-7742-4d4f-8925-9f0c739e96b8` |
| Name | `odoo` |

### Inbound Rules

| Protocol | Ports | Source |
|----------|-------|--------|
| ICMP | all | `0.0.0.0/0` |
| TCP | 22 | `0.0.0.0/0` |
| TCP | 80 | `0.0.0.0/0` |
| TCP | 443 | `0.0.0.0/0` |
| TCP | 2222 | `0.0.0.0/0` |

### Outbound Rules

| Protocol | Ports | Destination |
|----------|-------|-------------|
| ICMP | all | `0.0.0.0/0` |
| TCP | 1-65535 | `0.0.0.0/0` |
| UDP | 1-65535 | `0.0.0.0/0` |

---

## Services

### Docker Containers

| Container | Status | Ports | Network |
|-----------|--------|-------|---------|
| `bmp-web-1` | Running | 8069, 8072 | **`host`** (since 2026-06-28 — see `journals/2026-06-28-erp-down-do-outbound-block.md`) |

### Non-Docker Services

| Service | Details |
|---------|---------|
| Odoo | 5 worker processes, ~1.3GB RAM total |
| nginx | Reverse proxy (ports 80/443 → 8069) |
| SSH | ports 22 + 2222 |
| fail2ban | **DISABLED 2026-06-07** (was locking out the operator; soft plan: re-enable with per-IP whitelist) |

### Listening Ports

| Port | Service |
|------|---------|
| 22 | sshd |
| 80 | nginx (HTTP) |
| 443 | nginx (HTTPS) |
| 2222 | sshd |
| 8069 | Odoo (via Docker) |
| 8072 | Odoo longpolling (via Docker) |

### Odoo Configuration

| Property | Value |
|----------|-------|
| Binary | `/opt/odoo/odoo-venv/bin/python3 /opt/odoo/odoo-server/odoo-bin` |
| Config | `/etc/odoo/odoo.conf` |
| Workers | 5 (4 HTTP + 1 gevent) |

---

## Security

### Incident History

| Date | Event | Resolution |
|------|-------|------------|
| 2026-03-01 | SSH brute force → root compromised → kinsing/kswpad crypto miner | Cleaned 2026-03-06 |
| 2026-04-11 | Outbound TCP broken, SSH key lost | Fixed SSH key, nft flush |
| 2026-04-12 | DO blocked outbound — droplet in DDoS (168.4 Mbps to 103.36.167.70) | Removed `/tmp/.3ef779fef5ff2e9e-00000000.so` malware, kswpad service. DO ticket pending block lift |
| 2026-06-13 | Metabase RCE (CVE-2021-41277) → root → deploy session → XMRig-style miner (525 threads) via `kthreadadd`/`edac0` | Cleaned 2026-06-28 (see `journals/2026-06-28-crypto-miner-reinfection-3.md`) |
| 2026-06-28 ~06:00 | DO hypervisor outbound block on Docker bridge IPs (172.18.0.0/16) — Odoo workers can't reach managed Postgres `bmp-postgres-cluster-...ondigitalocean.com:25060`; `erp.patedeli.com` returns 504 | Switched `bmp-web-1` to `network_mode: host` in `/opt/bmp/docker-compose.yml` (see `journals/2026-06-28-erp-down-do-outbound-block.md`) |
| 2026-06-29 07:56 | Re-infection #4 via stolen RSA key `mdrfckr` (fingerprint `MkYY9qiVsFGBC5WkjoClCkwEFW5iSjcGQF7m4n4H7Cw`) from `136.243.92.210` (DE). Re-deployed miner with new toolchain (`.X212-unix`) + cron | Killed miner, removed `mdrfckr` from `authorized_keys` (see `journals/2026-07-01-crypto-miner-reinfection-4.md`). **CRITICAL**: operator must also delete the private `mdrfckr` key from local `~/.ssh/` and any password manager. |

### Hardening Applied

- Root password rotated (multiple times, latest 2026-06-28)
- Non-root `deploy` user with sudo (NOPASSWD)
- fail2ban DISABLED 2026-06-07 (operator decision: re-enable with per-IP whitelist when ready)
- SSH **password + key** auth (changed 2026-06-28 from key-only after operator request)
- Port 2222 as primary SSH
- Attacker IPs removed from firewall: `199.91.220.120`, `118.68.20.93`
- **2026-06-28**: Metabase vhost (`analytics.patedeli.com`) DISABLED — entry point for re-infection #3
- **2026-06-28**: n8n vhost (`workflow.patedeli.com` + `flow.finizi.{ai,app}`) DISABLED — service no longer used
- **2026-06-28**: nginx `000-default-reject` catch-all added — rejects any Host header not matching legit vhost (prevents fallback leak)
- **2026-06-28**: Odoo container switched to `network_mode: host` — bypasses DO hypervisor block on Docker bridge IPs (172.18.0.0/16). Backup at `/opt/bmp/docker-compose.yml.bak.20260628-0901`.

### Pending Actions

1. Disable port 22 inbound (use 2222 only)
2. Audit attacker activity (check what `199.91.220.120` / `118.68.20.93` changed)
3. Rotate all service passwords (DB, Odoo admin, credentials)
4. Lock down sudo rules for `deploy` user

---

## API Token

- **DO API Token**: stored in `.env` as `DIGITALOCEAN_ACCESS_TOKEN`
- **Usage**: `doctl` CLI via `export DIGITALOCEAN_ACCESS_TOKEN=...`

---

## Recovery

If SSH is inaccessible:

1. Go to [DO Console](https://cloud.digitalocean.com/droplets/518827273/access)
2. Launch **Recovery Console**
3. Fix SSH keys:
   ```bash
   # Add current primary key for deploy
   echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICy6EAOLzk6t1BfvlBDEE87ZCVZYDB00dKWdYfqw9zcV patedeli-digitalocean (2026-06-28) trunghuynh@devops" > /home/deploy/.ssh/authorized_keys
   chown -R deploy:deploy /home/deploy/.ssh
   chmod 700 /home/deploy/.ssh && chmod 600 /home/deploy/.ssh/authorized_keys

   # Add same key for root (optional, only if you need root SSH)
   echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICy6EAOLzk6t1BfvlBDEE87ZCVZYDB00dKWdYfqw9zcV patedeli-digitalocean (2026-06-28) trunghuynh@devops" > /root/.ssh/authorized_keys
   chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys
   ```
4. Restart sshd: `systemctl restart sshd`
5. Check nftables: `nft flush ruleset` if blocking

Password fallback (set 2026-06-28): user `deploy`, password in 1Password.

---

## VNPay Proxy Droplet

| Property | Value |
|----------|-------|
| Name | `vnpay-proxy` |
| ID | `564429669` |
| IP | `165.245.188.82` |
| Size | s-1vcpu-1gb ($4/month) |
| Region | sgp1 |
| SSH Key | `patedeli-digitalocean` (`~/.ssh/patedeli-digitalocean`) — see SSH Access section above |
| Service | tinyproxy on port 8443 |
| Purpose | **DEPRECATED 2026-06-07** — host outbound was working again; vnpay-proxy workaround retired. Re-evaluate if DO applies another outbound block. |

### Config
- `/etc/tinyproxy/tinyproxy.conf` — Port 8443, Allow only `146.190.104.85`
- ~~Odoo docker-compose has `HTTP_PROXY`/`HTTPS_PROXY` pointing to this proxy~~ — proxy env vars **removed 2026-06-07** from `/opt/bmp/docker-compose.yml`; backup at `/opt/bmp/docker-compose.yml.bak-260607`

### Cleanup (run when ready)
1. ✅ Remove proxy env vars from `/opt/bmp/docker-compose.yml` — done 2026-06-07
2. ⚠️ **2026-06-28 partial regression**: host outbound still works, but **container bridge IPs (172.18.0.0/16) are blocked** by DO hypervisor. Fix: Odoo switched to `network_mode: host` (see `journals/2026-06-28-erp-down-do-outbound-block.md`). vnpay-proxy no longer helps even if re-enabled (it would only fix host-level proxying).
3. ⏳ `doctl compute droplet delete 564429669 --force` — pending operator decision (saves $4-6/mo)

---

## Known Issues

- **DO hypervisor filters outbound to Docker bridge IPs (172.18.0.0/16)** — as of 2026-06-28. Host outbound OK; container bridge outbound SYN-ACK dropped. Workaround: `network_mode: host` for Odoo container. DO support ticket recommended to confirm if filter is intentional. See `journals/2026-06-28-erp-down-do-outbound-block.md`.
- **Docker disk waste** — 15GB reclaimable (unused images/volumes). Run `docker system prune -a` when safe.
- **No swap** — consider adding swap as safety for memory spikes.
- **`erp2.patedeli.com` cert EXPIRED** — Feb 28 2026. Certbot renewal failing (`Some challenges have failed` per syslog). Either fix HTTP-01 challenge or `certbot delete --cert-name erp2.patedeli.com` if not needed.
