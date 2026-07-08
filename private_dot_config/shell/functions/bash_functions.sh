is_file_exists() {
    local f="$1"
    if [[ -f "$f" ]]; then
        return 0  # Success
    else
        return 1  # Failure
    fi
}

chezmoi-cd() {
  cd "$(chezmoi source-path "$@")"
}

# Kill process by name (interactive confirmation)
killbyname() {
    [[ -z "$1" ]] && { echo "Usage: killbyname <pattern>"; return 1; }
    pgrep -af "$1"
    read -p "Kill these? [y/N] " && pkill -9 -f "$1"
    echo
}
