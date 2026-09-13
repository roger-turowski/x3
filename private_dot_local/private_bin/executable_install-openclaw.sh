#!/usr/bin/env bash
#
# install-openclaw.sh — OpenClaw on Arch Linux, rootless Podman + Quadlet.
# Uses the prebuilt ghcr.io image (digest-pinned). Config under ~/.config/openclaw.
# Requires: internet, sudo for pacman/subuid steps. No local image build.
#
set -euo pipefail

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

readonly SRC_DIR="$HOME/.local/src/openclaw"
readonly QUADLET="$HOME/.config/containers/systemd/openclaw.container"
export OPENCLAW_CONFIG_DIR="$HOME/.config/openclaw"
export OPENCLAW_WORKSPACE_DIR="$OPENCLAW_CONFIG_DIR/workspace"
readonly REMOTE_IMAGE="ghcr.io/openclaw/openclaw:latest"

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- [1/6] Packages -----------------------------------------------------
echo "[1/6] Installing packages"
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm podman crun passt fuse-overlayfs git nodejs npm

# --- [2/6] Rootless subuid/subgid (fresh systems have none) --------------
echo "[2/6] Rootless subordinate ID mappings"
ensure_map() { # file, username
  grep -qw "$2" "$1" || printf '%s:100000:65536\n' "$2" | sudo tee -a "$1" >/dev/null
  grep -qw "$2" "$1" || fail "subuid/subgid entry for $2 missing"
}
ensure_map /etc/subuid "$USER"
ensure_map /etc/subgid "$USER"

# --- [3/6] Host CLI (user prefix, no sudo, no /usr pollution) -----------
echo "[3/6] Host CLI"
if ! command -v openclaw >/dev/null; then
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$NODE_MAJOR" -ge 22 ] || fail "Node ${NODE_MAJOR} too old (need 22.22.3+/24.15+/25.9+)"
  mkdir -p "$HOME/.local/lib/node_modules"
  npm config set prefix "$HOME/.local"
  npm install -g openclaw
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"   # adjust for zsh
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v openclaw >/dev/null || fail "openclaw still not on PATH — source ~/.bashrc or re-login"

# --- [4/6] Pull image, pin by digest --------------------------------------
echo "[4/6] Pulling image (digest-pinned)"
podman pull "$REMOTE_IMAGE"
export OPENCLAW_IMAGE="$(podman inspect --format '{{index .RepoDigests 0}}' "$REMOTE_IMAGE")"
echo "  pinned: $OPENCLAW_IMAGE"

# --- [5/6] Clone repo, run upstream setup (config + token + quadlet) ----
echo "[5/6] OpenClaw setup"
if [[ -d "$SRC_DIR" ]]; then
  git -C "$SRC_DIR" pull --ff-only
else
  mkdir -p "$SRC_DIR"
  git clone --depth 1 https://github.com/openclaw/openclaw.git "$SRC_DIR"
fi
cd "$SRC_DIR"
./scripts/podman/setup.sh --quadlet

# Post-conditions the docs imply but do not guarantee — verify, don't assume.
grep -q 'config/openclaw' "$QUADLET" || cat <<WARN
WARN: Quadlet does not reference $OPENCLAW_CONFIG_DIR.
Check: grep Volume $QUADLET
If it hardcodes ~/.openclaw, fix the Volume= line (target side must stay
/home/node/.openclaw) or fall back to: ln -s ~/.config/openclaw ~/.openclaw
WARN
grep -q "$OPENCLAW_IMAGE" "$QUADLET" || echo "WARN: Quadlet does not reference the pinned digest — check: grep Image $QUADLET"

# --- [6/6] Activate + persist + verify -----------------------------------
echo "[6/6] Starting service"
# Generated units cannot be 'enabled' — Quadlet's generator implements
# [Install] itself. Make sure the section exists, then just start.
grep -q '\[Install\]' "$QUADLET" || printf '\n[Install]\nWantedBy=default.target\n' >> "$QUADLET"
systemctl --user daemon-reload
systemctl --user start openclaw.service
loginctl enable-linger "$USER" || sudo loginctl enable-linger "$USER"

echo; echo "=== Verification ==="
sleep 5
systemctl --user is-active openclaw.service \
  && echo "service: active" || { echo "service: NOT ACTIVE"; journalctl --user -u openclaw.service -n 50; exit 1; }
echo "ports:   $(podman port openclaw 2>/dev/null || echo 'none published')"
echo "state:   $(podman ps --filter name=openclaw --format '{{.Status}}')"
cat <<NEXT

Next steps:
  Onboarding / provider keys:  openclaw --container onboard
  Logs:                        journalctl --user -u openclaw.service -f
  Shell rc (recommended, prevents split-brain config):
    export OPENCLAW_CONFIG_DIR="$HOME/.config/openclaw"
NEXT

