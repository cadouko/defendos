#!/bin/bash
# DefendOS – Script post-démarrage Live
# Exécuté automatiquement au premier boot via systemd
# /airootfs/root/defendos-post.sh

set -euo pipefail

LOG="/var/log/defendos-boot.log"
exec > >(tee -a "$LOG") 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    clear
    echo -e "${CYAN}"
    cat <<'EOF'
  ██████╗ ███████╗███████╗███████╗███╗   ██╗██████╗  ██████╗ ███████╗
  ██╔══██╗██╔════╝██╔════╝██╔════╝████╗  ██║██╔══██╗██╔═══██╗██╔════╝
  ██║  ██║█████╗  █████╗  █████╗  ██╔██╗ ██║██║  ██║██║   ██║███████╗
  ██║  ██║██╔══╝  ██╔══╝  ██╔══╝  ██║╚██╗██║██║  ██║██║   ██║╚════██║
  ██████╔╝███████╗██║     ███████╗██║ ╚████║██████╔╝╚██████╔╝███████║
  ╚═════╝ ╚══════╝╚═╝     ╚══════╝╚═╝  ╚═══╝╚═════╝  ╚═════╝ ╚══════╝
EOF
    echo -e "${NC}"
    echo -e "${BOLD}     Cybersecurity Live OS – Arch Linux + BlackArch${NC}"
    echo -e "${YELLOW}     Usage éthique et légal uniquement.${NC}"
    echo ""
}

step() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; }

# ── 1. Appliquer les paramètres sysctl ───────────────────────
step "Application des paramètres kernel (sysctl)..."
sysctl --system -q 2>/dev/null || warn "sysctl --system partiel"

# ── 2. Démarrer les services essentiels ──────────────────────
step "Démarrage des services réseau..."
systemctl start NetworkManager --no-block 2>/dev/null || warn "NetworkManager non disponible"

step "Démarrage du pare-feu UFW..."
if command -v ufw &>/dev/null; then
    ufw --force reset   >/dev/null 2>&1
    ufw default deny incoming >/dev/null 2>&1
    ufw default allow outgoing >/dev/null 2>&1
    ufw allow ssh >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1
    step "UFW activé (deny incoming / allow outgoing)"
else
    warn "ufw non trouvé, pare-feu ignoré"
fi

# ── 3. AppArmor ───────────────────────────────────────────────
step "Activation AppArmor..."
if systemctl start apparmor 2>/dev/null; then
    aa-enforce /etc/apparmor.d/* 2>/dev/null || true
    step "AppArmor en mode enforce"
else
    warn "AppArmor non disponible sur ce kernel"
fi

# ── 4. Auditd ─────────────────────────────────────────────────
step "Démarrage d'auditd..."
systemctl start auditd 2>/dev/null && \
    augenrules --load 2>/dev/null || \
    warn "auditd non disponible"

# ── 5. ClamAV (base de signatures) ───────────────────────────
if command -v freshclam &>/dev/null; then
    step "Mise à jour des signatures ClamAV en arrière-plan..."
    freshclam --quiet &
fi

# ── 6. Configurer le shell root ───────────────────────────────
step "Configuration du shell (zsh + Oh-My-Zsh fallback)..."
if [[ ! -f /root/.zshrc ]]; then
    cat > /root/.zshrc <<'ZSHRC'
# DefendOS .zshrc
export HISTSIZE=10000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY

# Prompt
autoload -Uz vcs_info
precmd() { vcs_info }
PROMPT='%F{196}[DefendOS]%f %F{39}%~%f%F{226}${vcs_info_msg_0_}%f %# '

# Plugins intégrés
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null || true
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null || true

# Aliases
alias ll='ls -lahF --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias ip='ip -c'
alias nmap='nmap --privileged'
alias msfconsole='msfconsole -q'
alias update='pacman -Syu'
alias ports='ss -tulnp'
alias listen='ss -tulnp | grep LISTEN'
alias firewall='ufw status verbose'
alias audit-log='journalctl -u auditd -f'
alias defendos='defendos-gui &'
alias tools='tool-launcher'

# PATH
export PATH="$PATH:/usr/local/bin:/opt/defendos/bin"
ZSHRC
fi

chsh -s /usr/bin/zsh root 2>/dev/null || true

# ── 7. MOTD ───────────────────────────────────────────────────
cat > /etc/motd <<'MOTD'

  ⚔  DefendOS Live – Cybersecurity OS
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Commandes rapides :
    defendos-gui      → Launcher graphique
    defendos-welcome  → Écran d'accueil
    lynis audit system → Audit de sécurité
    nmap -sV <cible>   → Scan de services
    suricata -T -c /etc/suricata/suricata.yaml → Test IDS
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚠  Usage légal uniquement.

MOTD

# ── 8. Préparer le répertoire de travail ─────────────────────
mkdir -p /root/workspace/{reports,captures,wordlists,exploits,forensics}
step "Dossier de travail : /root/workspace/"

# ── 9. Lancer l'interface graphique si disponible ─────────────
step "Initialisation terminée. Démarrage de l'interface..."
if command -v startx &>/dev/null && [[ -z "${DISPLAY:-}" ]]; then
    echo -e "\n${GREEN}Démarrage de XFCE...${NC}"
    sleep 1
    exec startx /usr/bin/xfce4-session
fi

banner
echo -e "\n${GREEN}✔  DefendOS Live prêt !${NC}"
echo -e "   Tapez ${BOLD}defendos-gui${NC} pour ouvrir le launcher graphique."
echo -e "   Tapez ${BOLD}startx${NC} pour démarrer l'interface graphique.\n"
