weather() {
  if [ $# -eq 0 ]; then
    curl wttr.in
  else
    curl wttr.in/"$1"
  fi
}

# Quick port scan wrapper using nmap
quickscan() {
    [[ -z "$1" ]] && { echo "Usage: quickscan <host>"; return 1; }
    nmap -T4 -F --top-ports 50 "$1"
}

# Grab HTTP headers fast
headers() {
    [[ -z "$1" ]] && { echo "Usage: headers <url>"; return 1; }
    curl -sI "$1" | sed '/^$/d'
}

# Resolve all IPs for a hostname (IPv4+IPv6)
resolve() {
    [[ -z "$1" ]] && { echo "Usage: resolve <hostname>"; return 1; }
    dig +short "$1" A; dig +short "$1" AAAA
}

# Find what's listening on a given port
port() {
    [[ -z "$1" ]] && { echo "Usage: port <port>"; return 1; }
    lsof -iTCP:"$1" -sTCP:LISTEN 2>/dev/null || ss -tlnp | grep ":$1"
}

# Extract any archive format
extract() {
    [[ -z "$1" ]] && { echo "Usage: extract <file>"; return 1; }
    case "$1" in
        *.tar.gz|*.tgz)  tar xzf "$1" ;;
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.xz)        tar xJf "$1" ;;
        *.tar)           tar xf "$1" ;;
        *.zip)           unzip "$1" ;;
        *.7z)            7z x "$1" ;;
        *.rar)           unrar x "$1" ;;
        *) echo "Unknown format: $1"; return 1 ;;
    esac
}

# Generate a strong random token
token() {
    openssl rand -base64 "${1:-32}"
}

# Base64 encode/decode shortcuts
b64e() { echo -n "$1" | base64; }
b64d() { echo "$1" | base64 -d; echo; }

# Fresh clone + cd into it
clone() {
    git clone "$1" && cd "$(basename "$1" .git)"
}

# Amend last commit message without opening editor
gfixmsg() {
    [[ -z "$1" ]] && { echo "Usage: gfixmsg <message>"; return 1; }
    git commit --amend -m "$1"
}

# Tail docker logs with container name completion (zsh-only for the completion)
dlog() {
    [[ -z "$1" ]] && { echo "Usage: dlog <container>"; return 1; }
    docker logs -f --tail 100 "$1"
}

# SSH into a host by private IP shorthand — adapt ranges to your lab
labssh() {
    [[ -z "$1" ]] && { echo "Usage: labssh <last-octet>"; return 1; }
    ssh "10.0.0.$1"
}

# In your shell rc or a script
tmux-new-ssh() {
    local host=$(awk '/^Host / {print $2}' ~/.ssh/config | fzf --prompt="SSH> ")
    [[ -n "$host" ]] && tmux new-window -n "$host" "ssh $host"
}

