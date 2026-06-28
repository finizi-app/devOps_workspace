# erp.patedeli.com Down — DO Hypervisor Outbound Block on Docker Bridge

## Summary

`erp.patedeli.com` unreachable from 2026-06-28 ~06:00 ICT. Odoo container
`bmp-web-1` running but all workers dying on `psycopg2.OperationalError:
Connection timed out` to managed DO Postgres cluster. Root cause: **DO
hypervisor blocks outbound TCP from Docker bridge IPs (172.18.0.0/16)**
while host outbound works. Fix: switch Odoo to `network_mode: host`.
Resolved in ~15 min.

## Timeline (ICT)

| Time | Event |
|------|-------|
| 06:14 | Odoo container recreated (auto-restart?) — `Started: 2026-06-28T06:14:57` |
| 06:14+ | Odoo workers spawn, all fail to connect Postgres `159.223.51.178:25060` |
| ~06:00-09:00 | nginx upstream timeouts logged for `erp.patedeli.com` (visible in error.log) |
| ~08:30 | Operator reports `erp.patedeli.com` down |
| 09:01 | Container recreated with `network_mode: host` |
| 09:01:23 | First successful Odoo HTTP response (303) from `42.112.181.61` |

## Root Cause

### Symptom
- Container `bmp-web-1` "Up" but HTTP 000 from loopback + external
- nginx error log: `upstream timed out (110: Connection timed out)` for
  `http://0.0.0.0:8069/web`
- Odoo log: `psycopg2.OperationalError: could not connect to server:
  Connection timed out ... host "bmp-postgres-cluster-..." (159.223.51.178)`
- All workers exit; only WorkerCron stays alive (no DB needed for cron)

### Diagnosis
`tcpdump -i eth0` showed:

| Source | Target | SYN sent | SYN-ACK received |
|--------|--------|----------|------------------|
| `146.190.104.85` (host) | `159.223.51.178:25060` | ✅ | ✅ |
| `172.18.0.2` (container) | `159.223.51.178:25060` | ✅ | ❌ |
| `172.18.0.2` (container) | `8.8.8.8:53` | ✅ | ❌ |
| `172.18.0.2` (container) | `1.1.1.1:443` | ✅ | ❌ |
| `172.18.0.2` (container) | `146.190.104.85:443` (own) | ✅ | ✅ |

**Conclusion**: DO hypervisor filters SYN-ACK responses to non-host source
IPs. SYN packets egress eth0 (host kernel allows), but the external side
(likely DO DDoS protection layer) drops responses when source is in
`172.18.0.0/16`.

This is **regression of incident 2026-04-12** (DO outbound block during
DDoS). The block was partially lifted (host outbound restored ~Jun 7) but
container bridge IPs still filtered. Container restart at 06:14 likely
triggered re-evaluation by DO's heuristics.

## Fix Applied

`/opt/bmp/docker-compose.yml`:

```diff
   web:
     image: bmp:latest
+    network_mode: host
-    ports:
-      - "8069:8069"
-      - "8072:8072"
     volumes:
       - odoo-web-data:/var/lib/odoo
       - ./config:/etc/odoo
       ...
```

Then:
```bash
cd /opt/bmp && docker compose down && docker compose up -d
```

Container now shares host's network stack. Outbound uses host IP
`146.190.104.85` (allowed by DO).

### Verification
- `WorkerHTTP (11/13/14) alive` + `WorkerCron (18) alive`
- `Evented Service (longpolling) running on 0.0.0.0:8072`
- `127.0.0.1:8069` → 303 in 0.69s
- `erp.patedeli.com/web/login` → 200 in 0.52s

### Backup
- `/opt/bmp/docker-compose.yml.bak.20260628-0901` (pre-fix version retained)

## Open Questions

- Will Odoo still work if DO fully lifts the block? Yes — `network_mode: host`
  is functionally equivalent for this use case (no port mapping needed since
  8069/8072 are not 80/443).
- Why did Odoo container restart at 06:14? Possibly OOM, manual restart, or
  Odoo auto-failover. Not investigated (low priority — fixed and working).
- Should we file DO support ticket? Recommended — ask DO to verify whether
  the bridge IP filter is intentional. If intentional, this workaround
  becomes permanent; if a bug, fixing it lets us revert to bridge network.
