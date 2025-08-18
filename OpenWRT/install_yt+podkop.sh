#!/bin/sh

# Install Podkop
sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh)

# Install YouTubeUnblock
sh <(wget -O - https://raw.githubusercontent.com/gfreemoon/install_youtubeunblock_universal/refs/heads/main/install%2Bconfig.sh)

# Configuration instructions
echo "Important: Configure Podkop manually!"
echo "- Ensure YouTube uses YouTubeUnblock, not Podkop."
echo "- Disable 'Russia Inside' in Podkop settings."
echo "- Use your VDS with key for Podkop."

echo "Installation complete! Reboot router: reboot"
echo "After reboot, verify ad-free YouTube and access to blocked sites."
