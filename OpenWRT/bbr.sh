#!/bin/sh

# Installing BBR module
opkg update
opkg install kmod-tcp-bbr

# Loading BBR module
modprobe tcp_bbr

# Installing BBR as default
sed -i '/tcp_congestion_control/d' /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -w net.ipv4.tcp_congestion_control=bbr

# Test
echo "Curent algorythm:"
sysctl net.ipv4.tcp_congestion_control

echo "Testing BBR:"
lsmod | grep tcp_bbr

echo "Setup complete! You should reboot your router and test again."
