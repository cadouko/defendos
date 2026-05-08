#!/usr/bin/env bash
# DefendOS – Installateur principal v2.0.0
# Compatible : Debian 12+, Ubuntu 22.04+, Fedora 39+, Rocky Linux 9+, AlmaLinux 9+
# Usage : sudo ./install.sh [full|offensive|defensive|iso] [--yes] [--no-hardening]
#
# full       : Outils offensifs + défensifs (défaut)
# offensive  : Pentest / Red Team uniquement
# defensive  : Blue Team / SIEM uniquement
# iso        : Construire l'ISO live (Debian live-build)

set -euo pipefail
IFS=$'\n\t'

# ─── Constantes ───────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly LOG="/var/log/defendos-install.log"

# ─── Couleurs ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── Globals (remplis par detect_distro) ─────────────────────
DISTRO_FAMILY=""   # debian | rhel
PKG_MGR=""         # apt-get | dnf | yum
DISTRO_ID=""       # debian, ubuntu, fedora, rocky, rhel…
DISTRO_VERSION=""

# ─── Arguments ───────────────────────────────────────────────
MODULE="${1:-}"
AUTO_YES=false
NO_HARDENING=false

if [[ "$MODULE" == "--help" || "$MODULE" == "-h" ]]; then
    echo "Usage: $0 [full|offensive|defensive|iso] [--yes] [--no-hardening]"
    exit 0
fi

shift 2>/dev/null || true
for arg in "$@"; do
    case $arg in
        --yes|-y)          AUTO_YES=true ;;
        --no-hardening)    NO_HARDENING=true ;;
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
    echo "  ║   DefendOS Installer v${VERSION}           ║"
    echo "  ║   Debian / Ubuntu / RHEL / Fedora        ║"
    echo "  ║   Mix Offensif + Défensif                ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─── Détection de la distribution ────────────────────────────
detect_distro() {
    if [[ ! -f /etc/os-release ]]; then
        fail "/etc/os-release introuvable. Distribution non supportée."
    fi

    # shellcheck source=/dev/null
    source /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-0}"

    case "$DISTRO_ID" in
        debian|ubuntu|linuxmint|kali|parrot|pop)
            DISTRO_FAMILY="debian"
            PKG_MGR="apt-get"
            ;;
        fedora)
            DISTRO_FAMILY="rhel"
            PKG_MGR="dnf"
            ;;
        rhel|centos|rocky|almalinux|ol)
            DISTRO_FAMILY="rhel"
            # CentOS 7 / RHEL 7 utilisent yum
            if command -v dnf &>/dev/null; then
                PKG_MGR="dnf"
            else
                PKG_MGR="yum"
            fi
            ;;
        *)
            # Détection par commande disponible
            if command -v apt-get &>/dev/null; then
                DISTRO_FAMILY="debian"; PKG_MGR="apt-get"
                warn "Distribution '$DISTRO_ID' inconnue, mode Debian activé par défaut."
            elif command -v dnf &>/dev/null; then
                DISTRO_FAMILY="rhel"; PKG_MGR="dnf"
                warn "Distribution '$DISTRO_ID' inconnue, mode RHEL/DNF activé par défaut."
            elif command -v yum &>/dev/null; then
                DISTRO_FAMILY="rhel"; PKG_MGR="yum"
                warn "Distribution '$DISTRO_ID' inconnue, mode RHEL/YUM activé par défaut."
            else
                fail "Distribution non supportée. Utilisez Debian/Ubuntu ou RHEL/Fedora/Rocky."
            fi
            ;;
    esac

    log "Distribution détectée : ${DISTRO_ID} ${DISTRO_VERSION} (famille: ${DISTRO_FAMILY}, gestionnaire: ${PKG_MGR})"
}

# ─── Pré-vérifications ────────────────────────────────────────
preflight_checks() {
    log "Vérifications préalables..."

    [[ $EUID -ne 0 ]] && fail "Doit être exécuté en root : sudo $0"

    detect_distro

    # Connexion internet
    if ! curl -s --connect-timeout 5 https://deb.debian.org >/dev/null 2>&1 && \
       ! curl -s --connect-timeout 5 https://dl.fedoraproject.org >/dev/null 2>&1; then
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

# ─── Mise à jour du système ────────────────────────────────────
update_system() {
    log "Mise à jour des listes de paquets..."
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
    else
        "$PKG_MGR" makecache -q 2>/dev/null || true
    fi
}

# ─── Dépôts supplémentaires ───────────────────────────────────
setup_extra_repos() {
    log "Configuration des dépôts supplémentaires..."

    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        # Universe / contrib / non-free (Ubuntu)
        if [[ "$DISTRO_ID" == "ubuntu" ]]; then
            add-apt-repository -y universe >/dev/null 2>&1 || true
            add-apt-repository -y multiverse >/dev/null 2>&1 || true
        fi

        # contrib + non-free pour Debian
        if [[ "$DISTRO_ID" == "debian" ]]; then
            local src_file="/etc/apt/sources.list"
            if ! grep -q "non-free" "$src_file" 2>/dev/null; then
                sed -i 's/main$/main contrib non-free non-free-firmware/' "$src_file" 2>/dev/null || true
            fi
        fi

        # Dépôt Docker CE
        if ! command -v docker &>/dev/null; then
            log "Ajout du dépôt Docker CE..."
            install -m0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/"${DISTRO_ID}"/gpg \
                | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
            local arch
            arch=$(dpkg --print-architecture)
            local codename
            codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
            echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${DISTRO_ID} ${codename} stable" \
                > /etc/apt/sources.list.d/docker.list 2>/dev/null || true
        fi

        DEBIAN_FRONTEND=noninteractive apt-get update -qq

    else
        # RHEL/Fedora : EPEL
        if [[ "$DISTRO_ID" != "fedora" ]]; then
            "$PKG_MGR" install -y epel-release 2>/dev/null || \
                "$PKG_MGR" install -y \
                    "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm" \
                    2>/dev/null || warn "EPEL non installable – certains paquets peuvent manquer"
        fi

        # RPM Fusion (outils multimédia / firmware)
        if ! rpm -q rpmfusion-free-release &>/dev/null; then
            "$PKG_MGR" install -y \
                "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
                2>/dev/null || true
        fi
    fi

    log "Dépôts configurés"
}

# ─── Paquets de base ──────────────────────────────────────────
install_base() {
    log "Installation des paquets de base..."

    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            build-essential git curl wget \
            zsh zsh-autosuggestions zsh-syntax-highlighting \
            tmux neovim vim nano htop btop tree jq \
            ufw fail2ban apparmor apparmor-utils apparmor-profiles \
            auditd libpam-pwquality \
            wireshark tshark tcpdump nmap \
            python3 python3-pip python3-gi python3-gi-cairo \
            gir1.2-gtk-3.0 libgtk-3-0 \
            ca-certificates gnupg lsb-release \
            fzf ripgrep bat fd-find lsof \
            2>&1 | grep -E "^(Setting up|E:|W:)" || true
    else
        "$PKG_MGR" install -y \
            git curl wget \
            zsh tmux neovim vim nano htop btop tree jq \
            ufw fail2ban \
            audit libpwquality \
            wireshark-cli tcpdump nmap \
            python3 python3-pip \
            python3-gobject gtk3 \
            ca-certificates gnupg \
            fzf ripgrep bat \
            epel-release 2>/dev/null || true \
            2>&1 | grep -E "^(Installing|Error|Warning)" || true
    fi

    log "Paquets de base installés"
}

# ─── Modules ─────────────────────────────────────────────────
install_module() {
    local module="$1"
    local script="${SCRIPT_DIR}/modules/${module}.sh"

    [[ ! -f "$script" ]] && fail "Module introuvable : $script"
    chmod +x "$script"
    # Exporter les variables de distro pour les sous-scripts
    export DISTRO_FAMILY PKG_MGR DISTRO_ID DISTRO_VERSION AUTO_YES
    bash "$script"
}

# ─── ISO Build ────────────────────────────────────────────────
build_iso() {
    log "Construction de l'ISO DefendOS (Debian live-build)..."

    if [[ "$DISTRO_FAMILY" != "debian" ]]; then
        warn "La construction ISO est basée sur live-build (Debian/Ubuntu)."
        warn "Pour RHEL/Fedora, utilisez le kickstart : iso/fedora/defendos.ks"
        info "Consultez : https://github.com/livecd-tools/livecd-tools"
        exit 0
    fi

    if ! command -v lb &>/dev/null; then
        log "Installation de live-build..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y live-build
    fi

    local profile_dir="${SCRIPT_DIR}/iso/debian"
    local out_dir="${SCRIPT_DIR}/build/iso"
    local work_dir="${SCRIPT_DIR}/build/work"

    [[ ! -d "$profile_dir" ]] && fail "Profil ISO introuvable : $profile_dir"

    mkdir -p "$out_dir" "$work_dir"
    log "Profil live-build : $profile_dir"
    log "Output            : $out_dir"
    log "Work dir          : $work_dir"

    confirm "Lancer la construction ISO ? (peut prendre 30–90 min)" || exit 0

    cd "$profile_dir"
    # Nettoyer un éventuel build précédent
    lb clean --purge 2>/dev/null || true

    # Configurer puis construire
    bash auto/config
    lb build 2>&1 | tee "${out_dir}/build.log"

    # Récupérer l'ISO générée
    local iso_file
    iso_file=$(find . -name "*.iso" -maxdepth 1 | head -1)
    if [[ -z "$iso_file" ]]; then
        fail "Aucune ISO générée. Consultez ${out_dir}/build.log"
    fi

    cp "$iso_file" "$out_dir/"
    iso_file="${out_dir}/$(basename "$iso_file")"

    sha256sum "$iso_file" > "${iso_file}.sha256"
    sha512sum "$iso_file" > "${iso_file}.sha512"
    log "Checksums générés"

    cd "$SCRIPT_DIR"

    echo ""
    echo -e "${BOLD}${GREEN}ISO prête !${NC}"
    echo -e "  Fichier  : ${CYAN}$iso_file${NC}"
    echo -e "  SHA256   : $(awk '{print $1}' "${iso_file}.sha256")"
    echo ""
    echo "Pour tester : qemu-system-x86_64 -enable-kvm -m 4G -cdrom $iso_file -boot d"
}

# ─── Post-install ─────────────────────────────────────────────
post_install() {
    log "Configuration post-installation..."

    # Copier les launchers
    local bin_src="${SCRIPT_DIR}/iso/debian/config/includes.chroot/usr/local/bin"
    if [[ -d "$bin_src" ]]; then
        for launcher in defendos-gui defendos-welcome tool-launcher; do
            if [[ -f "${bin_src}/${launcher}" ]]; then
                install -m755 "${bin_src}/${launcher}" "/usr/local/bin/${launcher}"
                log "Launcher installé : /usr/local/bin/${launcher}"
            fi
        done
    fi

    # Répertoire de travail
    mkdir -p /root/workspace/{reports,captures,wordlists,exploits,forensics}
    log "Workspace créé : /root/workspace/"

    # Zsh par défaut pour root
    if command -v zsh &>/dev/null; then
        chsh -s "$(command -v zsh)" root 2>/dev/null || true
    fi

    # Hardening
    if ! $NO_HARDENING; then
        echo ""
        if confirm "Appliquer le hardening système avancé ?"; then
            export DISTRO_FAMILY PKG_MGR
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
    echo "  4) ISO Build    – Construire l'ISO live (Debian)"
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

    if [[ -z "$MODULE" ]]; then
        interactive_menu
    fi

    case "$MODULE" in
        full|offensive|defensive)
            setup_extra_repos
            update_system
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
