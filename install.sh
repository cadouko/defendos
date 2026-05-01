#!/usr/bin/env bash
# DefendOS – Installateur principal v1.0.0
# Usage : sudo ./install.sh [full|offensive|defensive|iso] [--yes] [--no-hardening]
#
# full       : Outils offensifs + défensifs (défaut)
# offensive  : Pentest / Red Team uniquement
# defensive  : Blue Team / SIEM uniquement
# iso        : Construire l'ISO live (nécessite archiso)

set -euo pipefail
IFS=$'\n\t'

# ─── Constantes ───────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="1.0.0"
readonly LOG="/var/log/defendos-install.log"
readonly BLACKARCH_URL="https://blackarch.org/strap.sh"
readonly BLACKARCH_SHA1="5ea40d49ecd14c2e024deecf90605426db3d32d5"

# ─── Couleurs ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── Arguments ───────────────────────────────────────────────
MODULE="${1:-}"
AUTO_YES=false
NO_HARDENING=false

shift 2>/dev/null || true
for arg in "$@"; do
    case $arg in
        --yes|-y)          AUTO_YES=true ;;
        --no-hardening)    NO_HARDENING=true ;;
        --help|-h)
            echo "Usage: $0 [full|offensive|defensive|iso] [--yes] [--no-hardening]"
            exit 0 ;;
    esac
done

# ─── Helpers ─────────────────────────────────────────────────
log()     { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOG"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG"; }
fail()    { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG"; exit 1; }
info()    { echo -e "${CYAN}[i]${NC} $*" | tee -a "$LOG"; }
confirm() {
    local msg="$1"
    if $AUTO_YES; then return 0; fi
    echo -en "${YELLOW}  ➜ ${NC}${msg} [Y/n] "
    read -r r
    [[ -z "$r" || "${r,,}" == "y" ]]
}

header() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║   DefendOS Installer v${VERSION}              ║"
    echo "  ║   Arch Linux + BlackArch                 ║"
    echo "  ║   Mix Offensif + Défensif                ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─── Pré-vérifications ────────────────────────────────────────
preflight_checks() {
    log "Vérifications préalables..."

    [[ $EUID -ne 0 ]] && fail "Doit être exécuté en root : sudo $0"

    [[ ! -f /etc/arch-release ]] && \
        warn "Non Arch Linux détecté. Certains modules peuvent échouer."

    # Connexion internet
    if ! curl -s --connect-timeout 5 https://archlinux.org >/dev/null 2>&1; then
        fail "Pas de connexion internet. Vérifiez votre réseau."
    fi

    # Espace disque (minimum 10 Go)
    local free_kb
    free_kb=$(df / | awk 'NR==2{print $4}')
    if (( free_kb < 10485760 )); then
        warn "Espace disque faible : $(( free_kb / 1024 / 1024 )) Go disponibles (recommandé : 10 Go)"
        confirm "Continuer quand même ?" || exit 0
    fi

    log "Vérifications OK"
}

# ─── BlackArch Repo ───────────────────────────────────────────
setup_blackarch() {
    if pacman -Q blackarch-keyring &>/dev/null; then
        log "Dépôt BlackArch déjà configuré"
        return 0
    fi

    log "Configuration du dépôt BlackArch..."
    local strap="/tmp/blackarch-strap.sh"

    curl -fsSL "$BLACKARCH_URL" -o "$strap"

    # Vérification du checksum SHA1
    local actual_sha1
    actual_sha1=$(sha1sum "$strap" | awk '{print $1}')
    if [[ "$actual_sha1" != "$BLACKARCH_SHA1" ]]; then
        rm -f "$strap"
        fail "Checksum BlackArch strap.sh invalide ! (attendu: $BLACKARCH_SHA1, obtenu: $actual_sha1)"
    fi
    log "Checksum BlackArch vérifié : OK"

    chmod +x "$strap"
    bash "$strap"
    rm -f "$strap"
    log "Dépôt BlackArch configuré"
}

# ─── Paquets de base ──────────────────────────────────────────
install_base() {
    log "Installation des paquets de base..."
    pacman -Syu --noconfirm --needed \
        base-devel git curl wget zsh zsh-completions \
        zsh-autosuggestions zsh-syntax-highlighting \
        tmux neovim vim htop btop tree jq \
        ufw fail2ban apparmor apparmor-profiles \
        audit libpwquality \
        wireshark-qt tcpdump tshark nmap \
        python python-pip python-gobject gtk3 \
        networkmanager 2>&1 | grep -E "^(installing|warning|error)" || true
    log "Paquets de base installés"
}

# ─── Modules ─────────────────────────────────────────────────
install_module() {
    local module="$1"
    local script="${SCRIPT_DIR}/modules/${module}.sh"

    [[ ! -f "$script" ]] && fail "Module introuvable : $script"
    chmod +x "$script"
    bash "$script"
}

# ─── ISO Build ────────────────────────────────────────────────
build_iso() {
    log "Construction de l'ISO DefendOS..."

    if ! command -v mkarchiso &>/dev/null; then
        log "Installation d'archiso..."
        pacman -S --noconfirm --needed archiso
    fi

    local profile_dir="${SCRIPT_DIR}/iso/defendos"
    local out_dir="${SCRIPT_DIR}/build/iso"
    local work_dir="${SCRIPT_DIR}/build/work"

    [[ ! -d "$profile_dir" ]] && fail "Profil ISO introuvable : $profile_dir"

    mkdir -p "$out_dir" "$work_dir"
    log "Profil     : $profile_dir"
    log "Output     : $out_dir"
    log "Work dir   : $work_dir"

    confirm "Lancer la construction ISO ? (peut prendre 30–90 min)" || exit 0

    mkarchiso \
        -v \
        -w "$work_dir" \
        -o "$out_dir" \
        "$profile_dir"

    local iso_file
    iso_file=$(find "$out_dir" -name "*.iso" | head -1)
    log "ISO créée : $iso_file"

    # Générer les checksums
    sha256sum "$iso_file" > "${iso_file}.sha256"
    sha512sum "$iso_file" > "${iso_file}.sha512"
    log "Checksums générés"

    echo ""
    echo -e "${BOLD}${GREEN}ISO prête !${NC}"
    echo -e "  Fichier  : ${CYAN}$iso_file${NC}"
    echo -e "  SHA256   : $(cat "${iso_file}.sha256" | awk '{print $1}')"
    echo ""
    echo "Pour tester : qemu-system-x86_64 -m 4G -cdrom $iso_file -boot d"
}

# ─── Post-install ─────────────────────────────────────────────
post_install() {
    log "Configuration post-installation..."

    # Copier les scripts dans /usr/local/bin
    if [[ -f "${SCRIPT_DIR}/iso/defendos/airootfs/usr/local/bin/defendos-gui" ]]; then
        install -m755 \
            "${SCRIPT_DIR}/iso/defendos/airootfs/usr/local/bin/defendos-gui" \
            /usr/local/bin/defendos-gui
        install -m755 \
            "${SCRIPT_DIR}/iso/defendos/airootfs/usr/local/bin/defendos-welcome" \
            /usr/local/bin/defendos-welcome
        install -m755 \
            "${SCRIPT_DIR}/iso/defendos/airootfs/usr/local/bin/tool-launcher" \
            /usr/local/bin/tool-launcher
        log "Launchers installés dans /usr/local/bin"
    fi

    # Créer le dossier de travail
    mkdir -p /root/workspace/{reports,captures,wordlists,exploits,forensics}
    log "Workspace créé : /root/workspace/"

    # Zsh par défaut pour root
    chsh -s /usr/bin/zsh root 2>/dev/null || true

    # Appliquer le hardening
    if ! $NO_HARDENING; then
        echo ""
        if confirm "Appliquer le hardening système avancé ?"; then
            bash "${SCRIPT_DIR}/scripts/hardening.sh"
        fi
    fi
}

# ─── Menu interactif ─────────────────────────────────────────
interactive_menu() {
    echo -e "${BOLD}Sélectionne le module à installer :${NC}"
    echo ""
    echo "  1) Full         – Offensif + Défensif  ${GREEN}(recommandé)${NC}"
    echo "  2) Offensif     – Pentest / Red Team"
    echo "  3) Défensif     – Blue Team / SIEM"
    echo "  4) ISO Build    – Construire l'ISO live"
    echo "  5) Quitter"
    echo ""
    read -rp "  Choix [1-5] : " choice
    case "$choice" in
        1) MODULE="full" ;;
        2) MODULE="offensive" ;;
        3) MODULE="defensive" ;;
        4) MODULE="iso" ;;
        5) exit 0 ;;
        *) warn "Choix invalide. Installation Full par défaut."; MODULE="full" ;;
    esac
}

# ─── Main ─────────────────────────────────────────────────────
main() {
    mkdir -p "$(dirname "$LOG")"
    touch "$LOG"

    header
    preflight_checks

    # Choix du module
    if [[ -z "$MODULE" ]]; then
        interactive_menu
    fi

    case "$MODULE" in
        full|offensive|defensive)
            setup_blackarch
            install_base
            install_module "$MODULE"
            post_install
            ;;
        iso)
            build_iso
            ;;
        *)
            fail "Module inconnu : '$MODULE'. Valeurs valides : full, offensive, defensive, iso"
            ;;
    esac

    echo ""
    echo -e "${BOLD}${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${GREEN}  DefendOS installé avec succès ! ✔    ${NC}"
    echo -e "${BOLD}${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    info "Log complet : $LOG"
    info "Lance 'defendos-gui' pour ouvrir le launcher graphique."
    info "Lance 'tool-launcher' pour le sélecteur CLI."
    echo ""
}

main "$@"
