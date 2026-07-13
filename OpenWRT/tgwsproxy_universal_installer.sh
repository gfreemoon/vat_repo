#!/bin/sh

# Проверяем, какой пакетный менеджер используется
if command -v apk >/dev/null 2>&1; then
    PKG_MANAGER="apk"
    ARCH=$(apk --print-arch 2>/dev/null)
    EXT="apk"
elif command -v opkg >/dev/null 2>&1; then
    PKG_MANAGER="opkg"
    ARCH=$(opkg print-architecture | awk 'NR==1 {print $2}')
    EXT="ipk"
else
    echo "[-] Не найден ни apk, ни opkg. Что это за прошивка?"
    exit 1
fi

echo "[+] Менеджер пакетов: $PKG_MANAGER | Архитектура: $ARCH"

# Получаем ссылки на последний релиз
echo "[+] Поиск пакетов в релизах GitHub..."
RELEASE_JSON=$(curl -s https://api.github.com/repos/spatiumstas/tg-ws-proxy-go/releases/latest)

# Ссылка на основной демон (зависит от архитектуры)
CORE_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url" | grep "$ARCH" | grep "\.$EXT" | cut -d '"' -f 4)
# Ссылка на LuCI апплет (он универсальный, от архитектуры процессора не зависит)
LUCI_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url" | grep "luci-app" | grep "\.$EXT" | cut -d '"' -f 4)

if [ -z "$CORE_URL" ] || [ -z "$LUCI_URL" ]; then
    echo "[-] Ошибка: Не удалось найти полный комплект пакетов ($EXT) в релизах."
    exit 1
fi

# Установка
if [ "$PKG_MANAGER" = "apk" ]; then
    echo "[+] Скачиваем публичный ключ для проверки apk пакетов..."
    mkdir -p /etc/apk/keys
    wget -qO /etc/apk/keys/tg-ws-proxy.pem "https://github.com/spatiumstas/tg-ws-proxy-go/releases/latest/download/tg-ws-proxy.pem"

    echo "[+] Скачивание пакетов..."
    wget -qO /tmp/tg-ws-proxy.apk "$CORE_URL"
    wget -qO /tmp/luci-app-tg-ws-proxy.apk "$LUCI_URL"
    
    echo "[+] Установка через apk..."
    apk update
    apk add /tmp/tg-ws-proxy.apk /tmp/luci-app-tg-ws-proxy.apk
    
    rm -f /tmp/tg-ws-proxy.apk /tmp/luci-app-tg-ws-proxy.apk
else
    echo "[+] Скачивание пакетов..."
    wget -qO /tmp/tg-ws-proxy.ipk "$CORE_URL"
    wget -qO /tmp/luci-app-tg-ws-proxy.ipk "$LUCI_URL"
    
    echo "[+] Установка через opkg..."
    opkg update
    opkg install /tmp/tg-ws-proxy.ipk
    opkg install /tmp/luci-app-tg-ws-proxy.ipk
    
    rm -f /tmp/tg-ws-proxy.ipk /tmp/luci-app-tg-ws-proxy.ipk
fi

# Сброс кэша LuCI, чтобы вкладка появилась без перезагрузки роутера
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache

echo "--------------------------------------------------------"
echo "Установка успешно завершена!"
echo "Обнови или выйди-войди в панель управления роутером."
echo "Ищи вкладку управления в меню 'Службы' (Services) -> 'TG WS Proxy'."
echo "--------------------------------------------------------"
