#!/usr/bin/env bash
#===============================================================================
# Script: set_hostname.sh
# Description: Changes the system hostname across supported Linux distributions.
#              Supports Arch, OpenSUSE Tumbleweed, Ubuntu, Fedora, Debian.
# Author: Lumo (for Roger's Dotfiles)
# Version: 1.0
#===============================================================================

set -euo pipefail

# --- Configuration ---
readonly SCRIPT_NAME="$(basename "$0")"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly BACKUP_DIR="/var/tmp/hostname_backups_${TIMESTAMP}"
readonly SUPPORTED_OS=("arch" "opensuse-tumbleweed" "ubuntu" "fedora" "debian")

# --- Color Codes for Output ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# --- Helper Functions ---

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

die() {
    log_error "$1"
    exit 1
}

# --- OS Detection ---
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        die "/etc/os-release not found. Cannot detect OS."
    fi

    # shellcheck source=/dev/null
    . /etc/os-release

    case "${ID}" in
        arch)
            echo "arch"
            ;;
        opensuse-tumbleweed|opensuse)
            # Normalize opensuse variants to tumbleweed if applicable, 
            # but standard ID is usually 'opensuse-tumbleweed' or 'opensuse-leap'
            if [[ "${ID_LIKE:-}" == *"suse"* ]] || [[ "${ID}" == *"suse"* ]]; then
                echo "opensuse-tumbleweed"
            else
                die "OpenSUSE variant detected but not Tumbleweed. This script currently targets Tumbleweed."
            fi
            ;;
        ubuntu|debian)
            # Ubuntu and Debian often share the same package managers/configs for hostname
            echo "${ID}"
            ;;
        fedora)
            echo "fedora"
            ;;
        *)
            die "Unsupported OS detected: ${ID}. Supported: ${SUPPORTED_OS[*]}"
            ;;
    esac
}

# --- Input Validation ---
validate_hostname() {
    local hostname="$1"

    # Check if empty
    if [[ -z "$hostname" ]]; then
        die "Hostname cannot be empty."
    fi

    # Check length (RFC 1123 recommends max 63 chars per label, total 255)
    if [[ ${#hostname} -gt 63 ]]; then
        die "Hostname too long (max 63 characters)."
    fi

    # Regex for valid hostname: alphanumeric, hyphens, dots. 
    # Must start/end with alphanumeric. No spaces or special chars.
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.]*[a-zA-Z0-9])?$ ]]; then
        die "Invalid hostname format. Only alphanumeric characters, hyphens (-), and dots (.) are allowed. Cannot start or end with a hyphen or dot."
    fi

    # Check for spaces specifically (regex covers most, but explicit check helps clarity)
    if [[ "$hostname" == *" "* ]]; then
        die "Hostnames cannot contain spaces."
    fi
}

# --- Backup Logic ---
create_backups() {
    log_info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR" || die "Failed to create backup directory. Do you have sudo privileges?"

    local files_to_backup=("/etc/hostname" "/etc/hosts")

    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            cp -v "$file" "$BACKUP_DIR/" || die "Failed to backup $file"
            log_info "Backed up $file to $BACKUP_DIR"
        else
            log_warn "$file does not exist, skipping backup."
        fi
    done
}

# --- Hostname Change Logic ---
apply_changes() {
    local new_hostname="$1"
    local os_type="$2"

    log_info "Applying hostname '$new_hostname' for $os_type..."

    # 1. Update /etc/hostname
    # Using printf to ensure no trailing newline issues if the file was weirdly formatted
    echo "$new_hostname" | sudo tee /etc/hostname > /dev/null || die "Failed to write to /etc/hostname"
    log_info "Updated /etc/hostname"

    # 2. Update /etc/hosts
    # We need to replace the old hostname with the new one on the localhost line (usually 127.0.0.1 or ::1)
    # Strategy: Find lines starting with 127.0.0.1 or ::1 and replace the old hostname token.
    
    local old_hostname
    old_hostname=$(cat /etc/hostname.bak 2>/dev/null || hostname) # Fallback if backup not created yet (shouldn't happen here)
    
    # If we just ran the backup, we might want to read the *original* from the backup if available, 
    # but simpler is to just replace the current content if it matches the old hostname.
    # However, since we already wrote to /etc/hostname above, we need to be careful.
    # Actually, /etc/hosts usually has the OLD hostname. We should have captured it before writing /etc/hostname.
    # Correction: Let's capture the OLD hostname BEFORE writing /etc/hostname in the main flow.
    # But since this function is called after validation, let's assume we passed the OLD hostname as an arg?
    # Better approach: Read the OLD hostname from the backup we just made.
    
    if [[ -f "$BACKUP_DIR/hostname" ]]; then
        old_hostname=$(cat "$BACKUP_DIR/hostname")
    else
        # Fallback: try to get current hostname before we changed it (if script logic allows)
        # Since we already changed /etc/hostname, we rely on the backup.
        old_hostname="localhost" # Safe fallback if backup failed somehow
    fi

    if [[ "$old_hostname" != "$new_hostname" ]]; then
        # Use sed to replace the old hostname with the new one in /etc/hosts
        # Escape dots in hostname for regex safety
        local escaped_old
        escaped_old=$(printf '%s\n' "$old_hostname" | sed 's/[\/&]/\\&/g')
        
        sudo sed -i "s/\b${escaped_old}\b/${new_hostname}/g" /etc/hosts || die "Failed to update /etc/hosts"
        log_info "Updated /etc/hosts (replaced '${old_hostname}' with '${new_hostname}')"
    else
        log_info "Hostname unchanged in /etc/hosts (already matches)."
    fi

    # 3. Distribution Specific Actions (if necessary)
    case "$os_type" in
        arch|fedora|ubuntu|debian)
            # systemd-based systems usually pick up changes on next boot or require hostnamectl
            # We use hostnamectl to update the transient/static hostname immediately without reboot
            if command -v hostnamectl &> /dev/null; then
                sudo hostnamectl set-hostname "$new_hostname"
                log_info "Systemd hostname updated via hostnamectl."
            fi
            ;;
        opensuse-tumbleweed)
            # OpenSUSE also uses systemd/hostnamectl
            if command -v hostnamectl &> /dev/null; then
                sudo hostnamectl set-hostname "$new_hostname"
                log_info "Systemd hostname updated via hostnamectl."
            fi
            ;;
    esac
}

# --- Main Execution ---
main() {
    local target_hostname=""

    # 1. Detect OS
    local os_detected
    os_detected=$(detect_os)
    log_info "Detected OS: $os_detected"

    # 2. Get New Hostname
    if [[ $# -gt 0 ]]; then
        # Command line argument provided
        target_hostname="$1"
        log_info "Using hostname from argument: $target_hostname"
    else
        # Interactive prompt
        read -rp "Enter new hostname: " target_hostname
        if [[ -z "$target_hostname" ]]; then
            die "No hostname provided."
        fi
    fi

    # 3. Validate
    validate_hostname "$target_hostname"

    # 4. Capture Old Hostname for /etc/hosts replacement BEFORE modifying files
    local old_hostname
    if [[ -f /etc/hostname ]]; then
        old_hostname=$(cat /etc/hostname)
    else
        old_hostname=$(hostname 2>/dev/null || echo "unknown")
    fi
    log_info "Current hostname: $old_hostname"

    if [[ "$old_hostname" == "$target_hostname" ]]; then
        log_warn "New hostname is identical to current hostname. Exiting."
        exit 0
    fi

    # 5. Create Backups
    create_backups

    # 6. Apply Changes
    apply_changes "$target_hostname" "$os_detected"

    # 7. Final Status
    echo ""
    log_info "=========================================="
    log_info "SUCCESS: Hostname changed to '$target_hostname'"
    log_info "Backups stored in: $BACKUP_DIR"
    log_info "Please reboot or run 'sudo systemctl restart systemd-hostnamed' for full propagation."
    log_info "=========================================="
}

# Run main
main "$@"

