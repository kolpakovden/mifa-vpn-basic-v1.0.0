#!/usr/bin/env bash
# MIFA-VPN-basic (RU-friendly) installer
# Xray (VLESS + Reality) + systemd
# Default port: 8443 (override via flags)
set -euo pipefail

DEFAULT_PORT="8443"
DEFAULT_SNI="www.cloudflare.com"
DEFAULT_TARGET="www.cloudflare.com:443"
FINGERPRINT="chrome"

# --- helpers ---
info() { echo "[INFO] $*"; }
ok()   { echo "[OK] $*"; }
err()  { echo "[ERROR] $*" >&2; }

usage() {
  cat <<EOF
MIFA-VPN-basic installer (RU-friendly)

Usage:
  sudo bash install.sh
  sudo bash install.sh --8443
  sudo bash install.sh --443
  sudo bash install.sh --port 12345
  sudo bash install.sh --sni example.com --target example.com:443
  sudo bash install.sh --non-interactive [--port N|--443|--8443] [--sni DOMAIN] [--target HOST:PORT]

Options:
  --port N             Set inbound port
  --443                Preset port 443
  --8443               Preset port 8443
  --sni DOMAIN         Reality serverName / client SNI (default: ${DEFAULT_SNI})
  --target HOST:PORT   Reality target (default: ${DEFAULT_TARGET})
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

validate_sni() {
  # simple domain check (letters, digits, dots, hyphens)
  local d="$1"
  [[ "$d" =~ ^[A-Za-z0-9.-]+$ ]] && [[ "$d" == *.* ]] && [[ ${#d} -le 253 ]]
}

validate_target() {
  # HOST:PORT (HOST can be domain; PORT numeric)
  local t="$1"
  [[ "$t" == *:* ]] || return 1
  local host="${t%:*}"
  local port="${t##*:}"
  [[ -n "$host" ]] || return 1
  validate_port "$port" || return 1
  [[ "$host" =~ ^[A-Za-z0-9.-]+$ ]] || return 1
  return 0
}

install_xray() {
  if command -v xray >/dev/null 2>&1; then
    ok "Xray уже установлен"
    return 0
  fi

  info "Пробуем установить Xray через APT (deb.xray.guru)..."
  if curl -fsSL --max-time 8 https://deb.xray.guru >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y ca-certificates gnupg >/dev/null

    curl -fsSL https://deb.xray.guru/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/xray-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/xray-archive-keyring.gpg] https://deb.xray.guru stable main" \
      > /etc/apt/sources.list.d/xray.list

    apt-get update -y
    apt-get install -y xray
  else
    info "APT-репозиторий недоступен. Пробуем официальный GitHub installer..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
  fi

  need_cmd xray
  ok "Xray установлен"
}

# --- parse args ---
PORT=""
NON_INTERACTIVE="0"
SNI="$DEFAULT_SNI"
TARGET="$DEFAULT_TARGET"

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
    --sni)
      shift
      SNI="${1:-}"
      ;;
    --target)
      shift
      TARGET="${1:-}"
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

if ! validate_sni "$SNI"; then
  err "Некорректный SNI: $SNI"
  exit 1
fi

if ! validate_target "$TARGET"; then
  err "Некорректный target: $TARGET (пример: example.com:443)"
  exit 1
fi

# --- main ---
require_root
need_cmd curl
need_cmd openssl
need_cmd systemctl
need_cmd sed
need_cmd tr

if ! is_port_free "$PORT"; then
  err "Порт ${PORT} занят. Освободи его и повтори."
  exit 1
fi
ok "Порт ${PORT} свободен"

info "Параметры Reality: SNI=${SNI}, target=${TARGET}"
info "Устанавливаем Xray..."
install_xray

info "Генерируем UUID / Reality keys / shortId..."
KEYS="$(xray x25519 2>&1 | tr -d '\r')"

# New format (v26+): PrivateKey / Password / Hash32
PRIVATE_KEY="$(printf '%s\n' "$KEYS" | sed -nE 's/^PrivateKey:[[:space:]]*//p' | head -n1)"
PBK_OR_PASSWORD="$(printf '%s\n' "$KEYS" | sed -nE 's/^Password:[[:space:]]*//p'  | head -n1)"

# Old format (legacy): "Private key:" / "Public key:"
if [[ -z "$PRIVATE_KEY" ]]; then
  PRIVATE_KEY="$(printf '%s\n' "$KEYS" | sed -nE 's/^Private key:[[:space:]]*//p' | head -n1)"
fi
if [[ -z "$PBK_OR_PASSWORD" ]]; then
  PBK_OR_PASSWORD="$(printf '%s\n' "$KEYS" | sed -nE 's/^Public key:[[:space:]]*//p' | head -n1)"
fi

if [[ -z "$PRIVATE_KEY" || -z "$PBK_OR_PASSWORD" ]]; then
  err "Не удалось распарсить ключи из 'xray x25519'. Вывод:"
  echo "$KEYS"
  exit 1
fi

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
        "target": "${TARGET}",
        "serverNames": ["${SNI}"],
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

VLESS_LINK="vless://${UUID}@${SERVER_IP}:${PORT}?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=${FINGERPRINT}&sni=${SNI}&sid=${SHORT_ID}&flow=xtls-rprx-vision#MIFA-VPN-basic"

echo
ok "Данные для клиента:"
echo "Port:      ${PORT}"
echo "SNI:       ${SNI}"
echo "Target:    ${TARGET}"
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
