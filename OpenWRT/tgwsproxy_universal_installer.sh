#!/bin/sh

# Проверяем пакетный менеджер и вытаскиваем точную архитектуру железа
if command -v apk >/dev/null 2>&1; then
    PKG_MANAGER="apk"
    ARCH=$(apk --print-arch 2>/dev/null)
    EXT="apk"
elif command -v opkg >/dev/null 2>&1; then
    PKG_MANAGER="opkg"
    EXT="ipk"
    ARCH=$(opkg info kernel | grep Architecture | awk '{print $2}')
else
    echo "Не найден ни apk, ни opkg. Скрипт остановлен."
    exit 1
fi

if [ -z "$ARCH" ]; then
    echo "Ошибка: Не удалось определить архитектуру роутера."
    exit 1
fi

echo "Менеджер пакетов: $PKG_MANAGER | Архитектура: $ARCH"

# Получаем ссылки на последний релиз с GitHub spatiumstas
echo "Поиск пакетов в релизах GitHub..."
RELEASE_JSON=$(curl -s https://api.github.com/repos/spatiumstas/tg-ws-proxy-go/releases/latest)

CORE_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url" | grep "$ARCH" | grep "\.$EXT" | cut -d '"' -f 4)
LUCI_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url" | grep "luci-app" | grep "\.$EXT" | cut -d '"' -f 4)

if [ -z "$CORE_URL" ] || [ -z "$LUCI_URL" ]; then
    echo "Ошибка: Не удалось найти полный комплект пакетов ($EXT) под архитектуру $ARCH."
    exit 1
fi

# Скачивание и установка пакетов
if [ "$PKG_MANAGER" = "apk" ]; then
    echo "Скачиваем публичный ключ для подписи apk пакетов..."
    mkdir -p /etc/apk/keys
    wget -qO /etc/apk/keys/tg-ws-proxy.pem "https://github.com/spatiumstas/tg-ws-proxy-go/releases/latest/download/tg-ws-proxy.pem"

    echo "Скачивание пакетов..."
    wget -qO /tmp/tg-ws-proxy.apk "$CORE_URL"
    wget -qO /tmp/luci-app-tg-ws-proxy.apk "$LUCI_URL"
    
    echo "Установка пакетов через apk..."
    apk update
    apk add /tmp/tg-ws-proxy.apk /tmp/luci-app-tg-ws-proxy.apk
    rm -f /tmp/tg-ws-proxy.apk /tmp/luci-app-tg-ws-proxy.apk
else
    echo "Скачивание пакетов..."
    wget -qO /tmp/tg-ws-proxy.ipk "$CORE_URL"
    wget -qO /tmp/luci-app-tg-ws-proxy.ipk "$LUCI_URL"
    
    echo "Установка пакетов через opkg..."
    opkg update
    opkg install /tmp/tg-ws-proxy.ipk
    opkg install /tmp/luci-app-tg-ws-proxy.ipk
    rm -f /tmp/tg-ws-proxy.ipk /tmp/luci-app-tg-ws-proxy.ipk
fi

# Сброс кэша веб-интерфейса
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache

echo "Установка успешно завершена!"
echo "Обнови или выйди-войди в панель управления роутером."
echo "Настройки и управление: 'Службы' (Services) -> 'TG WS Proxy'."
