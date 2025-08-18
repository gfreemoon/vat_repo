#!/bin/sh

### DPI-bypass fix in OpenWRT (Zapret, YouTubeUnblock) with Hardware/Software Offloading
sed -i 's/meta l4proto { tcp, udp } flow offload @ft;/meta l4proto { tcp, udp } ct original packets ge 30 flow offload @ft;/g' /usr/share/firewall4/templates/ruleset.uc
fw4 restart

### Disabling QUIC on the router (solves issues with video streaming and DPI bypass)
uci add firewall rule
uci set firewall.@rule[-1].name='Block_UDP_80'
uci set firewall.@rule[-1].src='*'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='REJECT'

uci add firewall rule
uci set firewall.@rule[-1].name='Block_UDP_443'
uci set firewall.@rule[-1].src='*'
uci set firewall.@rule[-1].dest_port='443'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='REJECT'

uci commit firewall
/etc/init.d/firewall restart
