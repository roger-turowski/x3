#!/usr/bin/env bash
set -euo pipefail

# --- Configuration -------------------------------------------------
PARAMS="amd_iommu=off amdgpu.gttsize=126976 ttm.pages_limit=32505856"
GRUB_DEFAULT="/etc/default/grub"
BACKUP="${GRUB_DEFAULT}.bak.$(date +%Y%m%d_%H%M%S)"
# -------------------------------------------------------------------

# Require root
if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root." >&2
    exit 1
fi

# Verify grub file exists
if [[ ! -f "${GRUB_DEFAULT}" ]]; then
    echo "ERROR: ${GRUB_DEFAULT} not found. Is GRUB installed?" >&2
    exit 1
fi

# Backup
cp "${GRUB_DEFAULT}" "${BACKUP}"
echo "Backed up ${GRUB_DEFAULT} → ${BACKUP}"

# Check if parameters already exist
if grep -q -- "${PARAMS}" "${GRUB_DEFAULT}"; then
    echo "Parameters already present in ${GRUB_DEFAULT}. Nothing to do."
    exit 0
fi

# Extract existing GRUB_CMDLINE_LINUX_DEFAULT line
EXISTING=$(grep -E "^GRUB_CMDLINE_LINUX_DEFAULT=" "${GRUB_DEFAULT}" || true)

if [[ -z "${EXISTING}" ]]; then
    # Line doesn't exist — append it
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${PARAMS}\"" >> "${GRUB_DEFAULT}"
    echo "Appended new GRUB_CMDLINE_LINUX_DEFAULT line with parameters."
else
    # Strip leading variable assignment and surrounding quotes
    CURRENT_VAL=$(sed -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"$/\1/' <<< "${EXISTING}")

    # Append our params to whatever is already there
    NEW_VAL="${CURRENT_VAL} ${PARAMS}"
    NEW_LINE="GRUB_CMDLINE_LINUX_DEFAULT=\"${NEW_VAL}\""

    # Replace the line in-place (portable sed with temp file)
    sed -i "\|^GRUB_CMDLINE_LINUX_DEFAULT=|c\\${NEW_LINE}" "${GRUB_DEFAULT}"
    echo "Updated GRUB_CMDLINE_LINUX_DEFAULT with additional parameters."
fi

# Show the resulting line
echo
echo "--- Resulting GRUB_CMDLINE_LINUX_DEFAULT ---"
grep -E "^GRUB_CMDLINE_LINUX_DEFAULT=" "${GRUB_DEFAULT}"
echo

# Regenerate grub.cfg
echo "Running grub-mkconfig..."
if command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "WARNING: grub-mkconfig not found in PATH. You may need to run it manually:" >&2
    echo "  grub-mkconfig -o /boot/grub/grub.cfg" >&2
    exit 1
fi

echo
echo "Done. Reboot for changes to take effect."
echo "Verify after reboot with: cat /proc/cmdline"

