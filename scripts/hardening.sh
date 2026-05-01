#!/usr/bin/env bash
# DefendOS – Script de hardening avancé
# Version : 1.0.0
# Usage   : sudo ./scripts/hardening.sh [--dry-run] [--no-ssh] [--no-firewall]
# Idempotent : peut être relancé sans danger

set -euo pipefail
IFS=$'\n\t'

# ─── Couleurs ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── Options ─────────────────────────────────────────────────
DRY_RUN=false
SKIP_SSH=false
SKIP_FIREWALL=false
SKIP_APPARMOR=false

for arg in "$@"; do
    case $arg in
        --dry-run)      DRY_RUN=true ;;
        --no-ssh)       SKIP_SSH=true ;;
        --no-firewall)  SKIP_FIREWALL=true ;;
        --no-apparmor)  SKIP_APPARMOR=true ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--no-ssh] [--no-firewall] [--no-apparmor]"
            exit 0 ;;
    esac
done

# ─── Helpers ─────────────────────────────────────────────────
LOG="/var/log/defendos-hardening.log"
BACKUP_DIR="/etc/defendos-backup/$(date +%Y%m%d_%H%M%S)"

log()  { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOG"; }
warn() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG"; }
fail() { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG"; }
info() { echo -e "${CYAN}[i]${NC} $*" | tee -a "$LOG"; }
section() {
    echo "" | tee -a "$LOG"
    echo -e "${BOLD}${CYAN}━━━ $* ━━━${NC}" | tee -a "$LOG"
}

run() {
    # Execute une commande ou simule si --dry-run
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY]${NC} $*"
    else
        eval "$*"
    fi
}

# ─── Vérifications préalables ────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    fail "Ce script doit être exécuté en root (sudo $0)"
    exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
    warn "Ce script est conçu pour Arch Linux. Continuer quand même ? [y/N]"
    read -r answer
    [[ "${answer,,}" == "y" ]] || exit 1
fi

echo -e "\n${BOLD}${RED}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}║   DefendOS – Hardening Avancé v1.0   ║${NC}"
echo -e "${BOLD}${RED}╚══════════════════════════════════════╝${NC}\n"
$DRY_RUN && warn "Mode DRY-RUN activé – aucune modification ne sera appliquée.\n"

# ─── Sauvegarde des configs originales ───────────────────────
section "Sauvegarde des configurations"
if ! $DRY_RUN; then
    mkdir -p "$BACKUP_DIR"
    for f in /etc/ssh/sshd_config /etc/sysctl.conf /etc/security/limits.conf; do
        [[ -f "$f" ]] && cp -a "$f" "$BACKUP_DIR/" && log "Sauvegardé : $f"
    done
    log "Backup dans : $BACKUP_DIR"
fi

# ─── 1. Mises à jour système ─────────────────────────────────
section "Mises à jour système"
if command -v pacman &>/dev/null; then
    run "pacman -Syu --noconfirm --needed audit fail2ban apparmor apparmor-profiles \
         ufw libpwquality lynis rkhunter clamav 2>&1 | tail -5"
    log "Paquets de sécurité installés/mis à jour"
fi

# ─── 2. Paramètres kernel (sysctl) ───────────────────────────
section "Hardening kernel (sysctl)"
SYSCTL_CONF="/etc/sysctl.d/99-defendos.conf"

if [[ ! -f "$SYSCTL_CONF" ]] || ! $DRY_RUN; then
    run "cat > $SYSCTL_CONF <<'EOF'
# DefendOS sysctl hardening
net.ipv4.tcp_syncookies                 = 1
net.ipv4.conf.all.rp_filter            = 1
net.ipv4.conf.default.rp_filter        = 1
net.ipv4.icmp_echo_ignore_broadcasts   = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_redirects     = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects       = 0
net.ipv4.conf.default.send_redirects   = 0
net.ipv4.conf.all.accept_source_route  = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians         = 1
net.ipv4.conf.default.log_martians     = 1
net.ipv4.tcp_timestamps                = 0
net.ipv4.tcp_rfc1337                   = 1
net.ipv6.conf.all.accept_redirects     = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route  = 0
net.ipv6.conf.all.accept_ra            = 0
kernel.randomize_va_space              = 2
kernel.kptr_restrict                   = 2
kernel.dmesg_restrict                  = 1
kernel.perf_event_paranoid             = 3
kernel.unprivileged_bpf_disabled       = 1
kernel.yama.ptrace_scope               = 2
kernel.sysrq                           = 0
kernel.core_uses_pid                   = 1
fs.protected_hardlinks                 = 1
fs.protected_symlinks                  = 1
fs.protected_fifos                     = 2
fs.protected_regular                   = 2
fs.suid_dumpable                       = 0
EOF"
    run "sysctl --system -q"
    log "Paramètres kernel appliqués"
fi

# ─── 3. SSH Hardening ────────────────────────────────────────
if ! $SKIP_SSH; then
    section "SSH Hardening"
    SSH_DROP="/etc/ssh/sshd_config.d/99-defendos.conf"
    run "mkdir -p /etc/ssh/sshd_config.d"
    run "cat > $SSH_DROP <<'EOF'
Protocol 2
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 0
AllowTcpForwarding no
X11Forwarding no
PermitTunnel no
AllowAgentForwarding no
PrintMotd no
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF"

    if ! $DRY_RUN; then
        if sshd -t 2>/dev/null; then
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
            log "SSH durci et redémarré"
        else
            fail "Configuration SSH invalide – reverted"
            rm -f "$SSH_DROP"
        fi
    fi
fi

# ─── 4. Pare-feu UFW ─────────────────────────────────────────
if ! $SKIP_FIREWALL; then
    section "Configuration pare-feu (UFW)"
    if command -v ufw &>/dev/null; then
        run "ufw --force reset"
        run "ufw default deny incoming"
        run "ufw default allow outgoing"
        run "ufw limit ssh comment 'SSH rate limited'"
        run "ufw deny proto tcp from any to any port 23 comment 'Block Telnet'"
        run "ufw deny proto tcp from any to any port 2323 comment 'Block alt-Telnet'"
        run "ufw --force enable"
        run "systemctl enable --now ufw"
        log "UFW configuré et activé"
    else
        warn "ufw non installé – pare-feu ignoré"
    fi
fi

# ─── 5. AppArmor ─────────────────────────────────────────────
if ! $SKIP_APPARMOR; then
    section "AppArmor"
    if command -v aa-enforce &>/dev/null; then
        run "systemctl enable --now apparmor"
        run "aa-enforce /etc/apparmor.d/* 2>/dev/null || true"
        log "AppArmor activé en mode enforce"
    else
        warn "AppArmor non disponible"
    fi
fi

# ─── 6. Auditd ───────────────────────────────────────────────
section "Audit système (auditd)"
if command -v auditd &>/dev/null; then
    run "systemctl enable --now auditd"
    AUDIT_RULES="/etc/audit/rules.d/defendos.rules"
    run "cat > $AUDIT_RULES <<'EOF'
-D
-b 8192
-f 1
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group  -p wa -k identity
-w /etc/sudoers -p wa -k priv_esc
-w /etc/sudoers.d -p wa -k priv_esc
-w /etc/ssh/sshd_config -p wa -k ssh_cfg
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root_cmd
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sudo -k privileged
-a always,exit -F arch=b64 -S socket  -F a0=2 -k network_socket
-a always,exit -F arch=b64 -S connect -k network_connect
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-w /var/log/ -p wa -k log_tamper
EOF"
    if ! $DRY_RUN; then
        augenrules --load 2>/dev/null && systemctl restart auditd && log "Règles auditd chargées"
    fi
else
    warn "auditd non installé"
fi

# ─── 7. Fail2Ban ─────────────────────────────────────────────
section "Fail2Ban"
if command -v fail2ban-client &>/dev/null; then
    F2B_LOCAL="/etc/fail2ban/jail.local"
    if [[ ! -f "$F2B_LOCAL" ]]; then
        run "cat > $F2B_LOCAL <<'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled  = true
port     = ssh
maxretry = 3
bantime  = 86400
EOF"
    fi
    run "systemctl enable --now fail2ban"
    log "Fail2Ban configuré et activé"
else
    warn "fail2ban non installé"
fi

# ─── 8. Limites système ──────────────────────────────────────
section "Limites système (limits.conf)"
LIMITS_CONF="/etc/security/limits.d/99-defendos.conf"
run "cat > $LIMITS_CONF <<'EOF'
# DefendOS – Limites de sécurité
*    hard  core         0
*    hard  nproc        10000
*    soft  nproc        5000
root hard  nproc        unlimited
*    hard  nofile       65536
*    soft  nofile       32768
EOF"
log "Limites système configurées"

# ─── 9. Politique de mots de passe ───────────────────────────
section "Politique de mots de passe (PAM / pwquality)"
PWQUAL="/etc/security/pwquality.conf"
if [[ -f "$PWQUAL" ]]; then
    run "sed -i 's/^# minlen.*/minlen = 14/' $PWQUAL"
    run "sed -i 's/^# dcredit.*/dcredit = -1/' $PWQUAL"
    run "sed -i 's/^# ucredit.*/ucredit = -1/' $PWQUAL"
    run "sed -i 's/^# ocredit.*/ocredit = -1/' $PWQUAL"
    run "sed -i 's/^# lcredit.*/lcredit = -1/' $PWQUAL"
    log "Politique de mots de passe durcie (min 14 chars, complexité)"
fi

# ─── 10. Droits sur fichiers sensibles ───────────────────────
section "Permissions fichiers sensibles"
declare -A PERMS=(
    ["/etc/shadow"]="640"
    ["/etc/gshadow"]="640"
    ["/etc/passwd"]="644"
    ["/etc/group"]="644"
    ["/boot"]="700"
    ["/etc/cron.d"]="700"
    ["/etc/cron.daily"]="700"
    ["/var/log"]="750"
)
for path in "${!PERMS[@]}"; do
    if [[ -e "$path" ]]; then
        run "chmod ${PERMS[$path]} $path"
        log "chmod ${PERMS[$path]} $path"
    fi
done

# ─── 11. Désactivation services inutiles ─────────────────────
section "Désactivation des services inutiles"
DISABLE_SERVICES=(avahi-daemon bluetooth cups ModemManager)
for svc in "${DISABLE_SERVICES[@]}"; do
    if systemctl is-active "$svc" &>/dev/null; then
        run "systemctl disable --now $svc"
        log "Service désactivé : $svc"
    fi
done

# ─── Rapport final ────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║    Hardening DefendOS terminé !      ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
info "Log complet : $LOG"
info "Backup configs : $BACKUP_DIR"
echo ""
log "Prochaine étape recommandée : lynis audit system"
echo ""
