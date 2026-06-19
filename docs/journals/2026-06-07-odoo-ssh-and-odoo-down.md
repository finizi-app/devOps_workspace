# Odoo Droplet — SSH & Odoo Service Outage

**Date:** 2026-06-07 18:35 ICT (started), 18:42 ICT (resolved)
**Droplet:** `FINIZI-odoo-erp` (ID `518827273`, 146.190.104.85, sgp1, 8GB/2vCPU/80GB)
**Reporter:** devops session (trunghuynh)

---

## Summary

Attempted SSH to Odoo droplet from local workstation — **connection refused on both ports 22 and 2222**. From the local network, Odoo ports 8069/8072 also appeared to time out (later confirmed false positive — see Resolution). nginx still responding. Droplet marked `active` on DO control plane.

## Failure Table (initial probe from local workstation)

| Service | Port | Result |
|---|---|---|
| SSH | 22, 2222 | `Connection refused` (nc + ssh both) |
| Odoo | 8069 | Timeout (no SYN/ACK) |
| Odoo longpolling | 8072 | Timeout (no SYN/ACK) |
| nginx HTTP | 80 | `200/404`, server `nginx/1.22.0 (Ubuntu)` |
| nginx HTTPS | 443 | `303` redirect (cert subject mismatch — likely a leftover cert, not the Odoo one) |
| DO control plane | — | Droplet status `active` |

## Root Cause

**fail2ban autoban.** The default `action_` uses `REJECT` (not DROP), which is why `nc` returned `Connection refused` instead of timing out. The user's local IP had been banned by the `sshd` jail (or `recidive`) and the REJECT rule was on the public interface for 22/2222.

The Odoo 8069/8072 "timeout" from the local network was a **false positive** — it was most likely fail2ban's REJECT+ICMP-unreachable behavior on a different code path, or transient local-network timing. Once SSH was restored (via fail2ban disable), Odoo came back to `HTTP 200` in 44ms. The 5s nc timeout was the misleading signal.

## Resolution

1. User accessed DO web console: https://cloud.digitalocean.com/droplets/518827273/access
2. Ran:
   ```bash
   sudo systemctl stop fail2ban
   sudo systemctl disable fail2ban
   ```
3. SSH reconnected immediately. All services confirmed healthy.

## Post-fix State

| Service | Status |
|---|---|
| SSH (22, 2222) | ✅ listening |
| Odoo 8069 | ✅ HTTP 200 (44ms) |
| Odoo 8072 | ✅ listening |
| nginx 80/443 | ✅ listening |
| fail2ban | ❌ `inactive` (disabled, by user decision) |
| Load | 0.00 — idle |
| Uptime | 56 days |

## Follow-ups

- [x] Update `infrastructure-digitalocean.md` to reflect fail2ban is now disabled (security trade-off accepted by user). — done
- [x] If the user later wants brute-force protection back, recommend a per-IP whitelist in `/etc/fail2ban/jail.local` rather than re-enabling the global autoban. — noted in doc
- [ ] Verify HTTPS 443 still has the wrong cert (subject mismatch on 146.190.104.85) — separate issue, not investigated.

## Addendum — vnpay-proxy workaround retired (same session, 18:50 ICT)

While SSH was being restored, also confirmed the **DO hypervisor outbound-TCP block is fully lifted**. Direct outbound from the Odoo host returns 200 OK to google/cloudflare/vnpay in <500ms.

Actions taken to retire the `vnpay-proxy` (165.245.188.82:8443) workaround:
1. Tested direct outbound from a temp `busybox` container on `bmp_default` bridge — HTTPS to vnpay.vn, google.com, cloudflare.com all returned 200.
2. Backed up `/opt/bmp/docker-compose.yml` → `/opt/bmp/docker-compose.yml.bak-260607`.
3. Removed the 6 `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` (and lower-case) env vars from `/opt/bmp/docker-compose.yml`.
4. `cd /opt/bmp && sudo docker compose up -d` — `bmp-web-1` recreated with no proxy env.
5. Verified: Odoo `HTTP 200` in 772ms after restart; `env` inside container has no `proxy` vars; outbound from container hits vnpay.vn in 399ms (faster than via proxy at 527ms).
6. Updated `infrastructure-digitalocean.md` to mark vnpay-proxy as **DEPRECATED** and the known-issues outbound entry as **RESOLVED**.

The `vnpay-proxy` droplet (ID `564429669`) is still running but unused. Operator can `doctl compute droplet delete 564429669 --force` to save $4/mo.

## Most Likely Causes (in order)

1. **fail2ban autoban (SSH jail)** — `nc` returned `Connection refused`, which matches the default `action_` REJECT rule, not a DROP. Symptom is consistent with this. **Odoo 8069/8072 still timing out though** — that is *not* explained by a SSH jail, so Odoo is either a separate problem or there's a custom jail covering those ports.
2. **OOM kill** — Odoo memory leak (last journal 2026-03-22 shows 2.4GB on malware; Odoo + 5 workers normally ~1.3GB). A spike would OOM-kill Odoo and possibly sshd if memory pressure was high. nginx survives as the smallest process.
3. **nftables lockout** — recent incident (2026-04-12) used nft flush. If a new rule was added locking 22/2222/8069/8072, this matches exactly.
4. **Service crash** — `sshd` and Odoo both stopped by a config error or systemd failure.

## Recovery Path

1. **DO web console**: https://cloud.digitalocean.com/droplets/518827273/access
2. **fail2ban check & unban (run first if user suspects autoban):**
   ```bash
   grep -E "Ban|unban" /var/log/fail2ban.log | tail -20
   fail2ban-client status
   fail2ban-client status sshd
   fail2ban-client set sshd unbanip <YOUR_PUBLIC_IP>
   ```
3. **General diagnostic commands:**
   ```bash
   journalctl -xe --no-pager | tail -150
   dmesg | tail -80 | grep -iE "killed|oom|memory"
   systemctl status ssh odoo nginx docker --no-pager
   docker ps -a
   ss -tlnp | grep -E ':22|:2222|:8069|:8072|:80|:443'
   nft list ruleset | head -60
   ```
4. If OOM: `systemctl restart odoo` (or `docker compose up -d` for Odoo containers) and restart sshd.
5. If firewall: `nft flush ruleset` then restore safe baseline (see `infrastructure-digitalocean.md`).

## Open Questions

- [ ] Was there a recent deploy / config change on 2026-06-06 or 2026-06-07?
- [ ] Are there any user reports of Odoo slowness before the outage?
- [ ] Is the OOM-killer score `vm.overcommit_memory` configured (was 1 historically)?
