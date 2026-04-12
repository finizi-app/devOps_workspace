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
| User | `deploy` (sudo) |
| Key | `~/.ssh/id_ed25519` |
| Root password | `Kafe@20188` (rotated 2026-04-11) |
| Deploy password | `Deploy2026!` |

```bash
ssh -p 2222 -i ~/.ssh/id_ed25519 deploy@146.190.104.85
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

| Container | Status | Ports |
|-----------|--------|-------|
| `bmp-web-1` | Running | 8069, 8072 |

### Non-Docker Services

| Service | Details |
|---------|---------|
| Odoo | 5 worker processes, ~1.3GB RAM total |
| nginx | Reverse proxy (ports 80/443 → 8069) |
| SSH | ports 22 + 2222 |
| fail2ban | Monitoring SSH (maxretry: 3, 24h ban) |

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

### Hardening Applied

- Root password rotated
- Non-root `deploy` user with sudo
- fail2ban enabled (3 retries, 24h ban)
- SSH key-only auth
- Port 2222 as primary SSH
- Attacker IPs removed from firewall: `199.91.220.120`, `118.68.20.93`

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
   # Add key for deploy
   echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEG19Um4/ZOzhHqo3jEi9PilxoZNtODIWAiGq5wqq+0U trunghuynh@devops" > /home/deploy/.ssh/authorized_keys
   chown -R deploy:deploy /home/deploy/.ssh
   chmod 700 /home/deploy/.ssh && chmod 600 /home/deploy/.ssh/authorized_keys

   # Add key for root
   echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEG19Um4/ZOzhHqo3jEi9PilxoZNtODIWAiGq5wqq+0U trunghuynh@devops" > /root/.ssh/authorized_keys
   chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys
   ```
4. Restart sshd: `systemctl restart sshd`
5. Check nftables: `nft flush ruleset` if blocking

---

## VNPay Proxy Droplet

| Property | Value |
|----------|-------|
| Name | `vnpay-proxy` |
| ID | `564429669` |
| IP | `165.245.188.82` |
| Size | s-1vcpu-1gb ($4/month) |
| Region | sgp1 |
| SSH Key | `trunghuynh-devops` (`~/.ssh/id_ed25519`) |
| Service | tinyproxy on port 8443 |
| Purpose | Temporary — routes Odoo HTTPS requests to VNPay |

### Config
- `/etc/tinyproxy/tinyproxy.conf` — Port 8443, Allow only `146.190.104.85`
- Odoo docker-compose has `HTTP_PROXY`/`HTTPS_PROXY` pointing to this proxy

### Cleanup (when DO fixes outbound)
1. Remove proxy env vars from `/opt/bmp/docker-compose.yml`
2. `doctl compute droplet delete 564429669 --force`

---

## Known Issues (2026-04-12)

- **Outbound TCP broken on Odoo droplet** — DO infrastructure issue. Ports 80/443 blocked at hypervisor level. DO support ticket needed. Workaround: vnpay-proxy droplet.
- **Docker disk waste** — 15GB reclaimable (unused images/volumes). Run `docker system prune -a` when safe.
- **No swap** — consider adding swap as safety for memory spikes.
