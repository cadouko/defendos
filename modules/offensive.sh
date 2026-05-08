#!/usr/bin/env bash
# DefendOS – Module Offensif (Pentest / Red Team)
# Compatible : Debian/Ubuntu, RHEL/Fedora/Rocky
# Appelé par install.sh (hérite de DISTRO_FAMILY, PKG_MGR)

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()   { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
info()  { echo -e "${CYAN}[i]${NC} $*"; }

# Hériter ou détecter la famille de distro
DISTRO_FAMILY="${DISTRO_FAMILY:-}"
PKG_MGR="${PKG_MGR:-}"
if [[ -z "$DISTRO_FAMILY" ]]; then
    if command -v apt-get &>/dev/null; then DISTRO_FAMILY="debian"; PKG_MGR="apt-get"
    elif command -v dnf &>/dev/null;     then DISTRO_FAMILY="rhel";   PKG_MGR="dnf"
    else echo "Distribution non supportée"; exit 1; fi
fi

# ── Architecture pour les binaires ────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH_GO="amd64"  ; ARCH_SUFFIX="linux_amd64"  ;;
    aarch64) ARCH_GO="arm64"  ; ARCH_SUFFIX="linux_arm64"  ;;
    armv7l)  ARCH_GO="arm"    ; ARCH_SUFFIX="linux_armv7"  ;;
    *)       ARCH_GO="amd64"  ; ARCH_SUFFIX="linux_amd64"  ; warn "Arch $ARCH non reconnue, amd64 par défaut" ;;
esac

FAILED=()

# ── Fonction d'installation de paquets ───────────────────────
pkg_install() {
    local pkg_debian="$1"
    local pkg_rhel="${2:-$1}"
    local pkg
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then pkg="$pkg_debian"; else pkg="$pkg_rhel"; fi
    if [[ -z "$pkg" || "$pkg" == "-" ]]; then return 0; fi
    if DEBIAN_FRONTEND=noninteractive "$PKG_MGR" install -y --no-install-recommends "$pkg" 2>/dev/null; then
        return 0
    else
        warn "Paquet non trouvé : $pkg"
        FAILED+=("$pkg")
        return 1
    fi
}

# ── Fonction installation binaire Go (GitHub releases) ───────
install_go_binary() {
    local name="$1"
    local binary="$2"
    local url="$3"    # URL directe ou template avec {{ARCH}}

    if command -v "$binary" &>/dev/null; then
        log "$name déjà installé"
        return 0
    fi

    local resolved_url="${url//\{\{ARCH\}\}/$ARCH_GO}"
    resolved_url="${resolved_url//\{\{ARCH_SUFFIX\}\}/$ARCH_SUFFIX}"

    log "Téléchargement de $name..."
    local tmp
    tmp=$(mktemp -d)

    if curl -fsSL "$resolved_url" -o "$tmp/tool.pkg" 2>/dev/null; then
        # Tenter tar.gz puis zip
        if tar -xzf "$tmp/tool.pkg" -C "$tmp/" 2>/dev/null; then
            :
        elif unzip -q "$tmp/tool.pkg" -d "$tmp/" 2>/dev/null; then
            :
        else
            # Peut-être un binaire direct
            chmod +x "$tmp/tool.pkg"
            install -m755 "$tmp/tool.pkg" "/usr/local/bin/$binary"
            rm -rf "$tmp"
            log "$name installé"
            return 0
        fi

        local found_bin
        found_bin=$(find "$tmp" -name "$binary" -type f 2>/dev/null | head -1)
        if [[ -n "$found_bin" ]]; then
            install -m755 "$found_bin" "/usr/local/bin/$binary"
            log "$name installé → /usr/local/bin/$binary"
        else
            warn "$name : binaire '$binary' non trouvé dans l'archive"
            FAILED+=("$name")
        fi
    else
        warn "$name : téléchargement échoué ($resolved_url)"
        FAILED+=("$name")
    fi

    rm -rf "$tmp"
}

# ── Fonction installation via pip3 ────────────────────────────
pip_install() {
    local name="$1"
    local pkg="${2:-$1}"
    log "pip3 install $pkg..."
    pip3 install --quiet --break-system-packages "$pkg" 2>/dev/null || \
    pip3 install --quiet "$pkg" 2>/dev/null || \
        { warn "pip3 : $pkg non installé"; FAILED+=("$name (pip)"); }
}

# ── Fonction installation via gem (Ruby) ─────────────────────
gem_install() {
    local name="$1"
    local pkg="${2:-$1}"
    if ! command -v gem &>/dev/null; then
        if [[ "$DISTRO_FAMILY" == "debian" ]]; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ruby-full 2>/dev/null || true
        else
            "$PKG_MGR" install -y ruby 2>/dev/null || true
        fi
    fi
    gem install "$pkg" --no-document 2>/dev/null || \
        { warn "gem : $pkg non installé"; FAILED+=("$name (gem)"); }
}

log "Installation des outils offensifs (Pentest / Red Team)..."
log "Distribution : $DISTRO_FAMILY / $PKG_MGR"

# ── 1. Paquets disponibles dans les dépôts officiels ─────────
log "Installation des outils via $PKG_MGR..."

if [[ "$DISTRO_FAMILY" == "debian" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        nmap masscan \
        nikto \
        sqlmap \
        hashcat john \
        hydra medusa \
        crunch \
        aircrack-ng hcxtools hcxdumptool \
        netcat-openbsd socat proxychains4 \
        mitmproxy \
        tcpdump tshark wireshark \
        python3-impacket \
        python3-requests python3-scapy \
        git curl wget ruby-full \
        wordlists \
        2>&1 | grep -E "^(Setting up|E:|W:)" || true
else
    # RHEL / Fedora
    "$PKG_MGR" install -y \
        nmap masscan \
        nikto \
        sqlmap \
        hashcat john \
        hydra medusa \
        crunch \
        aircrack-ng \
        ncat socat proxychains-ng \
        python3-requests python3-scapy \
        git curl wget ruby \
        2>&1 | grep -E "^(Installing|Error|Warning)" || true
fi

# ── 2. Outils Go – binaires depuis GitHub ────────────────────
log "Installation des outils Go (binaires GitHub)..."

# Nuclei – scanner de vulnérabilités
install_go_binary "nuclei" "nuclei" \
    "https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_linux_{{ARCH_SUFFIX}}.zip"

# Subfinder
install_go_binary "subfinder" "subfinder" \
    "https://github.com/projectdiscovery/subfinder/releases/latest/download/subfinder_linux_{{ARCH_SUFFIX}}.zip"

# Httpx
install_go_binary "httpx" "httpx" \
    "https://github.com/projectdiscovery/httpx/releases/latest/download/httpx_linux_{{ARCH_SUFFIX}}.zip"

# Dnsx
install_go_binary "dnsx" "dnsx" \
    "https://github.com/projectdiscovery/dnsx/releases/latest/download/dnsx_linux_{{ARCH_SUFFIX}}.zip"

# Naabu (scanner de ports)
install_go_binary "naabu" "naabu" \
    "https://github.com/projectdiscovery/naabu/releases/latest/download/naabu_linux_{{ARCH_SUFFIX}}.zip"

# Katana (web crawler)
install_go_binary "katana" "katana" \
    "https://github.com/projectdiscovery/katana/releases/latest/download/katana_linux_{{ARCH_SUFFIX}}.zip"

# ffuf – fuzzer web
install_go_binary "ffuf" "ffuf" \
    "https://github.com/ffuf/ffuf/releases/latest/download/ffuf_linux_{{ARCH_SUFFIX}}.tar.gz"

# Gobuster
install_go_binary "gobuster" "gobuster" \
    "https://github.com/OJ/gobuster/releases/latest/download/gobuster_Linux_{{ARCH_SUFFIX}}.tar.gz"

# Feroxbuster
install_go_binary "feroxbuster" "feroxbuster" \
    "https://github.com/epi052/feroxbuster/releases/latest/download/x86_64-linux-feroxbuster.zip"

# Amass
install_go_binary "amass" "amass" \
    "https://github.com/owasp-amass/amass/releases/latest/download/amass_Linux_{{ARCH_SUFFIX}}.zip"

# Rustscan
install_go_binary "rustscan" "rustscan" \
    "https://github.com/RustScan/RustScan/releases/latest/download/rustscan_linux_{{ARCH_SUFFIX}}.tar.gz"

# ── 3. Outils Python (pip) ────────────────────────────────────
log "Installation des outils Python..."
pip_install "theharvester"   "theHarvester"
pip_install "recon-ng"       "recon-ng"
pip_install "wapiti"         "wapiti3"
pip_install "commix"         "commix"
pip_install "crackmapexec"   "crackmapexec"
pip_install "pwntools"       "pwntools"

# ── 4. Outils Ruby (gem) ─────────────────────────────────────
log "Installation des outils Ruby (gem)..."
gem_install "cewl"      "cewl"
gem_install "evil-winrm" "evil-winrm"

# ── 5. Metasploit ─────────────────────────────────────────────
install_metasploit() {
    if command -v msfconsole &>/dev/null; then
        log "Metasploit déjà installé"
        return 0
    fi

    log "Installation de Metasploit Framework..."
    local tmp
    tmp=$(mktemp -d)

    # Script d'installation officiel Rapid7
    if curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
            -o "$tmp/msfinstall" 2>/dev/null; then
        chmod +x "$tmp/msfinstall"
        bash "$tmp/msfinstall" && log "Metasploit installé" || warn "Metasploit : installation échouée"
    else
        warn "Metasploit : téléchargement du script échoué"
        warn "Installation manuelle : https://github.com/rapid7/metasploit-framework/wiki/Nightly-Installers"
        FAILED+=("metasploit")
    fi
    rm -rf "$tmp"
}
install_metasploit || true

# ── 6. Burp Suite Community ───────────────────────────────────
install_burpsuite() {
    if command -v burpsuite &>/dev/null || [[ -f /opt/BurpSuiteCommunity/burpsuite_community.jar ]]; then
        log "Burp Suite déjà installé"
        return 0
    fi

    log "Téléchargement de Burp Suite Community..."
    local burp_url="https://portswigger-cdn.net/burp/releases/download?product=community&type=Linux"
    local installer="/tmp/burpsuite_installer.sh"

    if curl -fsSL "$burp_url" -o "$installer" 2>/dev/null; then
        chmod +x "$installer"
        bash "$installer" -q 2>/dev/null && log "Burp Suite installé" || warn "Burp Suite : installation interactive requise"
        rm -f "$installer"
    else
        warn "Burp Suite : téléchargement échoué"
        warn "Téléchargement manuel : https://portswigger.net/burp/releases/community/latest"
        FAILED+=("burpsuite")
    fi
}
install_burpsuite || true

# ── 7. ZAProxy ────────────────────────────────────────────────
install_zaproxy() {
    if command -v zaproxy &>/dev/null || command -v zap.sh &>/dev/null; then
        log "ZAProxy déjà installé"
        return 0
    fi
    log "Installation de ZAProxy via snap (si disponible)..."
    if command -v snap &>/dev/null; then
        snap install zaproxy --classic 2>/dev/null && log "ZAProxy installé via snap" || \
            warn "ZAProxy : snap install échoué"
    else
        warn "ZAProxy non installé (snap requis ou installation manuelle)"
        warn "Téléchargement : https://www.zaproxy.org/download/"
        FAILED+=("zaproxy")
    fi
}
install_zaproxy || true

# ── 8. BloodHound + Neo4j ─────────────────────────────────────
install_bloodhound() {
    if command -v bloodhound &>/dev/null; then log "BloodHound déjà installé"; return 0; fi

    log "Installation de Neo4j (BloodHound)..."
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        # Dépôt Neo4j officiel
        curl -fsSL https://debian.neo4j.com/neotechnology.gpg.key \
            | gpg --dearmor -o /etc/apt/keyrings/neo4j.gpg 2>/dev/null || true
        echo "deb [signed-by=/etc/apt/keyrings/neo4j.gpg] https://debian.neo4j.com stable latest" \
            > /etc/apt/sources.list.d/neo4j.list 2>/dev/null || true
        apt-get update -qq 2>/dev/null || true
        DEBIAN_FRONTEND=noninteractive apt-get install -y neo4j 2>/dev/null || warn "Neo4j non installé"
    else
        "$PKG_MGR" install -y neo4j 2>/dev/null || warn "Neo4j non installé via $PKG_MGR"
    fi

    # BloodHound GUI
    local bh_url="https://github.com/BloodHoundAD/BloodHound/releases/latest/download/BloodHound-linux-x64.zip"
    local tmp; tmp=$(mktemp -d)
    if curl -fsSL "$bh_url" -o "$tmp/bh.zip" 2>/dev/null; then
        unzip -q "$tmp/bh.zip" -d /opt/ 2>/dev/null || true
        ln -sf /opt/BloodHound-linux-x64/BloodHound /usr/local/bin/bloodhound 2>/dev/null || true
        log "BloodHound installé → /opt/BloodHound-linux-x64/"
    else
        warn "BloodHound : téléchargement échoué"
        FAILED+=("bloodhound")
    fi
    rm -rf "$tmp"
}
install_bloodhound || true

# ── 9. Impacket (complément) ──────────────────────────────────
if ! command -v impacket-smbclient &>/dev/null; then
    pip_install "impacket" "impacket"
fi

# ── 10. Wordlists (rockyou, etc.) ────────────────────────────
install_wordlists() {
    local wl_dir="/usr/share/wordlists"
    mkdir -p "$wl_dir"

    if [[ ! -f "${wl_dir}/rockyou.txt" ]]; then
        log "Téléchargement de rockyou.txt..."
        if [[ "$DISTRO_FAMILY" == "debian" ]]; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y wordlists 2>/dev/null || true
        fi
        # Fallback : téléchargement direct
        if [[ ! -f "${wl_dir}/rockyou.txt" ]]; then
            curl -fsSL \
                "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" \
                -o "${wl_dir}/rockyou.txt" 2>/dev/null && log "rockyou.txt téléchargé" || \
                warn "rockyou.txt : téléchargement échoué"
        fi
    else
        log "rockyou.txt déjà présent"
    fi
}
install_wordlists || true

# ── Rapport ───────────────────────────────────────────────────
echo ""
log "✅ Module Offensif installé"
if (( ${#FAILED[@]} > 0 )); then
    warn "Outils non installés automatiquement (installation manuelle requise) :"
    for p in "${FAILED[@]}"; do echo "   - $p"; done
    echo ""
    info "Consultez docs/tools-offensif.md pour les liens de téléchargement."
fi
