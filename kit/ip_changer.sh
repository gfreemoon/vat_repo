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

print_menu() {
    clear
    echo "=================================================="
    echo "          3X-UI & KIT IP MIGRATION TOOL           "
    echo "  Все действия на свой страх и риск, автор не     "
    echo "  несет ответственности за возможные сбои.        "
    echo "=================================================="
    echo "Текущий определенный/старый хост: ${DETECTED_OLD_IP:-Не найден}"
    echo ""
    echo "1. Сменить IP-адрес / Миграция"
    echo "2. Восстановить настройки из бэкапа"
    echo "3. Управление бэкапами (Удалить)"
    echo "0. Выход"
    echo "=================================================="
}

make_backup() {
    echo "[*] Создание резервной копии конфигураций..."
    mkdir -p "$CURRENT_BACKUP_PATH"
    DB_FILE=$(find / -name "x-ui.db" 2>/dev/null | grep -E "(/etc/x-ui/|/usr/local/x-ui/)" | head -n 1)
    [[ -n "$DB_FILE" ]] && cp "$DB_FILE" "$CURRENT_BACKUP_PATH/x-ui.db"
    [[ -d /etc/nginx ]] && cp -r /etc/nginx "$CURRENT_BACKUP_PATH/nginx"
    [[ -d /etc/kit-sub ]] && cp -r /etc/kit-sub "$CURRENT_BACKUP_PATH/kit-sub"
    echo "[+] Бэкап сохранен в: $CURRENT_BACKUP_PATH"
}

restore_backup() {
    echo ""
    echo "Доступные бэкапы:"
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR")" ]]; then
        echo "[-] Бэкапы не найдены в директории $BACKUP_DIR"
        read -r -p "Нажмите Enter для возврата в меню..."
        return
    fi
    
    select b in "$BACKUP_DIR"/*; do
        if [[ -d "$b" ]]; then
            RESTORE_PATH="$b"
            break
        else
            echo "Неверный выбор."
        fi
    done
    
    echo "[*] Восстановление из: $RESTORE_PATH..."
    if [[ -f "$RESTORE_PATH/x-ui.db" ]]; then
        TARGET_DB=$(find / -name "x-ui.db" 2>/dev/null | grep -E "(/etc/x-ui/|/usr/local/x-ui/)" | head -n 1)
        cp "$RESTORE_PATH/x-ui.db" "$TARGET_DB"
    fi
    [[ -d "$RESTORE_PATH/nginx" ]] && cp -r "$RESTORE_PATH/nginx" /etc/
    [[ -d "$RESTORE_PATH/kit-sub" ]] && cp -r "$RESTORE_PATH/kit-sub" /etc/
    
    systemctl restart nginx
    systemctl restart x-ui
    systemctl restart kit-sub 2>/dev/null || true
    
    echo "[+] Система успешно восстановлена из бэкапа!"
    read -r -p "Нажмите Enter для возврата в меню..."
}

manage_backups() {
    while true; do
        clear
        echo "=================================================="
        echo "               УПРАВЛЕНИЕ БЭКАПАМИ                "
        echo "=================================================="
        if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR")" ]]; then
            echo "Бэкапов пока нет."
            read -r -p "Нажмите Enter для возврата в меню..."
            break
        fi
        
        select b in "$BACKUP_DIR"/* "Удалить ВСЕ бэкапы" "Назад в главное меню"; do
            if [[ "$b" == "Назад в главное меню" ]]; then
                return
            elif [[ "$b" == "Удалить ВСЕ бэкапы" ]]; then
                rm -rf "$BACKUP_DIR"/*
                echo "[+] Все бэкапы успешно удалены!"
                sleep 1
                break
            elif [[ -d "$b" ]]; then
                echo ""
                echo "1. Удалить этот бэкап"
                echo "2. Назад к списку"
                read -r -p "Выберите действие (1-2): " act
                if [[ "$act" == "1" ]]; then
                    rm -rf "$b"
                    echo "[+] Бэкап удален."
                    sleep 1
                fi
                break
            fi
        done
    done
}

change_ip_wizard() {
    echo ""
    if [[ -n "$DETECTED_OLD_IP" ]]; then
        read -r -p "Введите СТАРЫЙ IP-адрес/домен [по умолчанию: $DETECTED_OLD_IP]: " OLD_IP
        OLD_IP="${OLD_IP:-$DETECTED_OLD_IP}"
    else
        read -r -p "Введите СТАРЫЙ IP-адрес/домен: " OLD_IP
    fi
    [[ -n "$OLD_IP" ]] || { echo "[!] Старый адрес обязателен!"; sleep 2; return; }

    read -r -p "Введите НОВЫЙ IP-адрес: " NEW_IP
    [[ -n "$NEW_IP" ]] || { echo "[!] Новый адрес обязателен!"; sleep 2; return; }

    if [[ "$NEW_IP" =~ : ]]; then
        NEW_FORMAT_CLEAN="$NEW_IP"
        NEW_FORMAT_BRACKET="[$NEW_IP]"
    else
        NEW_FORMAT_CLEAN="$NEW_IP"
        NEW_FORMAT_BRACKET="$NEW_IP"
    fi

    echo ""
    make_backup

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

    # 3. Замена в базе данных 3x-ui
    DB_FILE=$(find / -name "x-ui.db" 2>/dev/null | grep -E "(/etc/x-ui/|/usr/local/x-ui/)" | head -n 1)
    if [[ -n "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE inbounds SET external_proxy = replace(external_proxy, '$OLD_IP', '$NEW_IP');" 2>/dev/null || true
        sqlite3 "$DB_FILE" "UPDATE inbounds SET external_proxy = replace(external_proxy, '[$OLD_IP]', '$NEW_FORMAT_BRACKET');" 2>/dev/null || true
        
        sqlite3 "$DB_FILE" "UPDATE hosts SET address = replace(address, '$OLD_IP', '$NEW_FORMAT_CLEAN');" 2>/dev/null || true
        sqlite3 "$DB_FILE" "UPDATE hosts SET address = replace(address, '[$OLD_IP]', '$NEW_FORMAT_BRACKET');" 2>/dev/null || true
        
        sqlite3 "$DB_FILE" "UPDATE inbounds SET stream_settings = replace(stream_settings, '$OLD_IP', '$NEW_IP');" 2>/dev/null || true
        sqlite3 "$DB_FILE" "UPDATE inbounds SET stream_settings = replace(stream_settings, '[$OLD_IP]', '$NEW_FORMAT_BRACKET');" 2>/dev/null || true
        
        sqlite3 "$DB_FILE" "UPDATE inbounds SET settings = replace(settings, '$OLD_IP', '$NEW_IP');" 2>/dev/null || true
    fi

    # Проверка Nginx
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
    fi
    
    read -r -p "Нажмите Enter для возврата в меню..."
}

# Главный цикл меню
while true; do
    print_menu
    read -r -p "Выберите пункт меню (0-3): " choice
    case $choice in
        1) change_ip_wizard ;;
        2) restore_backup ;;
        3) manage_backups ;;
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный ввод."; sleep 1 ;;
    esac
done
