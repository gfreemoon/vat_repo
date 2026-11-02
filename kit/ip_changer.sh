#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "[!] Запустите скрипт от root (sudo -i)"; exit 1; }

BACKUP_DIR="/root/xui_ip_backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CURRENT_BACKUP_PATH="${BACKUP_DIR}/backup_${TIMESTAMP}"

# Авто-обнаружение старого IP из конфига kit-sub
DETECTED_OLD_IP=""
if [[ -f /etc/kit-sub/config.json ]] && command -v jq >/dev/null 2>&1; then
    DETECTED_OLD_IP=$(jq -r '.host // empty' /etc/kit-sub/config.json 2>/dev/null | tr -d '[]')
fi

clear
echo "=================================================="
echo "          3X-UI & KIT IP MIGRATION TOOL           "
echo "  Все действия на свой страх и риск, автор не     "
echo "  несет ответственности за возможные сбои.        "
echo "=================================================="
echo ""

# Ввод старого и нового IP
if [[ -n "$DETECTED_OLD_IP" ]]; then
    read -r -p "Введите СТАРЫЙ IP-адрес/домен [по умолчанию: $DETECTED_OLD_IP]: " OLD_IP
    OLD_IP="${OLD_IP:-$DETECTED_OLD_IP}"
else
    read -r -p "Введите СТАРЫЙ IP-адрес/домен: " OLD_IP
fi
[[ -n "$OLD_IP" ]] || { echo "[!] Старый адрес обязателен!"; exit 1; }

read -r -p "Введите НОВЫЙ IP-адрес: " NEW_IP
[[ -n "$NEW_IP" ]] || { echo "[!] Новый адрес обязателен!"; exit 1; }

# Форматирование под IPv4 или IPv6 (со скобками)
if [[ "$NEW_IP" =~ : ]]; then
    NEW_FORMAT_CLEAN="$NEW_IP"
    NEW_FORMAT_BRACKET="[$NEW_IP]"
else
    NEW_FORMAT_CLEAN="$NEW_IP"
    NEW_FORMAT_BRACKET="$NEW_IP"
fi

echo ""
echo "[*] Создание резервной копии конфигураций..."
mkdir -p "$CURRENT_BACKUP_PATH"
DB_FILE=$(find / -name "x-ui.db" 2>/dev/null | grep -E "(/etc/x-ui/|/usr/local/x-ui/)" | head -n 1)
[[ -n "$DB_FILE" ]] && cp "$DB_FILE" "$CURRENT_BACKUP_PATH/x-ui.db"
[[ -d /etc/nginx ]] && cp -r /etc/nginx "$CURRENT_BACKUP_PATH/nginx"
[[ -d /etc/kit-sub ]] && cp -r /etc/kit-sub "$CURRENT_BACKUP_PATH/kit-sub"
echo "[+] Бэкап сохранен в: $CURRENT_BACKUP_PATH"

echo "[*] Выполняется замена $OLD_IP на $NEW_IP во всех компонентах..."

# 1. Замена в Nginx конфигах
find /etc/nginx -type f -exec sed -i "s/$OLD_IP/$NEW_IP/g" {} +

# 2. Замена в kit-sub конфиге
if [[ -f /etc/kit-sub/config.json ]]; then
    sed -i "s/$OLD_IP/$NEW_IP/g" /etc/kit-sub/config.json
    if [[ "$NEW_IP" =~ : ]]; then
        sed -i "s/\"host\": \"[^\"]*\"/\"host\": \"[$NEW_IP]\"/g" /etc/kit-sub/config.json
    fi
fi

# 3. Замена в базе данных 3x-ui (Хосты, External Proxy, JSON-шаблоны инбаундов и Fake-TLS)
if [[ -n "$DB_FILE" ]]; then
    # Внешний прокси во всех инбаундах
    sqlite3 "$DB_FILE" "UPDATE inbounds SET external_proxy = replace(external_proxy, '$OLD_IP', '$NEW_IP');" 2>/dev/null || true
    sqlite3 "$DB_FILE" "UPDATE inbounds SET external_proxy = replace(external_proxy, '[$OLD_IP]', '$NEW_FORMAT_BRACKET');" 2>/dev/null || true
    
    # Таблица Хостов
    sqlite3 "$DB_FILE" "UPDATE hosts SET address = replace(address, '$OLD_IP', '$NEW_FORMAT_CLEAN');" 2>/dev/null || true
    sqlite3 "$DB_FILE" "UPDATE hosts SET address = replace(address, '[$OLD_IP]', '$NEW_FORMAT_BRACKET');" 2>/dev/null || true
    
    # Глубокий обход JSON-структур в stream_settings (Reality, WS, цели и т.д.)
    sqlite3 "$DB_FILE" "UPDATE inbounds SET stream_settings = replace(stream_settings, '$OLD_IP', '$NEW_IP');" 2>/dev/null || true
    sqlite3 "$DB_FILE" "UPDATE inbounds SET stream_settings = replace(stream_settings, '[$OLD_IP]', '$NEW_FORMAT_BRACKET');" 2>/dev/null || true
    
    # Обход настроек инбаундов (включая fakeTlsDomain для MTProto)
    sqlite3 "$DB_FILE" "UPDATE inbounds SET settings = replace(settings, '$OLD_IP', '$NEW_IP');" 2>/dev/null || true
fi

# Проверка Nginx на синтаксис
if nginx -t; then
    echo "[+] Синтаксис Nginx в норме."
    systemctl restart nginx
    systemctl restart x-ui
    systemctl restart kit-sub 2>/dev/null || true
    echo ""
    echo "=================================================="
    echo "         МИГРАЦИЯ УСПЕШНО ЗАВЕРШЕНА!              "
    echo "=================================================="
    echo "Старый адрес: $OLD_IP"
    echo "Новый адрес:  $NEW_IP"
    echo "=================================================="
else
    echo "[-] Ошибка в синтаксисе Nginx! Авто-откат из бэкапа..."
    cp -r "$CURRENT_BACKUP_PATH/nginx" /etc/
    systemctl restart nginx
    echo "[-] Откачено."
    exit 1
fi
