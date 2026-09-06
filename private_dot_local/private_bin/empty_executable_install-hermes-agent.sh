#!/usr/bin/env bash
#
# install-hermes-podman.sh — Hermes Agent on Arch Linux, rootless Podman + quadlet.
# Verified working: 2026-09-06 on ser10max (Podman 6.1.1).
# Sources: NousResearch/hermes-agent docs + tested on this host.
#
set -euo pipefail

HERMES_USER="${HERMES_USER:-$USER}"
HERMES_HOME="$HOME/.hermes"
ENV_FILE="$HERMES_HOME/.env"
QUADLET="$HOME/.config/containers/systemd/hermes.container"
IMAGE="docker.io/nousresearch/hermes-agent:latest"
HERMES_UID="$(id -u)"
HERMES_GID="$(id -g)"

echo "[1/7] Installing packages"
sudo pacman -Syu
sudo pacman -S --needed podman crun passt fuse-overlayfs

echo "[2/7] Rootless subordinate ID mappings"
if ! grep -qw "$HERMES_USER" /etc/subuid; then
  echo "$HERMES_USER:100000:65536" | sudo tee -a /etc/subuid >/dev/null
fi
if ! grep -qw "$HERMES_USER" /etc/subgid; then
  echo "$HERMES_USER:100000:65536" | sudo tee -a /etc/subgid >/dev/null
fi
grep -qw "$HERMES_USER" /etc/subuid || { echo "FAIL: subuid entry missing"; exit 1; }
grep -qw "$HERMES_USER" /etc/subgid || { echo "FAIL: subgid entry missing"; exit 1; }

echo "[3/7] Pulling image"
podman pull "$IMAGE"

echo "[4/7] Data dir + API server key"
mkdir -p "$HERMES_HOME"
touch "$ENV_FILE"
if ! grep -q '^API_SERVER_ENABLED=' "$ENV_FILE"; then
  echo "API_SERVER_ENABLED=true" >> "$ENV_FILE"
else
  sed -i 's/^API_SERVER_ENABLED=.*/API_SERVER_ENABLED=true/' "$ENV_FILE"
fi
if ! grep -q '^API_SERVER_KEY=' "$ENV_FILE"; then
  echo "API_SERVER_KEY=$(openssl rand -hex 32)" >> "$ENV_FILE"
  echo "  Generated new API_SERVER_KEY"
else
  echo "  Existing API_SERVER_KEY kept"
fi

echo "[5/7] Writing quadlet: $QUADLET"
mkdir -p "$(dirname "$QUADLET")"
cat > "$QUADLET" <<EOF
[Unit]
Description=Hermes Agent gateway
After=network-online.target

[Container]
Image=$IMAGE
ContainerName=hermes
Exec=gateway run
Environment=HERMES_UID=$HERMES_UID
Environment=HERMES_GID=$HERMES_GID
Volume=%h/.hermes:/opt/data
Network=host
PodmanArgs=--memory=4g --cpus=2

[Service]
Restart=always

[Install]
WantedBy=default.target
EOF

echo "[6/7] Activating service"
systemctl --user reset-failed hermes.service 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable --now hermes.service

echo "[7/7] Boot persistence (linger)"
loginctl enable-linger "$HERMES_USER" 2>/dev/null || \
  sudo loginctl enable-linger "$HERMES_USER"

KEY="$(grep -oP '(?<=^API_SERVER_KEY=).*' "$ENV_FILE")"

echo
echo "=== Verification ==="
sleep 3
systemctl --user is-active hermes.service && echo "service: active" || \
  echo "service: NOT ACTIVE — check: journalctl --user -u hermes -f"
echo "health:  $(curl -s http://127.0.0.1:8642/health)"
echo "bind:    $(ss -tlp | grep 8642 || echo 'NOTHING LISTENING')"
if curl -s -H "Authorization: Bearer $KEY" http://127.0.0.1:8642/v1/models | grep -q hermes-agent; then
  echo "models:  auth OK"
else
  echo "models:  auth FAILED — key: $KEY"
fi
echo
echo "API key: $KEY"
echo "OpenWebUI base URL: http://127.0.0.1:8642/v1"

