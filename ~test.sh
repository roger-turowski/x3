#!/usr/bin/env bash

# Backup current config
cp ~/.config/plasma-org.kde.plasma.desktop-appletsrc ~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak

source /etc/os-release

case "$ID" in
  opensuse-tumbleweed)
    ICON_PATH="/usr/share/icons/hicolor/scalable/apps/openSUSE-distributor-logo.svg"
    ;;
  arch)
    ICON_PATH="/usr/share/pixmaps/archlinux-logo.svg"
    ;;
  *)
    ICON_PATH=""
    ;;
esac

# Inject custom icon path
if [ -f "${ICON_PATH}" ]; then
    sed -i "/\[Containments\]/a\\[Containments/1/Configuration]\\nIcon=$ICON_PATH" ~/.config/plasma-org.kde.plasma.desktop-appletsrc

    # Restart Plasma
    kquitapp5 plasmashell && kstart5 plasmashell
fi
