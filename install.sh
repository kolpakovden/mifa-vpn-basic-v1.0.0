#!/bin/bash

# MIFA-VPN-basic installer
# Версия: 1.0
# Лицензия: MIT

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для красивого вывода
print_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}➡ ${NC}${YELLOW}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    print_error "Пожалуйста, запустите с sudo или от root"
    exit 1
fi

# Приветствие
clear
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     MIFA-VPN-basic - Установка VLESS + Reality           ║"
echo "║                 Минимальная версия                       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Определение ОС
print_step "Определение операционной системы"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
    print_success "Обнаружена ОС: $PRETTY_NAME"
else
    print_error "Не удалось определить ОС"
    exit 1
fi

# Установка Xray
print_step "Установка Xray"
print_info "Загружаем официальный скрипт установки..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
print_success "Xray успешно установлен"

# Создание директорий
print_step "Подготовка директорий"
mkdir -p /usr/local/etc/xray
mkdir -p /var/log/xray
print_success "Директории созданы"

# Копирование конфига
print_step "Настройка конфигурации"
if [ -f ./config/example.config.json ]; then
    cp ./config/example.config.json /usr/local/etc/xray/config.json
    print_success "Базовый конфиг скопирован"
else
    print_error "Файл example.config.json не найден!"
    print_info "Создаём минимальный конфиг..."
    
    # Генерация временных ключей для примера
    TEMP_KEYS=$(xray x25519)
    PRIVATE_KEY=$(echo "$TEMP_KEYS" | grep "Private" | awk '{print $3}')
    PUBLIC_KEY=$(echo "$TEMP_KEYS" | grep "Public" | awk '{print $3}')
    SHORT_ID=$(openssl rand -hex 8)
    UUID=$(xray uuid)
    
    # Создаём базовый конфиг
    cat > /usr/local/etc/xray/config.json <<EOF
{
    "log": {
        "loglevel": "warning",
        "access": "/var/log/xray/access.log"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "flow": "xtls-rprx-vision",
                        "email": "user@example.com"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "target": "www.microsoft.com:443",
                    "xver": 0,
                    "serverNames": [
                        "www.microsoft.com"
                    ],
                    "privateKey": "$PRIVATE_KEY",
                    "publicKey": "$PUBLIC_KEY",
                    "shortIds": [
                        "$SHORT_ID"
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        }
    ]
}
EOF
    print_success "Создан минимальный конфиг с временными ключами"
fi

# Настройка прав
print_step "Настройка прав доступа"
chown -R nobody:nogroup /usr/local/etc/xray
chown -R nobody:nogroup /var/log/xray
chmod 644 /usr/local/etc/xray/config.json
print_success "Права настроены"

# Запуск Xray
print_step "Запуск Xray"
systemctl restart xray
systemctl enable xray
print_success "Xray запущен и добавлен в автозагрузку"

# Финальная информация
print_step "Установка завершена!"

echo -e "${GREEN}Xray успешно установлен и настроен!${NC}\n"

echo -e "${YELLOW}📝 Что нужно сделать дальше:${NC}"
echo -e "  ${BLUE}1.${NC} Отредактировать конфиг: ${GREEN}nano /usr/local/etc/xray/config.json${NC}"
echo -e "  ${BLUE}2.${NC} Сгенерировать свои ключи (обязательно!):"
echo -e "     ${GREEN}xray x25519${NC} - для получения private/public key"
echo -e "     ${GREEN}openssl rand -hex 8${NC} - для shortID"
echo -e "     ${GREEN}xray uuid${NC} - для генерации UUID пользователя"
echo -e "  ${BLUE}3.${NC} Проверить конфиг: ${GREEN}xray run -test -config /usr/local/etc/xray/config.json${NC}"
echo -e "  ${BLUE}4.${NC} Перезапустить Xray: ${GREEN}systemctl restart xray${NC}"
echo -e "  ${BLUE}5.${NC} Проверить статус: ${GREEN}systemctl status xray${NC}\n"

echo -e "${YELLOW}📊 Полезные команды:${NC}"
echo -e "  • Просмотр логов: ${GREEN}journalctl -u xray -f${NC}"
echo -e "  • Проверка подключений: ${GREEN}tail -f /var/log/xray/access.log${NC}"
echo -e "  • Версия Xray: ${GREEN}xray --version${NC}\n"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🚀 Хочешь больше? Установи полную версию с мониторингом:${NC}"
echo -e "${BLUE}👉 https://github.com/kolpakovden/MIFA-VPN${NC}\n"
