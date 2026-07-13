#!/bin/sh

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
    echo -e "${RED}Не найден ни apk, ни opkg. Скрипт остановлен.${RESET}"
    exit 1
fi

if [ -z "$ARCH" ]; then
    echo -e "${RED}Ошибка: Не удалось определить архитектуру роутера.${RESET}"
    exit 1
fi

echo -e "Менеджер пакетов: ${GREEN}$PKG_MANAGER${RESET} | Архитектура: ${GREEN}$ARCH${RESET}"
echo "Поиск пакетов в релизах GitHub..."

RELEASE_DATA=$(curl -s https://api.github.com/repos/spatiumstas/tg-ws-proxy-go/releases/latest | sed 's/"/\n/g')

CORE_URL=$(echo "$RELEASE_DATA" | grep "browser_download_url" | grep "$ARCH" | grep "\.$EXT$")
LUCI_URL=$(echo "$RELEASE_DATA" | grep "browser_download_url" | grep "luci-app" | grep "\.$EXT$")

if [ -z "$CORE_URL" ] || [ -z "$LUCI_URL" ]; then
    echo -e "${RED}Ошибка: Не удалось найти полный комплект пакетов ($EXT) под архитектуру $ARCH.${RESET}"
    exit 1
fi

if [ "$PKG_MANAGER" = "apk" ]; then
    echo "Скачиваем публичный ключ для подписи apk пакетов..."
    mkdir -p /etc/apk/keys
    wget -q -O /etc/apk/keys/tg-ws-proxy.pem "https://github.com/spatiumstas/tg-ws-proxy-go/releases/latest/download/tg-ws-proxy.pem"

    echo "Скачивание пакетов..."
    wget -q -O /tmp/tg-ws-proxy.apk "$CORE_URL"
    wget -q -O /tmp/luci-app-tg-ws-proxy.apk "$LUCI_URL"
    
    echo "Установка пакетов через apk..."
    apk update
    apk add /tmp/tg-ws-proxy.apk /tmp/luci-app-tg-ws-proxy.apk
    rm -f /tmp/tg-ws-proxy.apk /tmp/luci-app-tg-ws-proxy.apk
else
    echo "Скачивание пакетов..."
    wget -q -O /tmp/tg-ws-proxy.ipk "$CORE_URL"
    wget -q -O /tmp/luci-app-tg-ws-proxy.ipk "$LUCI_URL"
    
    echo "Установка пакетов через opkg..."
    opkg update
    opkg install /tmp/tg-ws-proxy.ipk
    opkg install /tmp/luci-app-tg-ws-proxy.ipk
    rm -f /tmp/tg-ws-proxy.ipk /tmp/luci-app-tg-ws-proxy.ipk
fi

rm -rf /tmp/luci-indexcache /tmp/luci-modulecache

echo ""
echo -e "${GREEN}Установка успешно завершена!${RESET}"
echo -e "${YELLOW}Обнови или выйди-войди в панель управления роутером.${RESET}"
echo "Настройки и управление: 'Службы' (Services) -> 'TG WS Proxy'."
