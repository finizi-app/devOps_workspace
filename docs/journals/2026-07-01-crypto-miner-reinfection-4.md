# Crypto Miner Re-Infection #4 — 2026-07-01

## Summary

Fourth crypto miner re-infection on the same droplet. Attacker logged in
via **stolen RSA private key** (`mdrfckr` comment, fingerprint
`MkYY9qiVsFGBC5WkjoClCkwEFW5iSjcGQF7m4n4H7Cw`) on **2026-06-29 07:56 UTC**
from IP `136.243.92.210` (Germany). Re-deployed full miner stack with NEW
toolchain (`.X212-unix` instead of `.X291-unix`) and re-installed crontab.
Miner ran undetected for ~2.5 days until load alarm at 1.86 caught my
attention during a routine check. Cleaned in ~5 min.

## ✅ RESOLVED — 2026-07-01 15:56

### Detection
- Routine load check: `1.50 / 2.07 / 2.14` (was idle 0.24 hours earlier)
- Top process: `deploy / kthreadadd64` (PID 1608043, 9% CPU, 22 min uptime)
- Process tree: `go` → `kthreadadd` → `kthreadadd64` + 3× `edac0` perl
- Artifacts: `/home/deploy/.configrc7/` + `/tmp/.X212-unix/.rsync/`

### Miners Killed
| Process | PID | Status |
|---------|-----|--------|
| `kthreadadd64` | 1608043 | Killed |
| `kthreadadd` (parent) | 1608039 | Killed |
| `go` wrapper | 1581404 | Killed |
| `edac0` × 3 | 1462718, 1462731, 1462739 | Killed |

### Artifacts Removed
- `/home/deploy/.configrc7/` (recreated by attacker Jun 29 09:56 UTC)
- `/tmp/.X212-unix/` (full miner package: kthreadadd32/64, go, edac0, scan.log, dota3.tar.gz)
- Crontab cleared (5 malicious entries)

---

## Root Cause

### Entry Point: STOLEN RSA KEY

`auth.log` shows:

```
Jun 29 07:56:29 sshd[1457302]: Accepted publickey for deploy from 
136.243.92.210 port 45560 ssh2: RSA SHA256:MkYY9qiVsFGBC5WkjoClCkwEFW5iSjcGQF7m4n4H7Cw
```

**That fingerprint matches the `mdrfckr` key currently (was) in
`/home/deploy/.ssh/authorized_keys`** — confirmed via `ssh-keygen -lf`.

The key was added on **2026-04-21 08:05 UTC** during incident recovery
from the original March crypto miner attack (per authorized_keys
mtime). It has been there ever since. The attacker has had the matching
private key for at least 2.5 days (used it 2026-06-29 07:56 UTC to
re-establish access after the Jun 28 cleanup).

**How the key was stolen**: unknown. Possibilities:
- Key file on operator's laptop compromised at some point
- Key file copied by attacker during a previous root shell (from
  incident #1, #2, or #3) before we revoked it — but it's been there
  since Apr 21, so any of those incidents could have leaked it
- Operator accidentally shared/leaked the key

### What happened between Jun 28 12:50 (operator logout) and Jul 1 15:55 (detection)

| Time (UTC) | Event |
|-----------|-------|
| Jun 28 12:50 | Operator `42.112.181.61` logged out |
| Jun 28 13:00ish | My cleanup: killed miner procs, cleared crontab, removed `.configrc7` + `.X291-unix` |
| Jun 29 07:56 | Attacker `136.243.92.210` logged in via stolen RSA key |
| Jun 29 ~07:56-09:56 | Attacker: read crontab, uploaded new toolchain `.X212-unix`, dropped `.configrc7`, re-installed crontab |
| Jun 29 09:56 | `.configrc7/` first created (mtime) |
| Jun 29 09:56 | 3× `edac0` processes started (PID 1462718 etc., uptime 2-05:59:17 = Jun 29 09:56) |
| Jul 1 00:00 | `go` wrapper restarted (uptime 15:55:17 = Jul 1 00:00) — daily cron trigger |
| Jul 1 15:33 | `kthreadadd64` restarted (uptime 22:44 = Jul 1 15:33) — `@reboot` or 4h cron loop |
| Jul 1 15:55 | Detected, killed |

### Why miner survived my Jun 28 cleanup

My earlier cleanup:
- Killed 6 PIDs (1385821 go, 1142599/1142604/1142609 edac0)
- Cleared crontab
- Removed `.configrc7/` + `.X291-unix/`

But:
- Crontab was empty at end of cleanup
- `.configrc7` was gone
- 24h later, attacker came back, re-injected crontab, re-uploaded
  `.configrc7` with new toolchain
- Their re-injection mechanism: directly via SSH + `crontab` command
  (no persistence needed — they have the key)

### Why I didn't catch this earlier

- No CPU/monitoring alerts (load was 1-2, not extreme)
- No file integrity monitoring (aide/tripwire not installed)
- I marked `mdrfckr` as "legacy, recommend revoking after migration"
  but the user had not done the migration → key stayed → exploited

---

## Hardening Applied This Session

### SSH key rotation
- **Removed `mdrfckr` RSA key from `authorized_keys`** — confirmed
  compromised via auth.log
- Updated `/usr/local/share/ssh-recover/authorized_keys` baseline to
  remove the compromised key (only `patedeli-digitalocean` ed25519 now)
- Backup of old `authorized_keys` at `/home/deploy/.ssh/authorized_keys.bak.20260701-HHMMSS`
- After: only 1 key in authorized_keys (`patedeli-digitalocean`)

### `ssh-recover` baseline updated
- Baseline file now has only the safe key
- Future recoveries won't reintroduce the compromised key

### NOT done (pending operator decision)
- Password auth still enabled (operator's earlier request)
- fail2ban still disabled (operator's earlier decision)
- New SSH key generation (operator's `~/.ssh/id_ed25519` likely also
  has the compromised `mdrfckr` private key — recommend regenerating)

---

## Open Questions

1. **Where is the operator's copy of `mdrfckr` private key?** Operator
   should:
   - Check `~/.ssh/id_ed25519` (per docs) — if it's the `mdrfckr` key,
     it's compromised. Regenerate.
   - Check any backup systems, password manager entries, CI/CD secrets
2. **Are there OTHER authorized keys we don't know about?** Only
   checked deploy's authorized_keys. Root's authorized_keys may also
   have unauthorized keys added during past incidents.
3. **Is `mdrfckr` key in the operator's GitHub, GitLab, or any shared
   config?** If so, rotate it everywhere.
4. **Should we move to cert-based SSH** (e.g., Teleport, smallstep) to
   eliminate static key risk?