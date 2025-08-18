#!/bin/sh

echo "Select installation mode:"
echo "1) Automatic (install all components)"
echo "2) Manual (choose each component)"
read -p "Enter 1 or 2: " mode

if [ "$mode" = "1" ]; then
    echo "Running automatic installation..."

    # Install BBR
    echo "Installing BBR..."
    sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/bbr.sh)

    # Install DPI Fix
    echo "Installing DPI Fix..."
    sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/dpi_fix.sh)

    # Install Tailscale
    echo "Installing Tailscale..."
    sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/openwrt_autosetup/refs/heads/main/tailscale.sh)

    # Install YouTubeUnblock + Podkop
    echo "Installing YouTubeUnblock + Podkop..."
    sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/install_yt+podkop.sh)

    echo "Automatic installation complete!"
else
    echo "Running manual installation..."

    # Install BBR
    echo "BBR: Optimizes network performance, reduces latency, improves stability for downloads and gaming."
    read -p "Install BBR? (y/n): " install_bbr
    if [ "$install_bbr" = "y" ] || [ "$install_bbr" = "Y" ]; then
        echo "Installing BBR..."
        sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/bbr.sh)
    fi

    # Install DPI Fix
    echo "DPI Fix: This is done to prevent DPI from interfering when offloading is enabled."
    read -p "Install DPI Fix? (y/n): " install_dpi
    if [ "$install_dpi" = "y" ] || [ "$install_dpi" = "Y" ]; then
        echo "Installing DPI Fix..."
        sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/dpi_fix.sh)
    fi

    # Install Tailscale
    echo "Tailscale: Sets up a secure VPN for remote access to your network."
    read -p "Install Tailscale? (y/n): " install_tailscale
    if [ "$install_tailscale" = "y" ] || [ "$install_tailscale" = "Y" ]; then
        echo "Installing Tailscale..."
        sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/openwrt_autosetup/refs/heads/main/tailscale.sh)
    fi

    # Install YouTubeUnblock + Podkop
    echo "YouTubeUnblock + Podkop: Enables ad-free YouTube and access to blocked sites via your VDS."
    read -p "Install YouTubeUnblock + Podkop? (y/n): " install_yt_podkop
    if [ "$install_yt_podkop" = "y" ] || [ "$install_yt_podkop" = "Y" ]; then
        echo "Installing YouTubeUnblock + Podkop..."
        sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/vat_repo/refs/heads/main/OpenWRT/install_yt+podkop.sh)
    fi

    echo "Manual installation complete!"
fi

echo "Important: Manually configure components as needed!"
echo "- For Podkop: Ensure YouTube uses YouTubeUnblock, disable 'Russia Inside', use your VDS with key."
echo "Reboot router: reboot"
echo "After reboot, verify ad-free YouTube, access to blocked sites, and other components."
