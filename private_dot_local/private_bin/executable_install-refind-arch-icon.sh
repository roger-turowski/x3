#!/usr/bin/env bash

# --- Guard: must run as a normal user, not root ---
if [ "$(id -u)" -eq 0 ]; then
  echo "FAIL: Do not run this script as root or with sudo."
  echo "      The script calls sudo itself where elevated privileges are needed."
  exit 1
fi

# Optional: verify sudo is usable non-interactively, since the script
# invokes it mid-run and failing there is worse than failing here:
sudo -v || { echo "FAIL: passwordless sudo prompt unavailable"; exit 1; }

log_error() { echo "[ERROR] $*" >&2; exit 1; }
log_info()  { echo "[INFO] $*"; }

icon_src="${HOME}/.local/share/icons/os_arch.png"
icon_dst="/boot/efi/EFI/GRUB/grubx64.png"


if [[ ! -f  "${icon_dst}" ]]; then
  sudo cp "${icon_src}" "${icon_dst}" || \
      log_error "Could not copy icon ${icon_src} to ${icon_dst}"
fi

log_info "Installed icon file: ${icon_dst}"
