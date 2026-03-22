# DigitalOcean Odoo Server - High Load Investigation Report

**Date:** 2026-03-22 14:14 ICT
**Server:** 146.190.104.85 (odoo-erp-multi-company)
**Investigator:** debugger agent

---

## Executive Summary

**Crypto miner re-infected server** on Mar 20, 2026. Process `llda` (disguised as `kworkelr`) consumed **198% CPU** (2 full cores). All malware processes killed and persistence mechanisms removed.

| Metric | Before | After |
|--------|--------|-------|
| CPU Idle | ~0% | **96.8%** |
| Load Average | 2.05 | **0.50** |
| Malware Process | `llda` (PID 68848) | **None** |

---

## Root Cause Analysis

### Malware Process
| Property | Value |
|----------|-------|
| PID | 68848 |
| Name | `llda` (disguised as `kworkelr`) |
| Binary | `/tmp/.dbus-u620axow7u/kworkelr` (deleted) |
| Started | Mar 20, 2026 |
| CPU Usage | 198% |
| Memory | 2.4GB (29.5%) |
| Owner | deploy |

### Persistence Mechanisms Found & Removed

| File | Type | Status |
|------|------|--------|
| `/etc/systemd/system/systemd-kworkerd.service` | Systemd service | **REMOVED** |
| `/etc/systemd/system/systemd-kworkerd.timer` | Systemd timer (30min boot delay) | **REMOVED** |
| `/usr/lib/systemd/systemd-kworkerd` | Malware binary | **REMOVED** |
| `/etc/init.d/DbSecuritySpt` | Init script | **REMOVED** |
| `/tmp/.cfg` | Config file | **REMOVED** |

### Persistence Flow
```
Boot → 30min delay → systemd-kworkerd.timer → systemd-kworkerd.service → /usr/lib/systemd/systemd-kworkerd
                                                                              ↓
                                                                    Spawns /tmp/.dbus-*/kworkelr (deleted)
                                                                              ↓
                                                                    Process renames to kworkelr/llda
```

### Why Previous Cleanup Failed
1. **Immutable attribute** (`chattr +i`) was set on malware files
2. `chattr` binary was missing from system (possibly removed by malware)
3. Files survived March 6 cleanup

---

## Cleanup Actions Taken

1. **Killed malware process:** `kill -9 68848`
2. **Installed e2fsprogs:** Restored `chattr` command
3. **Removed immutable flags:** `chattr -i` on all malware files
4. **Deleted persistence files:** All service/timer/binary files removed
5. **Reloaded systemd:** `systemctl daemon-reload`

---

## Current System Status

### Resources
| Metric | Value |
|--------|-------|
| Uptime | 8 days, 13:48 |
| Load Average | 0.50, 1.49, 1.82 |
| CPU Idle | 96.8% |
| Memory | 1.3GB / 7.8GB (16%) |
| Disk | 48GB / 78GB (62%) |

### Security Status
| Check | Status |
|-------|--------|
| Malware processes | **None** |
| Persistence files | **All removed** |
| Fail2ban active | **Yes (201 IPs banned)** |
| SSH keys (deploy) | **Legitimate only** |
| Root crontab | **Empty** |

---

## Remaining Security Concerns

### P0 - Critical
1. **Server was re-infected** - Original compromise vector not fully addressed
2. **SSH still on port 22** - Should restrict to office IPs only
3. **Password auth enabled** - Should disable, use keys only

### P1 - High
4. **Attacker had deploy user access** - Consider rotating all credentials
5. **No intrusion detection** - Install rkhunter, chkrootkit
6. **No alerting** - Set up CPU/load monitoring alerts

### P2 - Medium
7. **Root login enabled** - Disable `PermitRootLogin`
8. **Change all passwords** - DB, Odoo admin, service accounts

---

## Recommendations

### Immediate
```bash
# 1. Restrict SSH port 22 to office IPs via DO firewall
doctl compute firewall add-rules ...

# 2. Disable password auth
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl reload sshd

# 3. Install intrusion detection
sudo apt install rkhunter chkrootkit
sudo rkhunter --update
sudo rkhunter --check
```

### Short-term
- Set up monitoring alerts for CPU > 80%
- Audit all files modified by attacker IPs (199.91.220.120, 118.68.20.93)
- Rotate all credentials
- Consider reimaging server from clean backup

### Long-term
- Deploy Cloudflare Tunnel to remove direct server exposure
- Implement log forwarding to centralized SIEM
- Regular security audits

---

## Unresolved Questions

1. **How did malware re-infect after March 6 cleanup?** - Possibly missed persistence or new breach
2. **Was deploy user compromised?** - Malware ran as deploy user
3. **Are there other hidden persistence mechanisms?** - Recommend full audit

---

## Connection Details

- **SSH:** `ssh -i ~/.ssh/id_ed25519 deploy@146.190.104.85`
- **Port:** 22
- **User:** deploy (sudo)
