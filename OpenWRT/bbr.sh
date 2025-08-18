#!/bin/sh

# Устанавливаем локаль для корректного отображения русского текста
export LANG=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8
export LC_CTYPE=ru_RU.UTF-8
if ! locale >/dev/null 2>&1; then
    echo "Локаль ru_RU.UTF-8 не найдена. Русский текст может отображаться некорректно."
    echo "Попробуйте установить пакет с локалями (opkg install locale) или проверить настройки терминала."
fi

# Устанавливаем модуль BBR
opkg update
opkg install kmod-tcp-bbr

# Загружаем модуль BBR
modprobe tcp_bbr

# Устанавливаем BBR как алгоритм по умолчанию
sed -i '/tcp_congestion_control/d' /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -w net.ipv4.tcp_congestion_control=bbr

# Проверка текущего алгоритма и загрузки модуля
echo "Текущий алгоритм:"
sysctl net.ipv4.tcp_congestion_control

echo "Проверка модуля BBR:"
lsmod | grep tcp_bbr

echo "Настройка завершена! Перезагрузите роутер и проверьте еще раз."
