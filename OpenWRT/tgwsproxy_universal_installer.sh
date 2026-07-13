#!/bin/sh

КРАСНЫЙ='\033[0;31m'
ЗЕЛЕНЫЙ='\033[0;32m'
ЖЕЛТЫЙ='\033[0;33m'
СБРОС='\033[0m'

if command -v apk >/dev/null 2>&1; then
    PKG_MANAGER="apk"
    ARCH=$(apk --print-arch 2>/dev/null)
    EXT="apk"
elif command -v opkg >/dev/null 2>&1; then
    PKG_MANAGER="opkg"
    EXT="ipk"
    ARCH=$(opkg info kernel | grep Architecture | awk '{print $2}')
else
    echo "${КРАСНЫЙ}Не найден ни apk, ни opkg. Скрипт остановлен.${СБРОС}"
    exit 1
fi

if [ -z "$ARCH" ]; then
    echo "${КРАСНЫЙ}Ошибка: Не удалось определить архитектуру роутера.${СБРОС}"
    exit 1
fi

echo "Менеджер пакетов: ${ЗЕЛЕНЫЙ}$PKG_MANAGER${СБРОС} | Архитектура: ${ЗЕЛЕНЫЙ}$ARCH${СБРОС}"
echo "Поиск пакетов в релизах GitHub..."

RELEASE_JSON=$(curl -s -H "Cache-Control: no-cache" https://api.github.com/repos/spatiumstas/tg-ws-proxy-go/releases/latest | tr ',' '\n')

CORE_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url" | grep "$ARCH" | grep "\.$EXT" | cut -d '"' -f 4)
LUCI_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url" | grep "luci-app" | grep "\.$EXT" | cut -d '"' -f 4)

if [ -z "$CORE_URL" ] || [ -z "$LUCI_URL" ]; then
    echo "${КРАСНЫЙ}Ошибка: Не удалось найти полный комплект пакетов ($EXT) под архитектуру $ARCH.${СБРОС}"
    exit 1
fi

if [ "$PKG_MANAGER" = "apk" ]; then
    echo "Скачиваем публичный ключ для подписи apk пакетов..."
    mkdir -p /etc/apk/keys
    wget -q --no-cache -O /etc/apk/keys/tg-ws-proxy.pem "https://github.com/spatiumstas/tg-ws-proxy-go/releases/latest/download/tg-ws-proxy.pem"

    echo "Скачивание пакетов..."
    wget -q --no-cache -O /tmp/tg-ws-proxy.apk "$CORE_URL"
    wget -q --no-cache -O /tmp/luci-app-tg-ws-proxy.apk "$LUCI_URL"
    
    echo "Установка пакетов через apk..."
    apk update
    apk add /tmp/tg-ws-proxy.apk /tmp/luci-app-tg-ws-proxy.apk
    rm -f /tmp/tg-ws-proxy.apk /tmp/luci-app-tg-ws-proxy.apk
else
    echo "Скачивание пакетов..."
    wget -q --no-cache -O /tmp/tg-ws-proxy.ipk "$CORE_URL"
    wget -q --no-cache -O /tmp/luci-app-tg-ws-proxy.ipk "$LUCI_URL"
    
    echo "Установка пакетов через opkg..."
    opkg update
    opkg install /tmp/tg-ws-proxy.ipk
    opkg install /tmp/luci-app-tg-ws-proxy.ipk
    rm -f /tmp/tg-ws-proxy.ipk /tmp/luci-app-tg-ws-proxy.ipk
fi

rm -rf /tmp/luci-indexcache /tmp/luci-modulecache

echo ""
echo "${ЗЕЛЕНЫЙ}Установка успешно завершена!${СБРОС}"
echo "${ЖЕЛТЫЙ}Обнови или выйди-войди в панель управления роутером.${СБРОС}"
echo "Настройки и управление: 'Службы' (Services) -> 'TG WS Proxy'."
