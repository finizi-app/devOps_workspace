#!/usr/bin/env bash
#
# enable-deploy-password-ssh.sh
#
# Bật password authentication cho user `deploy` trên DigitalOcean Odoo droplet,
# giữ song song key auth (PubkeyAuthentication yes).
#
# Context: docs/infrastructure-digitalocean.md
# - Port 2222 primary, 22 fallback
# - fail2ban hiện DISABLED nên password không có auto-ban
# - Đảo ngược hardening "SSH key-only auth" sau incident 2026-03-01
#
# Usage:
#   ssh -p 2222 -i ~/.ssh/id_ed25519 deploy@146.190.104.85 \
#     'bash -s' < scripts/enable-deploy-password-ssh.sh
#
# Sau khi chạy:
#   - Test password login ở terminal MỚI trước khi đóng session hiện tại
#   - Update docs/infrastructure-digitalocean.md với password mới

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: chạy với sudo (script cần set password + edit /etc/ssh/sshd_config + reload sshd)"
  echo "Re-run: sudo bash $0"
  exit 1
fi

DEPLOY_USER="deploy"
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak.$(date +%Y%m%d-%H%M%S)"

echo "=== [1/6] Generate password (24 chars) ==="
NEW_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#%^*()-_=+' </dev/urandom | head -c 24)
echo "Password sẽ được set cho ${DEPLOY_USER}: ${NEW_PASSWORD}"
echo "(ghi lại ngay - script không lưu file)"
echo ""

echo "=== [2/6] Set password cho ${DEPLOY_USER} ==="
echo "${DEPLOY_USER}:${NEW_PASSWORD}" | chpasswd
echo "OK"
echo ""

echo "=== [3/6] Backup ${SSHD_CONFIG} ==="
cp -p "${SSHD_CONFIG}" "${BACKUP}"
chmod 600 "${BACKUP}"
echo "Backup: ${BACKUP}"
echo ""

echo "=== [4/6] Bật PasswordAuthentication (giữ PubkeyAuthentication) ==="
# Đảm bảo PasswordAuthentication yes
if grep -qE '^[[:space:]]*#?[[:space:]]*PasswordAuthentication' "${SSHD_CONFIG}"; then
  sed -i 's/^[[:space:]]*#\?[[:space:]]*PasswordAuthentication.*/PasswordAuthentication yes/' "${SSHD_CONFIG}"
else
  echo "PasswordAuthentication yes" >> "${SSHD_CONFIG}"
fi

# Đảm bảo PubkeyAuthentication yes (giữ key auth làm fallback)
if grep -qE '^[[:space:]]*#?[[:space:]]*PubkeyAuthentication' "${SSHD_CONFIG}"; then
  sed -i 's/^[[:space:]]*#\?[[:space:]]*PubkeyAuthentication.*/PubkeyAuthentication yes/' "${SSHD_CONFIG}"
else
  echo "PubkeyAuthentication yes" >> "${SSHD_CONFIG}"
fi

echo "Effective config:"
grep -E '^(#?\s*)?(Password|Pubkey|UsePAM|ChallengeResponse)Authentication' "${SSHD_CONFIG}" || echo "(no matching lines)"
echo ""

echo "=== [5/6] Validate sshd config (sshd -t) ==="
if sshd -t; then
  echo "sshd -t: OK"
else
  echo "ERROR: sshd -t failed. Restoring backup."
  cp -p "${BACKUP}" "${SSHD_CONFIG}"
  exit 2
fi
echo ""

echo "=== [6/6] Reload sshd (giữ session hiện tại) ==="
systemctl reload sshd
echo "sshd reloaded"
echo ""

echo "============================================================"
echo "DONE. Password mới cho ${DEPLOY_USER}:"
echo ""
echo "    ${NEW_PASSWORD}"
echo ""
echo "============================================================"
echo ""
echo "TEST NGAY Ở TERMINAL MỚI (không đóng session hiện tại):"
echo ""
echo "  ssh -p 2222 -o PubkeyAuthentication=no -o PreferredAuthentications=password ${DEPLOY_USER}@146.190.104.85"
echo ""
echo "Nếu login OK mới đóng session key hiện tại."
echo "Nếu fail: restore backup ${BACKUP} và reload lại."
echo ""
echo "Sau khi verify thành công, update docs/infrastructure-digitalocean.md:"
echo "  - 'Deploy password' → giá trị mới ở trên"
echo "  - Security → Hardening: bỏ dòng 'SSH key-only auth' hoặc note 'key + password'"
echo "  - Recovery section: dùng password thay vì key nếu muốn"