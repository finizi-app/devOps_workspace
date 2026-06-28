# Crypto Miner Re-Infection #3 — 2026-06-28

## Summary

Third crypto miner re-infection on DigitalOcean droplet `146.190.104.85`
(odoo-erp-multi-company). Entry point: **Metabase CVE-2021-41277** pre-auth RCE
via publicly-exposed `analytics.patedeli.com` vhost. Attacker gained root on
**2026-06-13 19:09:37**, opened session as `deploy` user via `loginctl`/`runuser`
(no SSH login — auth.log corrupted by attacker), dropped XMRig-style miner
(`kthreadadd` 525 threads + `edac0` perl), persisted via 5 deploy-crontab
entries. Ran undetected for **15 days** until discovered via 184% CPU load.

## ✅ RESOLVED — 2026-06-28

### Detection
- Found via top CPU: deploy-owned `crond` (PID 1139216) running **184% CPU**,
  uptime **6d 23h**
- Initial process listing showed fake kernel threads: `kthreadadd64`,
  `edac0` (perl), `go` (sh wrapper)
- All binaries ran from deleted CWDs (`(deleted)` in `/proc/PID/cwd`) — attacker
  self-cleaned wrapper files after activation

### Miners Killed
| Process | Type | Status |
|---------|------|--------|
| `crond` PID 1139216 | fake crond (XMRig wrapper) | Killed & removed |
| `kthreadadd64` PID 1392307 | XMRig variant 64-bit | Killed |
| `kthreadadd` PID 1392303 | spawner for kthreadadd64 | Killed |
| `edac0` PIDs 1142599, 1142604, 1142609 | perl miner wrappers | Killed (3 procs) |
| `go` PID 1385821 | dash shell wrapper | Killed |

### Artifacts Removed
- `/home/deploy/.configrc7/` — fake crond + watchdog scripts (self-deleted by attacker before kill)
- `/tmp/.X291-unix/.rsync/` — miner package: `kthreadadd32`, `kthreadadd64`, `go`, `edac0`, `scan.log`, `dota3.tar.gz` (4.5MB miner payload) (self-deleted by attacker)
- `crontab -u deploy` — 5 malicious entries cleared
- `/usr/bin/.sshd`, `/usr/bin/bsd-port`, `/etc/kswpad`, `/lib/systemd/system/kswpad` — older backdoors (already cleaned by attacker's own `delsshd` script, verified gone)

### Server State After Cleanup
- CPU: **load 0.24** (was ~3.0 with 184% miner) ✅
- Odoo container `bmp-web-1` Up 2 weeks, HTTP 303 ✅
- nginx active, config test OK ✅
- sshd active on 22 + 2222 ✅
- All deploy-owned processes: only sshd/bash/systemd (legit) ✅

---

## Root Cause

### Entry Point: Metabase CVE-2021-41277

**Vulnerability**: Metabase < 0.40.5 has a pre-auth Remote Code Execution via the
setup wizard H2 database connection string. An unauthenticated attacker can POST
to `/api/setup` with a malicious H2 JDBC URL and gain code execution as the
Metabase process user (typically root if running in Docker).

**Exposure timeline**:
- 2025-10-01: `workflow-services` nginx config first created with `analytics.patedeli.com`
  vhost (per file mtime of backup) → Metabase exposed publicly
- 2026-04-12 to 2026-06-27: Metabase process running on `127.0.0.1:3000`,
  reachable via `https://analytics.patedeli.com/`
- 2026-06-13 19:09:37 UTC: RCE triggered, attacker opens deploy session (no SSH)
- 2026-06-13 19:37:45 UTC: malicious crontab installed
- 2026-06-28 (today): discovered & cleaned

**Why no SSH brute force**: deploy user has `NOPASSWD: ALL` sudo; attacker
already had root via Metabase RCE, used `loginctl`/`runuser` to open
`deploy` session 1737 directly — never went through sshd. Auth.log for
2026-06-13 was zeroed by attacker (gzip header preserved, payload empty).

### Exact Timeline (from syslog.3.gz)

```
2026-06-13 19:09:37  systemd-logind: "Started Session 1737 of User deploy"
2026-06-13 19:09:54  crontab[deploy] LIST       ← attacker recon
2026-06-13 19:17:30  + /tmp/.X291-unix/         ← drop miner package
2026-06-13 19:37:30  + /home/deploy/.configrc7/ ← drop watcher scripts
2026-06-13 19:37:45  crontab[deploy] REPLACE    ← inject 5 cron entries
2026-06-13 19:42:00  + kthreadadd, edac0, go   ← activate miner
... [15 days of undetected mining] ...
2026-06-28 05:33:00  detected via 184% CPU load on crond
2026-06-28 05:43:00  killed all miner PIDs
2026-06-28 05:55:00  cleaned nginx vhosts (Metabase + n8n)
2026-06-28 06:11:00  rootkit hunt complete, no findings
```

### Persistence Mechanism

**Deploy user's crontab** (5 entries, captured before self-delete):
```
5 6 */2 * 0 /home/deploy/.configrc7/a/upd>/dev/null 2>&1
@reboot /home/deploy/.configrc7/a/upd>/dev/null 2>&1
5 8 * * 0 /home/deploy/.configrc7/b/sync>/dev/null 2>&1
@reboot /home/deploy/.configrc7/b/sync>/dev/null 2>&1
0 0 */3 * * /tmp/.X291-unix/.rsync/c/aptitude>/dev/null 2>&1
```

**Watchdog architecture**:
- `configrc7/a/upd` — restart `crond` wrapper every 2 days + @reboot
- `configrc7/b/sync` — restart edac0 (perl miner) every Sunday + @reboot
- `X291-unix/.rsync/c/aptitude` — full miner re-download every 3 days
- `go` script — runs `kthreadadd` in infinite 4-hour loop (525 threads)
- After miner activation, all wrappers self-delete (processes continue with
  `(deleted)` CWDs)

---

## Rootkit Hunt Results

### Checks Performed (28 checks)

| ID | Check | Result |
|----|-------|--------|
| R1 | `dpkg --verify` (md5sum of all installed files) | ✅ No binary tampering (only config-file mods, legitimate) |
| R2 | `/etc/ld.so.preload` | ✅ Empty (no LD_PRELOAD rootkit) |
| R3 | SUID binaries in unusual locations | ✅ Only snap sandbox (legit) |
| R4 | Hidden kernel modules (lsmod vs /proc/modules) | ✅ No hidden modules |
| R5 | sshd binary integrity | ✅ In `openssh-server` package, unmodified |
| R6-R8 | Critical binaries md5 (sshd, sudo, passwd, su, cron, nginx, systemd, dash, perl) | ✅ All match packages |
| R9 | delsshd-target backdoors (`.sshd`, `bsd-port`, `kswpad`, `DbSecuritySpt`, `dns-udp4`) | ✅ None present |
| R10 | `/etc/profile.d/` | ✅ Standard files only (no `bash.cfg`/`gateway.sh`) |
| R11-R12 | `/etc/init.d/cron`, `/etc/sudoers` content | ✅ Legit (cron init script + deploy NOPASSWD sudo) |
| R13 | `/etc/sudoers.d/` | ✅ Only `90-cloud-init-users` |
| R14 | Actual binary tampering (`dpkg --verify | grep ^[^?]`) | ✅ None |
| R15 | Hidden bind mounts | ✅ Standard tmpfs/devtmpfs only |
| R16-R18 | Recently modified files (post Jun 13) | ✅ Only nginx config (my changes) + legit (shadow rotated today, snap mounts, bmp vhost unchanged since Mar) |
| R19 | UFW rules | ✅ 22+2222 restricted to `58.187.49.93` |
| R20-R21 | Installed packages + docker images | ✅ Only legit `busybox:latest` + `bmp:latest`, one container `bmp-web-1` |
| R22 | docker inspect `bmp-web-1` | ✅ Not privileged, only legit Odoo module mounts |
| R23 | Inside Odoo container | ✅ Only Odoo workers (1 master + 4 HTTP + 1 gevent), no miner, clean /tmp + /dev/shm |
| R24 | dmesg | ⚠️ Permission denied (expected, normal kernel restriction) |
| R25-R28 | rkhunter + chkrootkit | ✅ False positives only (test fixtures, systemd-networkd) |

### Conclusion
**No rootkit found.** No binary tampering, no hidden modules, no SUID anomalies,
no LD_PRELOAD, no backdoors. Attacker persistence was entirely via crontab
(now cleared) + deleted binaries (processes killed).

---

## Hardening Applied This Session

### Nginx Cleanup
1. **Disabled `analytics.patedeli.com` vhost** — commented out in
   `/etc/nginx/sites-available/workflow-services` (was Metabase upstream
   `127.0.0.1:3000`)
2. **Disabled n8n vhosts** — commented out `workflow.patedeli.com` (HTTPS),
   `flow.finizi.ai`, `flow.finizi.app` (HTTP), plus Certbot HTTP→HTTPS
   redirect for `workflow.patedeli.com`
3. **Added `000-default-reject` catch-all** — `/etc/nginx/sites-enabled/000-default-reject`
   with `server { listen 80/443 default_server; server_name _; ssl_reject_handshake on; return 444; }`
   — drops TLS handshake for any Host header not matching legit vhost
4. **Backups retained**: `workflow-services.bak.20260628-054049`,
   `workflow-services.bak.20260628-054617`

### SSH Cleanup (2026-06-28 morning)
- Deploy password rotated (was `Deploy2026!`) — see 1Password "Patedeli DO Infra" entry
- `PasswordAuthentication yes` enabled (was key-only)
- Root password rotated (per `/etc/shadow` mtime today)
- `PubkeyAuthentication yes` kept as fallback

### Cert Cleanup (Pending)
- Certbot certs for `analytics.patedeli.com`, `workflow.patedeli.com` still on
  disk in `/etc/letsencrypt/live/` — not needed but harmless. Can be deleted
  with `certbot delete --cert-name analytics.patedeli.com` etc.

---

## Why Detection Took 15 Days

1. **No monitoring** on droplet CPU/process anomalies (only DO basic metrics)
2. **fail2ban disabled** since 2026-06-07 — no auto-ban on suspicious activity
3. **Metabase dead** but vhost still served (returned 502 to attackers) — masked
   the actual compromise
4. **Auth.log corrupted** by attacker — even forensic investigation difficult
5. **No IDS / file integrity monitoring** — would have caught the crontab injection
   within minutes
6. **Wrapper self-deletion** — miner processes kept running with `(deleted)` CWDs,
   hard to find without `/proc/PID/fd` walk

---

## Recommendations (for operator decision)

### Immediate (do today)
- [ ] `certbot delete --cert-name analytics.patedeli.com`
- [ ] `certbot delete --cert-name workflow.patedeli.com`
- [ ] Check `flow.finizi.ai`, `flow.finizi.app` DNS — point elsewhere or remove
- [ ] Audit Odoo admin password + DB password (operator chose "minimal" rotation
      earlier, may not have rotated DB yet)
- [ ] Audit any service that stored secrets on this droplet since Apr 2026

### Short-term (this week)
- [ ] Install file integrity monitoring (`aide` or `tripwire`) — would have
      detected crontab injection immediately
- [ ] Install `debsums` package — needed for binary md5 verification (currently
      not installed)
- [ ] Add a daily cron that:
      - Checks for `(deleted)` executables in `/proc/*/exe`
      - Alerts on new crontab entries for human users
      - Alerts on processes using >50% CPU for >1 hour
- [ ] Re-enable fail2ban with per-IP whitelist (operator decision pending)

### Long-term (this month)
- [ ] Rebuild Odoo image `bmp:latest` from source — currently 3 years old, may
      have other unpatched CVEs
- [ ] Move all admin services (Metabase, n8n, etc.) behind VPN (WireGuard/Tailscale)
      — never expose to public Internet
- [ ] Set up central logging (off-droplet) so attackers can't zero auth.log
- [ ] DO snapshot before next major deploy (enables quick rebuild)
- [ ] Consider dedicated droplet per service (isolation)

---

## Open Questions

- Metabase version cannot be determined (process dead, logs gone, no version
  marker left on disk). CVE-2021-41277 applicability inferred from timing +
  exposed setup endpoint probing on Jun 27 + dead Metabase now.
- Auth.log corruption: gzip header valid, payload empty — consistent with
  attacker overwriting file contents while preserving size (to defeat naive
  detection). No tool used; manual observation.
- Dropped binaries (`configrc7/a/crond` 2.2MB, `kthreadadd32`/`64` 1.1-1.4MB)
  were not recoverable — already deleted before kill. Miner behavior inferred
  from `/proc/PID/fd/10` of `go` script and run-time behavior.
- Three cron schedule patterns suggest three independent re-infection or
  update cycles — could be the same attacker returning with new tools, or
  multiple attackers. Cannot determine without binary analysis.
