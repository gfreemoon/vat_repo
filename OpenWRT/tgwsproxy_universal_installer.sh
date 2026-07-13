#!/bin/sh

# ANSI Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

if command -v apk >/dev/null 2>&1; then
    PKG_MANAGER="apk"
    ARCH=$(apk --print-arch 2>/dev/null)
    EXT="apk"
elif command -v opkg >/dev/null 2>&1; then
    PKG_MANAGER="opkg"
    EXT="ipk"
    ARCH=$(opkg info kernel | grep Architecture | awk '{print $2}')
else
    echo -e "${RED}Ошибка: Не найден ни apk, ни opkg.${RESET}"
    exit 1
fi

if [ -z "$ARCH" ]; then
    echo -e "${RED}Ошибка: Не удалось определить архитектуру роутера.${RESET}"
    exit 1
fi

echo -e "Менеджер: ${GREEN}$PKG_MANAGER${RESET} | Архитектура: ${GREEN}$ARCH${RESET}"
echo "Поиск пакетов на GitHub..."

RELEASE_DATA=$(curl -s https://api.github.com/repos/spatiumstas/tg-ws-proxy-go/releases/latest | grep -o 'https://[^"]*')

CORE_URL=$(echo "$RELEASE_DATA" | grep "$ARCH" | grep "\.$EXT" | head -n 1)
LUCI_URL=$(echo "$RELEASE_DATA" | grep "luci-app" | grep "\.$EXT" | head -n 1)

if [ -z "$CORE_URL" ] || [ -z "$LUCI_URL" ]; then
    echo -e "${RED}Ошибка: Пакеты для $ARCH не найдены.${RESET}"
    exit 1
fi

if [ "$PKG_MANAGER" = "apk" ]; then
    echo "Скачивание ключа..."
    mkdir -p /etc/apk/keys
    wget -q -O /etc/apk/keys/tg-ws-proxy.pem "https://github.com/spatiumstas/tg-ws-proxy-go/releases/latest/download/tg-ws-proxy.pem"
    wget -q -O /tmp/tg-ws-proxy.apk "$CORE_URL"
    wget -q -O /tmp/luci-app-tg-ws-proxy.apk "$LUCI_URL"
    apk update
    apk add /tmp/tg-ws-proxy.apk /tmp/luci-app-tg-ws-proxy.apk
    rm -f /tmp/tg-ws-proxy.apk /tmp/luci-app-tg-ws-proxy.apk
else
    wget -q -O /tmp/tg-ws-proxy.ipk "$CORE_URL"
    wget -q -O /tmp/luci-app-tg-ws-proxy.ipk "$LUCI_URL"
    opkg update
    opkg install /tmp/tg-ws-proxy.ipk
    opkg install /tmp/luci-app-tg-ws-proxy.ipk
    rm -f /tmp/tg-ws-proxy.ipk /tmp/luci-app-tg-ws-proxy.ipk
fi

rm -rf /tmp/luci-indexcache /tmp/luci-modulecache

echo -e "\n${GREEN}Установка успешно завершена!${RESET}"
echo -e "${YELLOW}Обнови страницу в браузере.${RESET}"
echo "Настройки: Службы -> TG WS Proxy"
