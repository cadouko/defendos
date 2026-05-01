#!/usr/bin/env bash
# DefendOS – Module Défensif (Blue Team / SIEM light)

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

log "Installation des outils défensifs (Blue Team / SIEM)..."

TOOLS=(
    # IDS / NDR
    suricata zeek snort
    # Hardening & audit
    lynis rkhunter clamav chkrootkit
    audit apparmor apparmor-profiles
    fail2ban ufw gufw libpwquality
    # Monitoring
    syslog-ng logrotate lnav
    iotop nethogs iftop
    # Forensics / analyse
    wireshark-qt tcpdump tshark ngrep
    volatility3 autopsy sleuthkit foremost binwalk
    # Misc
    openssl gnupg hashdeep ssldump sslscan
)

FAILED=()
for pkg in "${TOOLS[@]}"; do
    if ! pacman -S --noconfirm --needed "$pkg" 2>/dev/null; then
        warn "Paquet non trouvé : $pkg"
        FAILED+=("$pkg")
    fi
done

# ── Configuration Suricata ────────────────────────────────────
if command -v suricata &>/dev/null; then
    log "Configuration Suricata..."
    suricata-update 2>/dev/null || warn "suricata-update échoué (pas de connexion ?)"
    systemctl enable suricata 2>/dev/null || true
fi

# ── Configuration ClamAV ──────────────────────────────────────
if command -v freshclam &>/dev/null; then
    log "Mise à jour des signatures ClamAV..."
    freshclam --quiet 2>/dev/null || warn "freshclam échoué"
    systemctl enable --now clamav-freshclam 2>/dev/null || true
fi

# ── Wazuh Agent (via AUR ou script officiel) ──────────────────
install_wazuh() {
    log "Installation de Wazuh Agent..."
    if command -v yay &>/dev/null; then
        yay -S --noconfirm wazuh-agent 2>/dev/null && return 0
    fi
    # Fallback : script officiel Wazuh
    local wazuh_ver="4.7.0"
    local pkg_url="https://packages.wazuh.com/4.x/arch/wazuh-agent-${wazuh_ver}-1-x86_64.pkg.tar.zst"
    if curl -fsSL "$pkg_url" -o /tmp/wazuh-agent.pkg.tar.zst 2>/dev/null; then
        pacman -U --noconfirm /tmp/wazuh-agent.pkg.tar.zst && \
            log "Wazuh Agent installé" && return 0
    fi
    warn "Wazuh Agent non installé automatiquement."
    warn "Installation manuelle : https://documentation.wazuh.com/current/installation-guide/"
}
install_wazuh || true

log "✅ Module Défensif installé"
if (( ${#FAILED[@]} > 0 )); then
    warn "Paquets non installés :"
    for p in "${FAILED[@]}"; do echo "   - $p"; done
fi
