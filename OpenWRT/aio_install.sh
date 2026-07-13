#!/bin/sh

echo "Select installation mode:"
echo "1) Automatic (install all components)"
echo "2) Manual (choose each component)"
read -p "Enter 1 or 2: " mode

if [ "$mode" = "1" ]; then
    echo "Running automatic installation..."

    echo "Installing ca-bundle, curl, kmod..."
    opkg update
    opkg install curl ca-bundle kmod-nft-queue kmod-nfnetlink-queue 

    # Install BBR
    echo "Installing BBR by community..."
    sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/bbr.sh)

    # Install DPI Fix
    echo "Installing DPI Fix by community..."
    sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/dpi_fix.sh)

    # Install TG WS PROXY
    echo "Installing TG WS PROXY by spatiumstas..."
    sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/tgwsproxy_universal_installer.sh)

    # Install Podkop
    echo "Installing Podkop by itdoginfo..."
    sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh)

    # Install YouTubeUnblock
    echo "Installing YouTubeUnblock by Waujito..."
    sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/install_youtubeunblock_universal/refs/heads/main/install_youtubeUnblock.sh)

    # Install YouTubeUnblock Config Generator
    echo "Installing YouTubeUnblock Config Generator by gfreemoon..."
    sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/install_youtubeunblock_universal/refs/heads/main/ytu_config_generator.sh)


    echo "Automatic installation complete!"
else
    echo "Running manual installation..."

    # Install BBR
    echo "BBR by community: Optimizes network performance, reduces latency, improves stability for downloads and gaming."
    read -p "Install BBR? (y/n): " install_bbr
    if [ "$install_bbr" = "y" ] || [ "$install_bbr" = "Y" ]; then
        echo "Installing BBR..."
        sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/bbr.sh)
    fi

    # Install DPI Fix
    echo "DPI Fix by community: Prevents Deep Packet Inspection from interfering when offloading is enabled."
    read -p "Install DPI Fix? (y/n): " install_dpi
    if [ "$install_dpi" = "y" ] || [ "$install_dpi" = "Y" ]; then
        echo "Installing DPI Fix..."
        sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/dpi_fix.sh)
    fi

    # Install TG_WS_PROXY and luci app
    echo "TG WS PROXY by spatiumstas: Local telegram proxy for openwrt with WebUI."
    read -p "Install TG WS PROXY? (y/n): " install_tg_ws_proxy
    if [ "$install_tg_ws_proxy" = "y" ] || [ "$install_tg_ws_proxy" = "Y" ]; then
        echo "Installing TG WS PROXY..."
        sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/tgwsproxy_universal_installer.sh)
    fi

    # Install Podkop
    echo "Podkop by itdoginfo: Routes specific domains, IPs, or subnets through proxy/VPN/tunnels using sing-box and FakeIP."
    read -p "Install Podkop? (y/n): " install_podkop
    if [ "$install_podkop" = "y" ] || [ "$install_podkop" = "Y" ]; then
        echo "Installing Podkop..."
        sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh)
    fi

    # Install YouTubeUnblock
    echo "YouTubeUnblock by Waujito: Enables ad-free YouTube streaming."
    read -p "Install YouTubeUnblock? (y/n): " install_yt
    if [ "$install_yt" = "y" ] || [ "$install_yt" = "Y" ]; then
        echo "Installing YouTubeUnblock..."
        sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/install_youtubeunblock_universal/refs/heads/main/install_youtubeUnblock.sh)
    fi

    # Install YouTubeUnblock Config Generator
    echo "YouTubeUnblock Config Generator by gfreemoon: Automatically configures YouTubeUnblock using AllowDomains list from ITDog."
    read -p "Install YouTubeUnblock and Config Generator? (y/n): " install_yt_config
    if [ "$install_yt_config" = "y" ] || [ "$install_yt_config" = "Y" ]; then
        echo "Installing YouTubeUnblock Config Generator..."
        sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/install_youtubeunblock_universal/refs/heads/main/ytu_config_generator.sh)
    fi

    echo "Manual installation complete!"
fi

echo "Important: Manually configure components as needed!"
echo "- For Podkop: Ensure YouTube uses YouTubeUnblock, disable 'Russia Inside', use your VDS with key."
echo "- For Tailscale: Configure with your authentication key."
echo "Reboot router: reboot"
echo "After reboot, verify ad-free YouTube, access to blocked sites, and other components."
