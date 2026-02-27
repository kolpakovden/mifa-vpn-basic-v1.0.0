#!/usr/bin/env bash

# MIFA-VPN Production Installer
# Version: 2.0 (production)
# License: MIT

set -euo pipefail

########################################
# Colors
########################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

########################################
# UI Functions
########################################
print_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}➡ ${NC}${YELLOW}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() { echo -e "${GREEN}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_info() { echo -e "${BLUE}$1${NC}"; }

########################################
# Root Check
########################################
if [[ "${EUID}" -ne 0 ]]; then
    print_error "Запустите скрипт с sudo или от root"
    exit 1
fi

########################################
# systemd Check
########################################
if ! command -v systemctl &>/dev/null; then
    print_error "Systemd не найден. Поддерживаются только systemd-системы."
    exit 1
fi

########################################
# Dependencies Check
########################################
print_step "Проверка зависимостей"

for cmd in curl openssl ss; do
    if ! command -v $cmd &>/dev/null; then
        print_error "$cmd не установлен. Установите и повторите запуск."
        exit 1
    fi
done

print_success "Все зависимости установлены"

########################################
# Port Check
########################################
print_step "Проверка порта 443"

if ss -tulnp | grep -q ":443 "; then
    print_error "Порт 443 уже занят. Освободите его перед установкой."
    exit 1
fi

print_success "Порт 443 свободен"

########################################
# Install Xray
########################################
print_step "Установка Xray"

bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

if ! command -v xray &>/dev/null; then
    print_error "Xray не установлен!"
    exit 1
fi

print_success "Xray успешно установлен"

########################################
# Generate Credentials
########################################
print_step "Генерация ключей и UUID"

KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | awk '/Private/{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | awk '/Public/{print $3}')
UUID=$(xray uuid)
SHORT_ID=$(openssl rand -hex 8)

print_success "Ключи успешно сгенерированы"

########################################
# Detect Public IP
########################################
SERVER_IP=$(curl -fsSL https://api.ipify.org || echo "YOUR_SERVER_IP")

########################################
# Create Config
########################################
print_step "Создание конфигурации"

print_info "Генерация ключей Reality и UUID..."

KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | awk '/Private/{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | awk '/Public/{print $3}')
UUID=$(xray uuid)
SHORT_ID=$(openssl rand -hex 8)

SERVER_IP=$(curl -fsSL https://api.ipify.org || echo "YOUR_SERVER_IP")

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

print_success "Конфигурация создана автоматически"

########################################
# Permissions
########################################
print_step "Настройка прав"

if id xray &>/dev/null; then
    XRAY_USER="xray"
else
    XRAY_USER="nobody"
fi

chown -R $XRAY_USER:$XRAY_USER /usr/local/etc/xray
chown -R $XRAY_USER:$XRAY_USER /var/log/xray
chmod 640 /usr/local/etc/xray/config.json

print_success "Права настроены"

########################################
# Firewall (UFW optional)
########################################
if command -v ufw &>/dev/null; then
    ufw allow 443/tcp || true
fi

########################################
# Validate Config
########################################
print_step "Проверка конфигурации"

if ! xray run -test -config /usr/local/etc/xray/config.json; then
    print_error "Конфиг содержит ошибки!"
    exit 1
fi

print_success "Конфигурация валидна"

########################################
# Start Service
########################################
print_step "Запуск сервиса"

systemctl daemon-reload
systemctl enable xray
systemctl restart xray

sleep 2

if ! systemctl is-active --quiet xray; then
    print_error "Xray не запустился!"
    systemctl status xray --no-pager
    exit 1
fi

print_success "Xray успешно запущен"

########################################
# Client Link
########################################
print_step "Данные для подключения"

VLESS_LINK="vless://${UUID}@${SERVER_IP}:443?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=chrome&sni=www.microsoft.com&sid=${SHORT_ID}&flow=xtls-rprx-vision#MIFA-VPN"

echo -e "${GREEN}UUID:${NC} $UUID"
echo -e "${GREEN}PublicKey:${NC} $PUBLIC_KEY"
echo -e "${GREEN}ShortID:${NC} $SHORT_ID"
echo -e "${GREEN}Server IP:${NC} $SERVER_IP"
echo
echo -e "${YELLOW}VLESS ссылка:${NC}"
echo -e "${BLUE}$VLESS_LINK${NC}"
echo
echo -e "${GREEN}Установка завершена успешно ${NC}"
