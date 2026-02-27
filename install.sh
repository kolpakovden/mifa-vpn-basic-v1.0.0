#!/usr/bin/env bash
# MIFA-VPN-basic installer (minimal)
# Installs Xray + generates VLESS Reality config + starts service
set -euo pipefail

# --- helpers ---
info()  { echo -e "ℹ️  $*"; }
ok()    { echo -e "✅ $*"; }
err()   { echo -e "❌ $*" >&2; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Запусти с sudo или от root"
    exit 1
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Не найдено: $1"; exit 1; }
}

port_free() {
  # ss preferred, fallback netstat if exists
  if command -v ss >/dev/null 2>&1; then
    ss -tuln | awk '{print $5}' | grep -qE ':(443)$' && return 1 || return 0
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln | awk '{print $4}' | grep -qE ':(443)$' && return 1 || return 0
  fi
  # If no tool to check, don't block install
  return 0
}

# --- main ---
require_root
need_cmd curl
need_cmd openssl

if ! port_free; then
  err "Порт 443 занят. Освободи его (nginx/apache/другой сервис) и повтори."
  exit 1
fi
ok "Порт 443 свободен"

info "Устанавливаем Xray (официальный installer)..."
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
need_cmd xray
ok "Xray установлен"

info "Генерируем UUID/keys/shortId..."
KEYS="$(xray x25519)"
PRIVATE_KEY="$(echo "$KEYS" | awk '/Private/{print $3}')"
PUBLIC_KEY="$(echo "$KEYS"  | awk '/Public/{print $3}')"
UUID="$(xray uuid)"
SHORT_ID="$(openssl rand -hex 8)"

SERVER_IP="$(curl -fsSL https://api.ipify.org || true)"
SERVER_IP="${SERVER_IP:-YOUR_SERVER_IP}"

info "Пишем конфиг..."
install -d /usr/local/etc/xray /var/log/xray

cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "flow": "xtls-rprx-vision"
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "target": "www.microsoft.com:443",
        "serverNames": ["www.microsoft.com"],
        "privateKey": "$PRIVATE_KEY",
        "shortIds": ["$SHORT_ID"]
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

# permissions: prefer xray user if exists
XRAY_USER="xray"
if ! id "$XRAY_USER" >/dev/null 2>&1; then
  XRAY_USER="nobody"
fi
XRAY_GROUP="$(id -gn "$XRAY_USER" 2>/dev/null || echo "$XRAY_USER")"

chown -R "$XRAY_USER:$XRAY_GROUP" /usr/local/etc/xray /var/log/xray || true
chmod 640 /usr/local/etc/xray/config.json || true
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

# Client link (publicKey is for client only)
VLESS_LINK="vless://${UUID}@${SERVER_IP}:443?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=chrome&sni=www.microsoft.com&sid=${SHORT_ID}&flow=xtls-rprx-vision#MIFA-VPN-basic"

echo
ok "Данные для клиента:"
echo "UUID:      $UUID"
echo "PublicKey: $PUBLIC_KEY"
echo "ShortID:   $SHORT_ID"
echo "Server IP: $SERVER_IP"
echo
echo "VLESS URI:"
echo "$VLESS_LINK"
echo
info "Логи: journalctl -u xray -f"
info "Access: /var/log/xray/access.log"
