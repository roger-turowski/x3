#! /usr/bin/env bash

# --- Guard: must run as a normal user, not root ---

if [ "$(id -u)" -eq 0 ]; then
  echo "FAIL: Do not run this script as root or with sudo."
  echo "      It deploys rootless Podman containers under the invoking user."
  echo "      The script calls sudo itself where elevated privileges are needed."
  exit 1
fi

# Optional: verify sudo is usable non-interactively, since the script
# invokes it mid-run and failing there is worse than failing here:
sudo -v || { echo "FAIL: passwordless sudo prompt unavailable"; exit 1; }

mkdir -p "${HOME}/podman/open-webui"

# Podman command line:
# podman run -d \
#  --name open-webui \
#  -p 3000:8080 \
#  --userns=keep-id \
#  -v ~/podman/open-webui:/app/backend/data:Z \
#  --restart=always \
#  ghcr.io/open-webui/open-webui:main

# Create the Quadlet Unit
mkdir -p "${HOME}/.config/containers/systemd"

cat << EOF > "${HOME}/.config/containers/systemd/open-webui.container"
[Unit]
Description=Open WebUI (rootless Podman)
Wants=network-online.target
After=network-online.target

[Container]
Image=ghcr.io/open-webui/open-webui:main
ContainerName=open-webui
AutoUpdate=registry
Volume=%h/podman/open-webui:/app/backend/data:Z
Environment=UVICORN_HEADERS="X-Accel-Buffering:\ no"
Environment=OLLAMA_BASE_URL=http://192.168.2.73:11434
Environment=WEBUI_AUTH=true
HostName=open-webui
Network=host

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=default.target
EOF

#Load and Start
systemctl --user daemon-reload
systemctl --user start open-webui.service

# Enable at Boot + Auto-Updates
sudo loginctl enable-linger roger

#  Automate image updates
systemctl --user enable podman-auto-update.timer
systemctl --user start podman-auto-update.timer

sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

