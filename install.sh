#!/usr/bin/env bash
# MIFA-VPN-basic (RU-friendly) installer
# Xray (VLESS + Reality) + systemd
# Default port: 8443 (override via flags)
set -euo pipefail

DEFAULT_PORT="8443"
TARGET_HOST="www.microsoft.com"
FINGERPRINT="chrome"

# --- helpers ---
info() { echo -e "ℹ️  $*"; }
ok()   { echo -e "✅ $*"; }
err()  { echo -e "❌ $*" >&2; }

usage() {
  cat <<'EOF'
MIFA-VPN-basic installer (RU-friendly)

Usage:
  sudo bash install.sh                 # interactive (default port 8443)
  sudo bash install.sh --8443          # preset port 8443
  sudo bash install.sh --443           # preset port 443
  sudo bash install.sh --port 12345    # custom port
  sudo bash install.sh --non-interactive [--port N|--443|--8443]

Options:
  --port N             Set inbound port
  --443                Preset port 443
  --8443               Preset port 8443
  --non-interactive    Do not prompt (use defaults/flags)
  -h, --help           Show help
EOF
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Запусти с sudo или от root"
    exit 1
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Не найдено: $1"; exit 1; }
}

is_port_free() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tuln | awk '{print $5}' | grep -qE ":(${p})$" && return 1 || return 0
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln | awk '{print $4}' | grep -qE ":(${p})$" && return 1 || return 0
  fi
  return 0
}

validate_port() {
  local p="$1"
  [[ "$p" =~ ^[0-9]+$ ]] || return 1
  (( p >= 1 && p <= 65535 )) || return 1
  return 0
}

# --- parse args ---
PORT=""
NON_INTERACTIVE="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      shift
      PORT="${1:-}"
      ;;
    --443)
      PORT="443"
      ;;
    --8443)
      PORT="8443"
      ;;
    --non-interactive)
      NON_INTERACTIVE="1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Неизвестный аргумент: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -z "${PORT}" ]]; then
  if [[ "$NON_INTERACTIVE" == "1" ]]; then
    PORT="$DEFAULT_PORT"
  else
    read -r -p "Введите порт (по умолчанию ${DEFAULT_PORT}): " PORT_INPUT
    PORT="${PORT_INPUT:-$DEFAULT_PORT}"
  fi
fi

if ! validate_port "$PORT"; then
  err "Некорректный порт: $PORT"
  exit 1
fi

# --- main ---
require_root
need_cmd curl
need_cmd openssl
need_cmd systemctl

if ! is_port_free "$PORT"; then
  err "Порт ${PORT} занят. Освободи его и повтори."
  exit 1
fi
ok "Порт ${PORT} свободен"

info "Устанавливаем Xray (официальный installer)..."
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
need_cmd xray
ok "Xray установлен"

info "Генерируем UUID / Reality keys / shortId..."
KEYS="$(xray x25519)"
PRIVATE_KEY="$(echo "$KEYS" | awk '/Private/{print $3}')"
PUBLIC_KEY="$(echo "$KEYS"  | awk '/Public/{print $3}')"
UUID="$(xray uuid)"
SHORT_ID="$(openssl rand -hex 8)"

SERVER_IP="$(curl -fsSL https://api.ipify.org || true)"
SERVER_IP="${SERVER_IP:-YOUR_SERVER_IP}"

info "Создаём конфиг..."
install -d /usr/local/etc/xray /var/log/xray

cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [{
    "port": ${PORT},
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "${UUID}",
        "flow": "xtls-rprx-vision"
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "target": "${TARGET_HOST}:443",
        "serverNames": ["${TARGET_HOST}"],
        "privateKey": "${PRIVATE_KEY}",
        "shortIds": ["${SHORT_ID}"]
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

# permissions (best-effort, distro differences allowed)
XRAY_USER="xray"
if ! id "$XRAY_USER" >/dev/null 2>&1; then
  XRAY_USER="nobody"
fi
XRAY_GROUP="$(id -gn "$XRAY_USER" 2>/dev/null || echo "$XRAY_USER")"

chown -R "$XRAY_USER:$XRAY_GROUP" /usr/local/etc/xray /var/log/xray 2>/dev/null || true
chmod 640 /usr/local/etc/xray/config.json 2>/dev/null || true

ok "Конфиг создан: /usr/local/etc/xray/config.json"

info "Проверяем конфиг..."
xray run -test -config /usr/local/etc/xray/config.json
ok "Конфиг валиден"

info "Запускаем сервис..."
systemctl enable xray >/dev/null
systemctl restart xray

if ! systemctl is-active --quiet xray; then
  err "Xray не запустился. Статус:"
  systemctl status xray --no-pager || true
  exit 1
fi
ok "Xray запущен"

VLESS_LINK="vless://${UUID}@${SERVER_IP}:${PORT}?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=${FINGERPRINT}&sni=${TARGET_HOST}&sid=${SHORT_ID}&flow=xtls-rprx-vision#MIFA-VPN-basic"

echo
ok "Данные для клиента:"
echo "Port:      ${PORT}"
echo "UUID:      ${UUID}"
echo "PublicKey: ${PUBLIC_KEY}"
echo "ShortID:   ${SHORT_ID}"
echo "Server IP: ${SERVER_IP}"
echo
echo "VLESS URI:"
echo "${VLESS_LINK}"
echo
info "Логи: journalctl -u xray -f"
info "Access: /var/log/xray/access.log"
