# Kill process by name (interactive confirmation)
killbyname() {
    [[ -z "$1" ]] && { echo "Usage: killbyname <pattern>"; return 1; }
    pgrep -af "$1"
    read -q "REPLY?Kill these? [y/N] " && pkill -9 -f "$1"
    echo
}


