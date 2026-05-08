#!/usr/bin/env bash
# DefendOS – Module Défensif (Blue Team / SIEM light)
# Compatible : Debian/Ubuntu, RHEL/Fedora/Rocky

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
info() { echo -e "${CYAN}[i]${NC} $*"; }

DISTRO_FAMILY="${DISTRO_FAMILY:-}"
PKG_MGR="${PKG_MGR:-}"
if [[ -z "$DISTRO_FAMILY" ]]; then
    if command -v apt-get &>/dev/null; then DISTRO_FAMILY="debian"; PKG_MGR="apt-get"
    elif command -v dnf &>/dev/null;     then DISTRO_FAMILY="rhel";   PKG_MGR="dnf"
    else echo "Distribution non supportée"; exit 1; fi
fi

FAILED=()

log "Installation des outils défensifs (Blue Team / SIEM)..."
log "Distribution : $DISTRO_FAMILY / $PKG_MGR"

# ── 1. Paquets officiels Debian/Ubuntu ────────────────────────
if [[ "$DISTRO_FAMILY" == "debian" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        \
        suricata zeek snort \
        \
        lynis rkhunter clamav clamav-daemon chkrootkit \
        auditd audispd-plugins \
        apparmor apparmor-utils apparmor-profiles \
        fail2ban ufw gufw libpam-pwquality \
        \
        syslog-ng logrotate lnav \
        iotop nethogs iftop bandwidthd \
        \
        wireshark tshark tcpdump ngrep \
        sleuthkit foremost binwalk \
        radare2 \
        gdb \
        \
        openssl gnupg sslscan \
        \
        docker.io docker-compose \
        2>&1 | grep -E "^(Setting up|E:|W:)" || true

# ── 1b. Paquets officiels RHEL/Fedora/Rocky ───────────────────
else
    "$PKG_MGR" install -y \
        \
        suricata snort \
        \
        lynis rkhunter clamav clamav-update chkrootkit \
        audit \
        fail2ban firewalld libpwquality \
        \
        syslog-ng logrotate \
        iotop nethogs iftop \
        \
        wireshark-cli tcpdump ngrep \
        sleuthkit foremost binwalk \
        radare2 \
        gdb \
        \
        openssl gnupg \
        \
        docker docker-compose \
        2>&1 | grep -E "^(Installing|Error|Warning)" || true
fi

# ── 2. Volatility3 (pip) ─────────────────────────────────────
if ! command -v vol &>/dev/null && ! command -v volatility3 &>/dev/null; then
    log "Installation de Volatility3 via pip..."
    pip3 install --quiet --break-system-packages volatility3 2>/dev/null || \
    pip3 install --quiet volatility3 2>/dev/null || \
        { warn "Volatility3 non installé"; FAILED+=("volatility3"); }
fi

# ── 3. Autopsy (forensics GUI) ────────────────────────────────
install_autopsy() {
    if command -v autopsy &>/dev/null; then log "Autopsy déjà installé"; return 0; fi
    log "Installation d'Autopsy..."
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y autopsy 2>/dev/null && \
            log "Autopsy installé" && return 0
    fi
    warn "Autopsy non disponible via $PKG_MGR"
    warn "Installation manuelle : https://www.sleuthkit.org/autopsy/"
    FAILED+=("autopsy")
}
install_autopsy || true

# ── 4. Zeek (si non installé via apt) ────────────────────────
install_zeek() {
    if command -v zeek &>/dev/null; then log "Zeek déjà installé"; return 0; fi

    if [[ "$DISTRO_FAMILY" == "rhel" ]]; then
        log "Ajout du dépôt Zeek pour RHEL/Fedora..."
        local os_ver
        os_ver=$(rpm -E %{rhel} 2>/dev/null || echo "9")
        "$PKG_MGR" install -y \
            "https://download.opensuse.org/repositories/security:/zeek/CentOS_${os_ver}/x86_64/zeek-lts-${os_ver}.rpm" \
            2>/dev/null || warn "Zeek : rpm non installable"
    fi
}
install_zeek || true

# ── 5. Wazuh Agent ───────────────────────────────────────────
install_wazuh() {
    if command -v wazuh-agentd &>/dev/null || \
       systemctl is-active wazuh-agent &>/dev/null 2>&1; then
        log "Wazuh Agent déjà installé"
        return 0
    fi

    log "Installation de Wazuh Agent..."
    local wazuh_ver="4.9.0"

    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        # Dépôt Wazuh officiel
        curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH \
            | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg 2>/dev/null || true
        echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
            > /etc/apt/sources.list.d/wazuh.list 2>/dev/null || true
        apt-get update -qq 2>/dev/null || true
        DEBIAN_FRONTEND=noninteractive apt-get install -y wazuh-agent 2>/dev/null && \
            log "Wazuh Agent installé" && return 0
    else
        # Dépôt RPM Wazuh
        cat > /etc/yum.repos.d/wazuh.repo <<'REPO'
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
REPO
        "$PKG_MGR" install -y wazuh-agent 2>/dev/null && \
            log "Wazuh Agent installé" && return 0
    fi

    warn "Wazuh Agent non installé automatiquement."
    warn "Installation manuelle : https://documentation.wazuh.com/current/installation-guide/"
    FAILED+=("wazuh-agent")
}
install_wazuh || true

# ── 6. Configuration Suricata ─────────────────────────────────
if command -v suricata &>/dev/null; then
    log "Configuration Suricata..."
    suricata-update 2>/dev/null || warn "suricata-update échoué (pas de connexion ?)"
    systemctl enable suricata 2>/dev/null || true
fi

# ── 7. Configuration ClamAV ──────────────────────────────────
if command -v freshclam &>/dev/null; then
    log "Mise à jour des signatures ClamAV..."
    freshclam --quiet 2>/dev/null || warn "freshclam échoué"
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        systemctl enable --now clamav-freshclam 2>/dev/null || true
    else
        systemctl enable --now clamav-freshclam 2>/dev/null || \
            systemctl enable --now clamd@scan 2>/dev/null || true
    fi
fi

# ── 8. GDB + pwndbg ──────────────────────────────────────────
install_pwndbg() {
    if python3 -c "import pwndbg" 2>/dev/null; then log "pwndbg déjà installé"; return 0; fi
    log "Installation de pwndbg (plugin GDB)..."
    local tmp; tmp=$(mktemp -d)
    if git clone --depth=1 https://github.com/pwndbg/pwndbg.git "$tmp/pwndbg" 2>/dev/null; then
        pushd "$tmp/pwndbg" > /dev/null
        bash setup.sh 2>/dev/null && log "pwndbg installé" || warn "pwndbg : setup échoué"
        popd > /dev/null
    else
        warn "pwndbg : clone échoué"
        FAILED+=("pwndbg")
    fi
    rm -rf "$tmp"
}
install_pwndbg || true

# ── 9. testssl.sh ─────────────────────────────────────────────
if ! command -v testssl &>/dev/null && ! command -v testssl.sh &>/dev/null; then
    log "Installation de testssl.sh..."
    curl -fsSL https://testssl.sh/testssl.sh -o /usr/local/bin/testssl.sh 2>/dev/null && \
        chmod +x /usr/local/bin/testssl.sh && \
        ln -sf /usr/local/bin/testssl.sh /usr/local/bin/testssl && \
        log "testssl.sh installé" || \
        { warn "testssl.sh : téléchargement échoué"; FAILED+=("testssl.sh"); }
fi

# ── 10. sslscan / sslyze ─────────────────────────────────────
pip3 install --quiet --break-system-packages sslyze 2>/dev/null || \
pip3 install --quiet sslyze 2>/dev/null || true

# ── Rapport ───────────────────────────────────────────────────
echo ""
log "✅ Module Défensif installé"
if (( ${#FAILED[@]} > 0 )); then
    warn "Outils non installés automatiquement :"
    for p in "${FAILED[@]}"; do echo "   - $p"; done
    echo ""
    info "Consultez docs/tools-defensif.md pour les liens de téléchargement."
fi
