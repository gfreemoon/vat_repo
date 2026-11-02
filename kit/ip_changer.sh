#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "[!] Запустите скрипт от root (sudo -i)"; exit 1; }

BACKUP_DIR="/root/xui_ip_backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CURRENT_BACKUP_PATH="${BACKUP_DIR}/backup_${TIMESTAMP}"

# Авто-определение текущего IPv4/IPv6
OLD_IP=$(curl -4 -fsS -m 5 https://api.ipify.org 2>/dev/null || ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7}')

print_menu() {
    clear
    echo "=================================================="
    echo "       3X-UI & KIT IP MIGRATION MANAGER           "
    echo "=================================================="
    echo "Текущий определенный IP сервера: ${OLD_IP:-Не определен}"
    echo ""
    echo "1. Сменить IP-адрес (Миграция)"
    echo "2. Восстановить настройки из бэкапа"
    echo "3. Управление бэкапами (Просмотр / Удаление)"
    echo "0. Выход"
    echo "=================================================="
}

make_backup() {
    echo "[*] Создание резервной копии конфигураций..."
    mkdir -p "$CURRENT_BACKUP_PATH"
    
    # Бэкапим базу 3x-ui
    DB_FILE=$(find / -name "x-ui.db" 2>/dev/null | grep -E "(/etc/x-ui/|/usr/local/x-ui/)" | head -n 1)
    [[ -n "$DB_FILE" ]] && cp "$DB_FILE" "$CURRENT_BACKUP_PATH/x-ui.db"
    
    # Бэкапим Nginx и kit-sub
    [[ -d /etc/nginx ]] && cp -r /etc/nginx "$CURRENT_BACKUP_PATH/nginx"
    [[ -d /etc/kit-sub ]] && cp -r /etc/kit-sub "$CURRENT_BACKUP_PATH/kit-sub"
    
    echo "[+] Бэкап успешно сохранен в: $CURRENT_BACKUP_PATH"
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
    
    # Восстанавливаем базу
    if [[ -f "$RESTORE_PATH/x-ui.db" ]]; then
        TARGET_DB=$(find / -name "x-ui.db" 2>/dev/null | grep -E "(/etc/x-ui/|/usr/local/x-ui/)" | head -n 1)
        cp "$RESTORE_PATH/x-ui.db" "$TARGET_DB"
    fi
    
    # Восстанавливаем Nginx и kit-sub
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
        
        echo "Список существующих бэкапов:"
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

change_ip() {
    echo ""
    read -r -p "Введите НОВЫЙ IP-адрес сервера (IPv4 или IPv6 в [скобках]): " NEW_IP
    [[ -n "$NEW_IP" ]] || { echo "[!] IP не может быть пустым!"; sleep 2; return; }
    
    read -r -p "Введите старый IP-адрес (который нужно заменить, по умолчанию '$OLD_IP'): " TARGET_IP
    TARGET_IP="${TARGET_IP:-$OLD_IP}"
    
    if [[ -z "$TARGET_IP" ]]; then
        echo "[!] Не удалось определить старый IP. Введите его вручную следующий раз."
        sleep 2
        return
    fi

    # Делаем бэкап перед изменениями
    make_backup

    echo "[*] Выполняется замена $TARGET_IP на $NEW_IP во всех конфигурациях..."

    # 1. Замена в Nginx конфигах
    find /etc/nginx -type f -exec sed -i "s/$TARGET_IP/$NEW_IP/g" {} +

    # 2. Замена в kit-sub конфиге
    if [[ -f /etc/kit-sub/config.json ]]; then
        sed -i "s/$TARGET_IP/$NEW_IP/g" /etc/kit-sub/config.json
    fi

    # 3. Замена в базе данных 3x-ui (external_proxy и прочее)
    DB_FILE=$(find / -name "x-ui.db" 2>/dev/null | grep -E "(/etc/x-ui/|/usr/local/x-ui/)" | head -n 1)
    if [[ -n "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE inbounds SET external_proxy = replace(external_proxy, '$TARGET_IP', '$NEW_IP');" 2>/dev/null || true
    fi

    # Проверка Nginx на синтаксис
    if nginx -t; then
        echo "[+] Конфигурация Nginx прошла проверку успешно."
        systemctl restart nginx
        systemctl restart x-ui
        systemctl restart kit-sub 2>/dev/null || true
        echo ""
        echo "=================================================="
        echo "[+] МИГРАЦИЯ УСПЕШНО ЗАВЕРШЕНА!"
        echo "Новый IP: $NEW_IP"
        echo "=================================================="
    else
        echo "[-] Ошибка в синтаксисе Nginx! Откатываемся назад..."
        # Авто-откат из свежего бэкапа
        cp -r "$CURRENT_BACKUP_PATH/nginx" /etc/
        systemctl restart nginx
        echo "[-] Изменения отменены, система возвращена в исходное состояние."
    fi
    
    read -r -p "Нажмите Enter для возврата в меню..."
}

# Главный цикл меню
while true; do
    print_menu
    read -r -p "Выберите пункт меню (0-3): " choice
    case $choice in
        1) change_ip ;;
        2) restore_backup ;;
        3) manage_backups ;;
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный ввод."; sleep 1 ;;
    esac
done