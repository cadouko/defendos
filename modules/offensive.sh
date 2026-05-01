#!/usr/bin/env bash
# DefendOS – Module Offensif (Pentest / Red Team)
# Appelé par install.sh

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

log "Installation des outils offensifs (Pentest / Red Team)..."

# ── Groupes BlackArch ─────────────────────────────────────────
BLACKARCH_GROUPS=(
    blackarch-recon
    blackarch-scanner
    blackarch-exploitation
    blackarch-webapp
    blackarch-fuzzer
    blackarch-proxy
    blackarch-wireless
    blackarch-cracker
    blackarch-sniffer
    blackarch-networking
)

log "Installation des groupes BlackArch..."
for group in "${BLACKARCH_GROUPS[@]}"; do
    if pacman -Sg "$group" &>/dev/null; then
        pacman -S --noconfirm --needed "$group" 2>&1 | grep -c "installing" | \
            xargs -I{} echo "  → $group : {} paquets installés" || true
    else
        warn "Groupe non trouvé : $group (dépôt BlackArch configuré ?)"
    fi
done

# ── Outils individuels garantis ───────────────────────────────
log "Installation des outils individuels..."
TOOLS=(
    # Reconnaissance
    nmap masscan rustscan
    whatweb theharvester recon-ng
    amass subfinder dnsx httpx naabu
    # Web
    gobuster feroxbuster ffuf dirsearch nikto wapiti
    nuclei katana
    sqlmap commix
    burpsuite zaproxy
    # Exploitation
    metasploit
    # Passwords
    hashcat john thc-hydra medusa
    crunch cewl
    # Réseau / MitM
    bettercap mitmproxy
    netcat socat proxychains-ng
    # Wireless
    aircrack-ng hcxtools hcxdumptool
    # Post-exploitation
    impacket crackmapexec evil-winrm
    # Python tooling
    python-impacket python-requests python-scapy
)

FAILED=()
for pkg in "${TOOLS[@]}"; do
    if ! pacman -S --noconfirm --needed "$pkg" 2>/dev/null; then
        warn "Paquet non trouvé dans les dépôts : $pkg"
        FAILED+=("$pkg")
    fi
done

# ── AUR : outils non dans les dépôts officiels ───────────────
setup_yay() {
    if command -v yay &>/dev/null; then return 0; fi
    log "Installation de yay (AUR helper)..."
    local tmp
    tmp=$(mktemp -d)
    git clone --depth=1 https://aur.archlinux.org/yay.git "$tmp/yay"
    pushd "$tmp/yay" > /dev/null
    # yay doit être buildé par un non-root
    if [[ $EUID -eq 0 ]]; then
        chown -R nobody:nobody "$tmp/yay"
        sudo -u nobody makepkg -si --noconfirm
    else
        makepkg -si --noconfirm
    fi
    popd > /dev/null
    rm -rf "$tmp"
}

AUR_TOOLS=(bloodhound neo4j covenant)
if (( ${#AUR_TOOLS[@]} > 0 )); then
    setup_yay || warn "yay non installable – outils AUR ignorés"
    if command -v yay &>/dev/null; then
        for pkg in "${AUR_TOOLS[@]}"; do
            yay -S --noconfirm "$pkg" 2>/dev/null || warn "AUR : $pkg non installé"
        done
    fi
fi

# ── Rapport ───────────────────────────────────────────────────
echo ""
log "✅ Module Offensif installé"
if (( ${#FAILED[@]} > 0 )); then
    warn "Paquets non installés (dépôt manquant ?) :"
    for p in "${FAILED[@]}"; do echo "   - $p"; done
fi
