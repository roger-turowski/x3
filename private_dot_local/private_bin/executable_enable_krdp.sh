#!/usr/bin/env bash
set -euo pipefail

# 1. Verify KRDP package is installed
if ! pacman -Q org.kde.krdpserver &>/dev/null; then
    echo "Installing KRDP packages..."
    sudo pacman -S plasma-workspace
fi

# 2. Configure autologin correctly for SDDM
sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null << 'EOF_SDDM'
[Autologin]
User=roger
Session=plasma.desktop
Relogin=true
EOF_SDDM

# 3. Enable firewall with nftables (preferred on Arch) or open port directly
# Option A: Using firewalld (install first if needed)
# sudo systemctl enable --now firewalld
# sudo firewall-cmd --permanent --add-service=rdp
# sudo firewall-cmd --reload

# Option B: Using nftables directly  
sudo tee /etc/nftables.d/allow-rdp.conf > /dev/null << 'EOF_NFT'
table inet filter {
    chain input {
        tcp dport 3389 accept
    }
}
EOF_NFT
sudo nft -f /etc/nftables.d/allow-rdp.conf

# 4. Ensure KRDP server is configured (system-level, not just user override)
# Check if the unit exists first
if systemctl list-unit-files | grep -q krdpserver; then
    systemctl --user daemon-reload
    systemctl --user enable app-org.kde.krdpserver.service
    systemctl --user start app-org.kde.krdpserver.service
else
    echo "WARNING: KRDP server unit not found. Manual configuration may be needed."
fi

echo "Configuration complete. Reboot required."
