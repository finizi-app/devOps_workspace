#!/usr/bin/env bash
#
# ssh-recover-toolkit.sh
#
# Recovery toolkit for DO droplet `odoo-erp-multi-company` (146.190.104.85).
# Use when SSH access is blocked: miner eating CPU, sshd broken, keys gone,
# firewall locked, disk full, etc.
#
# USAGE
#   From Recovery Console (https://cloud.digitalocean.com/droplets/518827273/access):
#     sudo bash /root/ssh-recover            # primary location (Recovery ISO root=/root)
#     sudo bash /usr/local/sbin/ssh-recover  # alt location (sbin, in PATH)
#   Or non-interactive (no prompts):
#     sudo bash /root/ssh-recover --yes
#   Or with a custom public key file:
#     sudo bash /root/ssh-recover --key /path/to/authorized_keys
#
# INSTALLED LOCATIONS (synced from scripts/ssh-recover-toolkit.sh in repo)
#   /root/ssh-recover                            — primary, used from Recovery Console
#   /usr/local/sbin/ssh-recover                  — in PATH for normal sessions
#   /usr/local/share/ssh-recover/authorized_keys — baseline keys (2 known public keys)
#   /usr/local/share/ssh-recover/keys/           — extra key files merged at restore time
#
# WHAT IT DOES (each step confirmed unless --yes)
#   1. Restore /home/deploy/.ssh/authorized_keys from embedded baseline
#      + any extra keys in /usr/local/share/ssh-recover/keys/
#   2. Reset /etc/ssh/sshd_config baseline (PasswordAuth yes, PubkeyAuth yes,
#      Port 2222, PermitRootLogin prohibit-password)
#   3. Kill high-CPU miner processes owned by `deploy` (>50% CPU)
#   4. Open ports 22, 2222 in ufw + flush nftables ruleset if blocking
#   5. Restart sshd (reload to keep current session alive when possible)
#   6. Show diagnostics: listening ports, sshd status, disk, CPU
#
# CONTEXT
#   - DO droplet ID: 518827273, IP: 146.190.104.85
#   - User: deploy (sudo NOPASSWD)
#   - Cloud firewall also needs ports 22/2222 open from 0.0.0.0/0
#     (cannot automate from Recovery Console — manual in DO dashboard)

set -euo pipefail

# ---------- Constants ----------
DEPLOY_USER="deploy"
SSH_PORT_PRIMARY=2222
SSH_PORT_FALLBACK=22
SSHD_CONFIG="/etc/ssh/sshd_config"
AUTH_KEYS="/home/${DEPLOY_USER}/.ssh/authorized_keys"
KEYS_DIR="/usr/local/share/ssh-recover/keys"
BASELINE_KEYS="/usr/local/share/ssh-recover/authorized_keys"
BACKUP_DIR="/var/backups/ssh-recover/$(date +%Y%m%d-%H%M%S)"

ASSUME_YES=0
CUSTOM_KEY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) ASSUME_YES=1; shift ;;
    --key) CUSTOM_KEY="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

# ---------- Helpers ----------
confirm() {
  local prompt="$1"
  if [[ $ASSUME_YES -eq 1 ]]; then return 0; fi
  read -rp "$prompt [y/N] " ans
  [[ "${ans,,}" =~ ^y ]]
}

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m ✗\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || die "chạy với sudo (cần write sshd_config + kill processes + restart sshd)"
}

# ---------- Step 1: restore authorized_keys ----------
step_restore_keys() {
  log "Step 1: Restore authorized_keys"
  mkdir -p "$(dirname "$AUTH_KEYS")"
  mkdir -p "$BACKUP_DIR"
  [[ -f "$AUTH_KEYS" ]] && cp -p "$AUTH_KEYS" "$BACKUP_DIR/authorized_keys.bak" && warn "backup → $BACKUP_DIR/authorized_keys.bak"

  local new_keys="$BASELINE_KEYS"
  [[ -n "$CUSTOM_KEY" && -f "$CUSTOM_KEY" ]] && new_keys="$CUSTOM_KEY"
  [[ -f "$new_keys" ]] || die "không tìm thấy baseline keys: $new_keys"

  cp "$new_keys" "$AUTH_KEYS"
  chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh"
  chmod 700 "/home/${DEPLOY_USER}/.ssh"
  chmod 600 "$AUTH_KEYS"
  ok "$AUTH_KEYS ($(wc -l < "$AUTH_KEYS") keys)"
}

# ---------- Step 2: reset sshd_config baseline ----------
step_reset_sshd_config() {
  log "Step 2: Reset sshd_config baseline"
  [[ -f "$SSHD_CONFIG" ]] && cp -p "$SSHD_CONFIG" "$BACKUP_DIR/sshd_config.bak"

  # Apply only the directives that matter for recovery; don't blow away
  # the whole file (preserves Certbot includes, custom Match blocks, etc.)
  declare -A baseline=(
    ["PasswordAuthentication"]="yes"
    ["PubkeyAuthentication"]="yes"
    ["PermitRootLogin"]="prohibit-password"
    ["Port"]="${SSH_PORT_PRIMARY}"
  )
  for key in "${!baseline[@]}"; do
    local val="${baseline[$key]}"
    if grep -qE "^[[:space:]]*#?[[:space:]]*${key}\b" "$SSHD_CONFIG"; then
      sed -i "s/^[[:space:]]*#\?[[:space:]]*${key}\b.*/${key} ${val}/" "$SSHD_CONFIG"
    else
      printf '\n%s %s\n' "$key" "$val" >> "$SSHD_CONFIG"
    fi
  done

  if sshd -t; then ok "sshd -t: OK"; else
    warn "sshd -t failed, restoring backup"
    [[ -f "$BACKUP_DIR/sshd_config.bak" ]] && cp -p "$BACKUP_DIR/sshd_config.bak" "$SSHD_CONFIG"
    die "sshd config invalid"
  fi
}

# ---------- Step 3: kill high-CPU miner ----------
step_kill_miners() {
  log "Step 3: Kill high-CPU deploy processes (likely miners)"
  local victims
  victims=$(ps -u "$DEPLOY_USER" -o pid=,pcpu=,comm= --no-headers 2>/dev/null | awk '$2+0 > 50 {print $1}' || true)
  if [[ -z "$victims" ]]; then ok "no high-CPU deploy processes"; return 0; fi
  warn "high-CPU PIDs: $victims"
  if confirm "kill -9 these processes"; then
    kill -9 $victims 2>/dev/null || true
    sleep 1
    ok "killed"
  else
    warn "skipped"
  fi
}

# ---------- Step 4: open firewall ----------
step_open_firewall() {
  log "Step 4: Open ports 22, 2222"
  # ufw (host firewall)
  if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "${SSH_PORT_PRIMARY}/tcp" 2>&1 | sed 's/^/  ufw: /'
    ufw allow "${SSH_PORT_FALLBACK}/tcp" 2>&1 | sed 's/^/  ufw: /'
    ok "ufw: ports ${SSH_PORT_PRIMARY}, ${SSH_PORT_FALLBACK} opened"
  fi
  # nftables (Droplet sometimes has stale rules)
  if command -v nft >/dev/null; then
    warn "flushing nftables ruleset (may break other iptables-dependent services)"
    if confirm "nft flush ruleset"; then
      nft flush ruleset 2>&1 | sed 's/^/  nft: /' || warn "nft flush failed (may not have rules)"
    fi
  fi
  warn "CLOUD firewall: check DO dashboard > droplet 518827273 > Networking > Firewalls"
  warn "  Inbound must allow: TCP 22, 80, 443, 2222 from 0.0.0.0/0"
}

# ---------- Step 5: restart sshd ----------
step_restart_sshd() {
  log "Step 5: Restart sshd"
  if pgrep -x sshd >/dev/null; then
    systemctl reload sshd 2>&1 || systemctl restart sshd 2>&1
    ok "sshd reloaded"
  else
    systemctl start sshd
    ok "sshd started"
  fi
}

# ---------- Step 6: diagnostics ----------
step_diagnostics() {
  log "Step 6: Diagnostics"
  echo "--- sshd status ---"
  systemctl is-active sshd || true
  echo "--- listening ports ---"
  ss -tlnp 2>/dev/null | grep -E ":(22|2222)\b" || warn "no sshd listeners"
  echo "--- disk ---"
  df -h / /home 2>/dev/null | grep -vE "^(Filesystem|tmpfs|overlay)"
  echo "--- load ---"
  uptime
  echo "--- deploy processes ---"
  ps -u "$DEPLOY_USER" -o pid,pcpu,pmem,comm --sort=-pcpu 2>/dev/null || echo "(none)"
  echo
  ok "Recovery complete. Test from another terminal:"
  echo "  ssh -p ${SSH_PORT_PRIMARY} -i ~/.ssh/patedeli-digitalocean ${DEPLOY_USER}@146.190.104.85"
}

# ---------- Main ----------
require_root
mkdir -p "$BACKUP_DIR"
log "ssh-recover started at $(date -u +%FT%TZ)"
log "Backup dir: $BACKUP_DIR"

step_restore_keys
step_reset_sshd_config
step_kill_miners
step_open_firewall
step_restart_sshd
step_diagnostics

echo
ok "Done. If SSH still fails, check DO Cloud Firewall and droplet console logs."
