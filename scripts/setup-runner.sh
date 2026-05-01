#!/usr/bin/env bash
# DefendOS – Setup GitHub Actions Self-Hosted Runner
# Usage: sudo ./setup-runner.sh <REPO_URL> <REGISTRATION_TOKEN>
set -euo pipefail

REPO_URL="${1:?Usage: $0 <REPO_URL> <REGISTRATION_TOKEN>}"
TOKEN="${2:?Usage: $0 <REPO_URL> <REGISTRATION_TOKEN>}"
RUNNER_DIR="/opt/github-runner"
GH_USER="runner"

echo "=== DefendOS Self-Hosted Runner Setup ==="

# 1. Install dependencies
echo "[+] Installing dependencies..."
pacman -S --noconfirm --needed archiso grub edk2-shell jq curl

# 2. Create runner user and directory
echo "[+] Creating runner user..."
if ! id "$GH_USER" &>/dev/null; then
    useradd -r -m -s /bin/bash "$GH_USER"
fi
mkdir -p "$RUNNER_DIR"
chown "$GH_USER:$GH_USER" "$RUNNER_DIR"

# 3. Download GitHub Actions runner (as root, then chown)
echo "[+] Downloading GitHub Actions runner..."
LATEST_JSON=$(curl -s https://api.github.com/repos/actions/runner/releases/latest)
ASSET_URL=$(echo "$LATEST_JSON" | jq -r '.assets[] | select(.name | contains("linux-x64")) | .browser_download_url')

if [[ -z "$ASSET_URL" || "$ASSET_URL" == "null" ]]; then
    echo "Failed to find runner download URL. Manual download needed."
    echo "Visit: https://github.com/actions/runner/releases/latest"
    exit 1
fi

echo "Downloading from: $ASSET_URL"
curl -fSL "$ASSET_URL" -o "$RUNNER_DIR/actions-runner.tar.gz"

# Verify download
if [[ ! -s "$RUNNER_DIR/actions-runner.tar.gz" ]]; then
    echo "Download failed (empty file)"
    exit 1
fi

# Extract
tar xzf "$RUNNER_DIR/actions-runner.tar.gz" -C "$RUNNER_DIR"
rm -f "$RUNNER_DIR/actions-runner.tar.gz"

# Verify extraction
if [[ ! -x "$RUNNER_DIR/config.sh" ]]; then
    echo "Extraction failed (config.sh missing or not executable)"
    exit 1
fi

echo "[+] Extracted runner v$(cat "$RUNNER_DIR/VERSION")"

# Set ownership
chown -R "$GH_USER:$GH_USER" "$RUNNER_DIR"

# 4. Configure runner
echo "[+] Configuring runner..."
runuser -u "$GH_USER" -- "$RUNNER_DIR/config.sh" --unattended \
    --url "$REPO_URL" \
    --token "$TOKEN" \
    --labels linux,arch,defendos \
    --name defendos-builder \
    --work _work \
    --replace

# 5. Install systemd service
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[+] Installing systemd service..."
cp "$SCRIPT_DIR/github-runner.service" /etc/systemd/system/github-runner.service
systemctl daemon-reload
systemctl enable --now github-runner.service

echo ""
echo "[+] Runner installed and started!"
echo "    Status: systemctl status github-runner"
echo "    Logs:   journalctl -u github-runner -f"
