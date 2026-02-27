#!/usr/bin/env bash
# MIFA-VPN-basic uninstall script
set -euo pipefail

info() { echo "[INFO] $*"; }
ok()   { echo "[OK] $*"; }
err()  { echo "[ERROR] $*" >&2; }

if [[ "${EUID}" -ne 0 ]]; then
  err "Запусти с sudo или от root"
  exit 1
fi

read -r -p "Удалить Xray и конфигурацию? (y/N): " CONFIRM
CONFIRM="${CONFIRM:-N}"

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  info "Отменено."
  exit 0
fi

info "Останавливаем сервис..."
systemctl stop xray 2>/dev/null || true
systemctl disable xray 2>/dev/null || true

info "Удаляем конфиги и логи..."
rm -rf /usr/local/etc/xray
rm -rf /var/log/xray

if command -v xray >/dev/null 2>&1; then
  info "Удаляем бинарник Xray..."
  rm -f /usr/local/bin/xray 2>/dev/null || true
fi

ok "Удаление завершено."

echo
echo "Если использовался официальный installer,"
echo "можно также выполнить:"
echo "  bash -c \"\$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)\" @ remove"
