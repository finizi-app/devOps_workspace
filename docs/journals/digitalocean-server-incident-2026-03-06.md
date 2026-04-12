# DigitalOcean Server Incident - 2026-03-06

## Summary
Odoo server `146.190.104.85` compromised via **SSH brute force** on March 1, 2026. Attacker guessed root password, installed `kinsing`/`kswpad` crypto miner. Fully resolved on 2026-03-06 at ~02:00 ICT.

## ✅ RESOLVED - 2026-03-06 01:45 ICT

### SSH Access
- **User**: `deploy` (non-root, sudo access)
- **Port**: `2222`
- **Key**: `~/.ssh/id_ed25519`
- **Command**: `ssh -p 2222 -i ~/.ssh/id_ed25519 deploy@146.190.104.85`

### Miners Killed
| Malware          | CPU      | Status           |
| ---------------- | -------- | ---------------- |
| `llda`           | 86%      | Killed & removed |
| `kswpad`         | 73%      | Killed & removed |
| `/tmp/moni.lod`  | watchdog | Removed          |
| `/tmp/gates.lod` | watchdog | Removed          |

### Server State After Cleanup
- CPU: **100% idle** ✅
- Docker: n8n, Odoo, workflow-db all running ✅
- Disk: 52G / 78G (67%) ✅

---

## Root Cause of SSH Block
1. **fail2ban** banned external IPs after repeated attempts
2. **PermitRootLogin** — sshd rejected root even with valid key (auth log: `ROOT LOGIN REFUSED`)
3. **nftables** DROP policy blocked port 2222
4. **Crypto miner** `kswpad` installed as fake systemd binary at `/usr/lib/systemd/system/kswpad`

## Resolution Steps
1. DigitalOcean Recovery Console used to add SSH pubkey to `/root/.ssh/authorized_keys`
2. `sshd` reinstalled: `apt-get install --reinstall openssh-server`
3. Port 2222 opened: systemd socket override + DO firewall via `doctl`
4. nftables flushed: `nft flush ruleset`
5. Non-root user `deploy` created with sudo + SSH key
6. Miners killed: `llda` (PID 27388) and `kswpad` (PID 865)
7. Persistence files removed: `/tmp/moni.lod`, `/tmp/gates.lod`
8. Cleanup script run via nohup via SSH

## 🔍 Root Cause - Attack Timeline

### Entry Point: SSH Brute Force (Port 22)
```
Mar 1 02:04 UTC — Accepted password for root from 199.91.220.120  ← INITIAL BREACH
Mar 1 03:24 UTC — Accepted publickey from 118.68.20.93 (backdoor RSA key)
Mar 1 03:24–04:xx — Attacker connects repeatedly with backdoor key
Mar 1 05:17 UTC — kswpad miner binary written to /usr/lib/systemd/system/kswpad
```

### How It Happened
1. Root SSH exposed on port 22 with weak password `Hq@20011982`
2. Attacker `199.91.220.120` brute-forced password and got root shell
3. Installed backdoor RSA key (fingerprint `YrnrRmkyG2c5VO+BiTtsQ2fa4mXaOvzWL6DfD4guL94`) for persistent access from `118.68.20.93`
4. Installed `kswpad` as fake systemd service + crypto miner `llda`
5. Miner ran undetected for 5+ days consuming 100% CPU

### NOT the attack vector
- n8n webhooks — all nginx requests returned 404/400/101
- Docker API — port 2375 was not exposed
- Web exploits — CGI/PHP attacks from 89.117.51.126 all blocked by nginx

---

## Server Details
- Droplet ID: `518827273`
- Name: `odoo-erp-multi-company`
- IP: `146.190.104.85`
- SSH Port: `2222` (port 22 still active but use 2222)
- SSH User: `deploy` (sudo)
- SSH Key: `~/.ssh/id_ed25519` (MacBook & Thinkpad X1 Extreme)
- Root password (rotated 2026-04-11): `Kafe@20188`
- Deploy password: `Deploy2026!`
- Connect: `ssh -p 2222 -i ~/.ssh/id_ed25519 deploy@146.190.104.85`

## ⚠️ Pending Actions
1. ~~**Metabase**: Container needs restart~~: Restarted ✅ (`workflow-services-metabase-1` is Up)
2. ~~**Harden SSH**~~: Root password rotated ✅ — still need to disable port 22, restrict 2222 to office IPs
3. ~~**Enable fail2ban**~~: Enabled ✅ with `maxretry: 3` and 24h ban time (monitoring ports 22 and 2222)
4. ~~**Remove kswpad service**~~: Removed ✅ (`/usr/lib/systemd/system/kswpad` and daemon reloaded)
5. **Audit attacker's activity**: Check what else 199.91.220.120 / 118.68.20.93 changed
6. **Block attacker IPs** in DO Cloud Firewall: `199.91.220.120`, `118.68.20.93`
7. **Change all passwords**: DB passwords, Odoo admin, service credentials
8. **Deploy user sudo**: Lock down sudo rules once stable
