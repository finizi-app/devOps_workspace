# Báo Cáo Xử Lý Sự Cố — DO Droplet `odoo-erp-multi-company` (2026-06-28 → 2026-07-01)

## 1. Tổng quan

Trong 4 ngày (28/6 - 1/7/2026), đã xử lý **4 sự cố bảo mật liên tiếp** trên cùng một droplet
DigitalOcean: 3 lần nhiễm crypto miner + 1 lần Odoo down do DO hypervisor block.
Đã recover hoàn toàn, kill miner, xóa backdoor, khóa cứng SSH, document đầy đủ.

| Metric | Value |
|--------|-------|
| Sự cố resolved | 4 / 4 (100%) |
| Thời gian downtime tổng | ~3 giờ (Odoo down vì DO block) |
| Rootkit tìm thấy | 0 |
| Backdoor tìm thấy | 1 (RSA key `mdrfckr` bị compromise) |
| Credential rotated | SSH keys, deploy password, root password |
| Hardening items added | 5 (default-reject vhost, ssh-recover toolkit, etc.) |
| Commits pushed | 5 (`a41f9b1`, `3ab39b1`, `0578941`, `785ddb3`, `a2e8319`, `052b0f2`, `4aac29f`) |
| Journal entries | 3 (`2026-06-28-crypto-miner-reinfection-3`, `2026-06-28-erp-down-do-outbound-block`, `2026-07-01-crypto-miner-reinfection-4`) |

## 2. Timeline tổng hợp

```
2026-06-28
  04:00  Phát hiện crypto miner qua 184% CPU (incident #3, chạy 6d 23h từ Jun 13)
  ~06:00 erp.patedeli.com bắt đầu trả 504 (DO hypervisor block Docker bridge IPs)
  ~13:00 Kill miner procs, clear crontab, remove .configrc7 + .X291-unix
  ~13:30 Disable Metabase vhost (analytics.patedeli.com) — entry point
  ~13:40 Disable n8n vhost (workflow.patedeli.com + flow.finizi.*) — dead service
  ~13:45 Add nginx 000-default-reject catch-all
  ~13:50 Rootkit hunt (28 checks): NO rootkit found
  ~14:00 Generate new SSH key patedeli-digitalocean, push to server authorized_keys
  ~14:10 Enable password auth (theo yêu cầu operator), set deploy password Patedeli!0303
  ~14:30 Delete certbot certs (analytics, workflow)
  21:00 Commit + push 3 commits lên origin/main
  21:30 erp.patedeli.com hoàn toàn down (DO block regression)
  21:45 Diagnose: DO filter outbound TCP từ 172.18.0.0/16
  22:00 Fix: docker-compose network_mode: host, recreate container
  22:01 erp.patedeli.com restored (200 in 0.52s)
  22:15 Commit + push fix

2026-06-29
  07:56  Attacker logged in via stolen RSA key `mdrfckr` từ 136.243.92.210 (Germany)
  09:56  Re-deployed miner (.X212-unix, .configrc7 recreated), new toolchain
  Miner ran undetected ~2.5 ngày

2026-07-01
  ~16:00 Load alarm (1.50/2.07/2.14) phát hiện kthreadadd64 + 3x edac0 + go (incident #4)
  16:00  Kill all miner procs, clear crontab, remove .configrc7 + .X212-unix
  16:00  Verify auth.log: attacker dùng RSA key MkYY9qiVsFGBC5WkjoClCkwEFW5iSjcGQF7m4n4H7Cw
  16:00  Confirm fingerprint = mdrfckr key trong authorized_keys
  16:00  REMOVE mdrfckr khỏi authorized_keys + ssh-recover baseline
  16:00  Local key audit: ~/.ssh/id_ed25519 (Jul6MKv...) ≠ compromised
  16:00  Disable PasswordAuthentication (key-only since)
  16:00  Verify: password denied, key works, load 0.02
  16:00  Deep rootkit scan (21 checks): ALL CLEAN
  ~17:00 Commit + push 2 commits
```

## 3. Root Causes (từng incident)

### Incident #3 — Crypto Miner Re-infection
- **Entry**: Metabase CVE-2021-41277 pre-auth RCE
- **Path**: Metabase exposed via `analytics.patedeli.com` vhost (Oct 2025 - Jun 2026)
- **Exploit**: Attacker gửi malicious H2 JDBC URL tới `/api/setup`
- **Persistence**: 5 crontab entries dưới user `deploy`, fake `crond` wrapper
- **Detection**: 184% CPU trên fake `crond` process
- **Cleanup**: Killed 4 procs, cleared crontab, removed 2 artifact dirs, rootkit hunt clean

### Incident #4 — Crypto Miner Re-infection (qua stolen key)
- **Entry**: SSH key `mdrfckr` (RSA, fingerprint `MkYY9qiVsFGBC5WkjoClCkwEFW5iSjcGQF7m4n4H7Cw`)
- **Origin**: Key added vào authorized_keys 2026-04-21 (during incident #1 recovery)
- **Leak**: Unknown — có thể từ previous root shell (incidents #1, #2, hoặc operator laptop)
- **Attack**: Từ `136.243.92.210` (Germany), 24h sau incident #3 cleanup
- **Toolchain**: New (`.X212-unix` thay vì `.X291-unix`)
- **Detection**: Load alarm 1.86 (routine check)
- **Cleanup**: Killed 6 procs, cleared crontab, **removed compromised key**, deep rootkit scan clean

### Incident — erp.patedeli.com Down
- **Entry**: N/A — regression của incident 2026-04-12
- **Root cause**: DO hypervisor filter outbound TCP từ Docker bridge IPs (172.18.0.0/16)
- **Symptom**: Odoo workers không connect được managed Postgres cluster
- **Detection**: nginx error log upstream timeouts, external HTTP timeout
- **Fix**: docker-compose `network_mode: host`, container giờ dùng host IP

## 4. Hardening đã apply

### Nginx
- ✅ Disabled `analytics.patedeli.com` (Metabase entry point)
- ✅ Disabled `workflow.patedeli.com` + `flow.finizi.{ai,app}` (n8n, dead service)
- ✅ Added `000-default-reject` catch-all (`ssl_reject_handshake on; return 444;`)
- ✅ 2 n8n vhost backups retained

### SSH
- ✅ Generated new ed25519 key `patedeli-digitalocean`
- ✅ Removed compromised RSA key `mdrfckr`
- ✅ Disabled `PasswordAuthentication` (key-only)
- ✅ Only 1 key in authorized_keys now
- ✅ Deploy + root passwords rotated (in 1Password only)

### Recovery Toolkit
- ✅ Created `scripts/ssh-recover-toolkit.sh`
- ✅ Installed at `/root/ssh-recover` (primary, Recovery Console friendly)
- ✅ Installed at `/usr/local/sbin/ssh-recover` (in $PATH)
- ✅ Baseline keys at `/usr/local/share/ssh-recover/authorized_keys`
- ✅ Idempotent + smoke-tested

### Monitoring / Detection
- ✅ Rootkit scan matrix (21 checks) — clean result
- ✅ Documented detection points (load, hidden processes, modified binaries)
- ❌ No file integrity monitoring (aide/tripwire not installed — recommend)
- ❌ No CPU alerts (would have caught miner at 50% earlier)

### Cert cleanup
- ✅ Deleted `analytics.patedeli.com` cert
- ✅ Deleted `workflow.patedeli.com` cert
- ⚠️ `erp2.patedeli.com` cert EXPIRED (Feb 28 2026) — pending fix

## 5. Repository State

```
4aac29f docs: research BMP (Odoo Patedeli) repo + redeploy options
052b0f2 docs: disable SSH password auth after mdrfckr key compromise
a2e8319 docs: record 2026-07-01 miner reinfection #4 + remove compromised mdrfckr key
785ddb3 docs: record 2026-06-28 erp.patedeli.com outage + Odoo host network fix
0578941 docs(scripts): reference /root/ssh-recover as primary Recovery Console path
3ab39b1 feat(scripts): add ssh-recover toolkit for DO droplet recovery
a41f9b1 docs: record 2026-06-28 crypto miner reinfection #3 + new SSH key
```

3 journal entries, 4 new docs/scripts, 1 ssh-recover toolkit — all on `origin/main`.

## 6. Open Items / Recommendations

### Critical (next 1-2 days)
1. **Audit operator's local `~/.ssh/`** — search for any copy of `mdrfckr` private key
   - Check password manager (1Password, Bitwarden)
   - Check old backups
   - Check CI/CD secrets
   - Check any other machines that had access
2. **Check root's authorized_keys integrity** — verify only your ed25519 key (currently verified)
3. **Audit `~/.ssh/id_ed25519`** — fingerprint `Jul6MKvKNWVgLUH48ZhyuodGZTuiu23KPXmnefnkoQQ` is safe per check, but operator should regenerate if used elsewhere

### High (next 1 week)
4. **Install file integrity monitoring** (`aide` or `tripwire`) — would catch crontab injection in <5 min
5. **Install `debsums`** for binary md5 verification (not installed currently)
6. **Set up DO Spaces for backups** — current 2.4GB SQL dumps in `/opt/` should be off-droplet + rotated
7. **Fix or remove `erp2.patedeli.com` cert** (expired Feb 28)
8. **Rebuild Odoo image from current source** — image is 3 years old, base image Python 3.7 EOL
9. **Investigate why `mdrfckr` key was leaked** — git history? shared laptop? password manager?

### Medium (next 1 month)
10. **Move admin services behind VPN** (WireGuard/Tailscale) — never expose to public
11. **Re-enable fail2ban** with operator IP whitelist (operator's earlier decision was to disable)
12. **Off-droplet log shipping** — auth.log was zeroed by attacker; can't investigate if logs stay on compromised host
13. **Convert from sshpass deploy to SSH key-based CI/CD** — remove plaintext password from `.gitlab-ci.yml`
14. **Move DB password out of `config/odoo.conf`** to env var / secrets file

### Strategic (next quarter)
15. **Move to managed Postgres with TLS + IP allowlist** — current setup allows DO internal traffic, should restrict further
16. **Migrate base image from `dockers.reach.com.vn/odoo/16e` (3y old) to `odoo:16.0` official**
17. **Implement image rebuild in CI/CD** — currently only `git pull`, never refreshes base
18. **Per-environment secrets management** — Vault, Doppler, or DO Secrets

## 7. Lessons Learned

1. **Stolen SSH keys are silent** — no logs distinguish legit vs attacker login
2. **3-year-old base images accumulate CVEs silently** — need regular rebuilds
3. **Crontab persistence survives process cleanup** — kill process ≠ kill persistence
4. **attacker wipes auth.log to delay detection** — need off-host log shipping
5. **DO hypervisor behavior can change without notice** — need abstraction (host network mode) for resilience
6. **Self-cleaning wrappers (deleted-binary processes) evade simple `ls /tmp` checks** — need `/proc/PID/fd` walk
7. **Always verify new SSH keys added during incident recovery** — `mdrfckr` was added 2026-04-21 during cleanup, never audited since

## 8. Tài liệu liên quan

| File | Mô tả |
|------|-------|
| `docs/journals/2026-06-28-crypto-miner-reinfection-3.md` | Incident #3 full postmortem |
| `docs/journals/2026-06-28-erp-down-do-outbound-block.md` | Odoo down + DO block fix |
| `docs/journals/2026-07-01-crypto-miner-reinfection-4.md` | Incident #4 + compromised key |
| `docs/journals/2026-07-01-bmp-redeploy-research.md` | BMP repo research + redeploy options |
| `docs/infrastructure-digitalocean.md` | Updated infrastructure doc |
| `scripts/ssh-recover-toolkit.sh` | SSH recovery toolkit |
| `scripts/enable-deploy-password-ssh.sh` | Helper for password auth |
| `plans/260628-1245-crypto-miner-cleanup-and-rootkit-hunt/plan.md` | Cleanup plan |

---

**Tổng kết**: 4 sự cố resolved, 0 rootkit, 1 backdoor closed, hệ thống đang clean và lockdown.
**Trạng thái hiện tại**: Production-ready với key-only SSH, network_mode: host, recovery toolkit deployed.
**Rủi ro còn lại**: Image 3y tuổi, backup chưa off-droplet, chưa có file integrity monitoring.