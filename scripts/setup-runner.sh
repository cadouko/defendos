#!/usr/bin/env bash
# DefendOS – Setup GitHub Actions Self-Hosted Runner
# Usage: sudo ./setup-runner.sh <REPO_URL> <REGISTRATION_TOKEN>
set -euo pipefail

REPO_URL="${1:?Usage: $0 <REPO_URL> <REGISTRATION_TOKEN>}"
TOKEN="${2:?Usage: $0 <REPO_URL> <REGISTRATION_TOKEN>}"
RUNNER_DIR="/opt/github-runner"
GH_USER="runner"

echo "=== DefendOS Self-Hosted Runner Setup ==="

# 1. Create runner user
if ! id "$GH_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$GH_USER"
    echo "[+] User '$GH_USER' created"
fi

# 2. Install dependencies
pacman -Sy --noconfirm archiso grub edk2-shell jq wget

# 3. Create runner directory
mkdir -p "$RUNNER_DIR"
chown "$GH_USER:$GH_USER" "$RUNNER_DIR"

# 4. Download latest GitHub Actions runner
echo "[+] Downloading GitHub Actions runner..."
su - "$GH_USER" -c "bash <<'SETUP'
cd /opt/github-runner
LATEST=\$(curl -s https://api.github.com/repos/actions/runner/releases/latest)
ASSET_URL=\$(echo \"\$LATEST\" | jq -r '.assets[] | select(.name | contains(\"linux-x64\")) | .browser_download_url')
if [[ -z \"\$ASSET_URL\" || \"\$ASSET_URL\" == \"null\" ]]; then
    echo \"Failed to find runner download URL\"
    exit 1
fi
curl -fSL \"\$ASSET_URL\" -o actions-runner.tar.gz
tar xzf actions-runner.tar.gz
rm actions-runner.tar.gz
SETUP"

# 5. Configure runner
echo "[+] Configuring runner..."
su - "$GH_USER" -c "/opt/github-runner/config.sh --unattended --url $REPO_URL --token $TOKEN --labels linux,arch,defendos --name defendos-builder --work _work --replace"

# 6. Install systemd service
cp "$(dirname "$0")/github-runner.service" /etc/systemd/system/github-runner.service
systemctl daemon-reload
systemctl enable --now github-runner.service

echo ""
echo "[+] Runner installed and started!"
echo "    Status: systemctl status github-runner"
echo "    Logs:   journalctl -u github-runner -f"
