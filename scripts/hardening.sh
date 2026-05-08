#!/usr/bin/env bash
# DefendOS – Script de hardening avancé v2.0.0
# Compatible : Debian/Ubuntu (AppArmor/UFW), RHEL/Fedora/Rocky (SELinux/firewalld)
# Usage   : sudo ./scripts/hardening.sh [--dry-run] [--no-ssh] [--no-firewall] [--no-mac]
# Idempotent : peut être relancé sans danger

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── Options ─────────────────────────────────────────────────
DRY_RUN=false
SKIP_SSH=false
SKIP_FIREWALL=false
SKIP_MAC=false    # MAC = AppArmor (Debian) ou SELinux (RHEL)

for arg in "$@"; do
    case $arg in
        --dry-run)      DRY_RUN=true ;;
        --no-ssh)       SKIP_SSH=true ;;
        --no-firewall)  SKIP_FIREWALL=true ;;
        --no-mac)       SKIP_MAC=true ;;
        --no-apparmor)  SKIP_MAC=true ;;    # alias rétrocompatible
        --help|-h)
            echo "Usage: $0 [--dry-run] [--no-ssh] [--no-firewall] [--no-mac]"
            exit 0 ;;
    esac
done

# ─── Détection distro ─────────────────────────────────────────
DISTRO_FAMILY="${DISTRO_FAMILY:-}"
PKG_MGR="${PKG_MGR:-}"

if [[ -z "$DISTRO_FAMILY" ]]; then
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        case "${ID:-}" in
            debian|ubuntu|linuxmint|kali|parrot)
                DISTRO_FAMILY="debian"; PKG_MGR="apt-get" ;;
            fedora|rhel|centos|rocky|almalinux|ol)
                DISTRO_FAMILY="rhel"
                PKG_MGR=$(command -v dnf &>/dev/null && echo "dnf" || echo "yum") ;;
            *)
                if command -v apt-get &>/dev/null; then DISTRO_FAMILY="debian"; PKG_MGR="apt-get"
                elif command -v dnf &>/dev/null;   then DISTRO_FAMILY="rhel";   PKG_MGR="dnf"
                else DISTRO_FAMILY="debian";             PKG_MGR="apt-get"; fi ;;
        esac
    fi
fi

# ─── Helpers ─────────────────────────────────────────────────
LOG="/var/log/defendos-hardening.log"
BACKUP_DIR="/etc/defendos-backup/$(date +%Y%m%d_%H%M%S)"

log()     { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOG"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG"; }
fail()    { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG"; }
info()    { echo -e "${CYAN}[i]${NC} $*" | tee -a "$LOG"; }
section() {
    echo "" | tee -a "$LOG"
    echo -e "${BOLD}${CYAN}━━━ $* ━━━${NC}" | tee -a "$LOG"
}

run() {
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY]${NC} $*"
    else
        eval "$@"
    fi
}

# ─── Vérifications préalables ────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    fail "Ce script doit être exécuté en root (sudo $0)"
    exit 1
fi

echo -e "\n${BOLD}${RED}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}║   DefendOS – Hardening Avancé v2.0   ║${NC}"
echo -e "${BOLD}${RED}╚══════════════════════════════════════╝${NC}\n"
info "Distribution : $DISTRO_FAMILY / $PKG_MGR"
$DRY_RUN && warn "Mode DRY-RUN activé – aucune modification ne sera appliquée.\n"

# ─── Sauvegarde des configs originales ───────────────────────
section "Sauvegarde des configurations"
if ! $DRY_RUN; then
    mkdir -p "$BACKUP_DIR"
    for f in /etc/ssh/sshd_config /etc/sysctl.conf /etc/security/limits.conf \
              /etc/security/pwquality.conf; do
        [[ -f "$f" ]] && cp -a "$f" "$BACKUP_DIR/" && log "Sauvegardé : $f"
    done
    log "Backup dans : $BACKUP_DIR"
fi

# ─── 1. Mises à jour système ─────────────────────────────────
section "Mises à jour système"
if [[ "$DISTRO_FAMILY" == "debian" ]]; then
    run "DEBIAN_FRONTEND=noninteractive $PKG_MGR update -qq"
    run "DEBIAN_FRONTEND=noninteractive $PKG_MGR install -y --no-install-recommends \
        auditd fail2ban apparmor apparmor-utils apparmor-profiles \
        ufw libpam-pwquality lynis rkhunter clamav 2>&1 | tail -5"
else
    run "$PKG_MGR makecache -q"
    run "$PKG_MGR install -y \
        audit fail2ban firewalld libpwquality lynis rkhunter clamav 2>&1 | tail -5"
fi
log "Paquets de sécurité installés/mis à jour"

# ─── 2. Paramètres kernel (sysctl) ───────────────────────────
section "Hardening kernel (sysctl)"
SYSCTL_CONF="/etc/sysctl.d/99-defendos.conf"

run "cat > $SYSCTL_CONF <<'EOF'
# DefendOS sysctl hardening v2.0
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
        local_sshd="sshd"
        # Ubuntu utilise parfois "ssh"
        command -v sshd &>/dev/null || local_sshd="ssh"
        if sshd -t 2>/dev/null; then
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
            log "SSH durci et redémarré"
        else
            fail "Configuration SSH invalide – rollback"
            rm -f "$SSH_DROP"
        fi
    fi
fi

# ─── 4. Pare-feu ─────────────────────────────────────────────
if ! $SKIP_FIREWALL; then
    section "Configuration pare-feu"

    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        # ── UFW (Debian/Ubuntu) ──────────────────────────────
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
            warn "ufw non disponible – installation..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y ufw 2>/dev/null && \
                bash "$0" --no-mac --no-ssh || warn "ufw non installable"
        fi
    else
        # ── firewalld (RHEL/Fedora) ──────────────────────────
        if command -v firewall-cmd &>/dev/null; then
            run "systemctl enable --now firewalld"
            run "firewall-cmd --set-default-zone=drop"
            run "firewall-cmd --permanent --add-service=ssh"
            run "firewall-cmd --permanent --add-rich-rule='rule service name=ssh limit value=3/m accept'"
            run "firewall-cmd --permanent --remove-service=telnet 2>/dev/null || true"
            run "firewall-cmd --reload"
            log "firewalld configuré et activé (zone drop, SSH rate-limited)"
        else
            warn "firewalld non disponible"
        fi
    fi
fi

# ─── 5. Contrôle d'accès obligatoire (MAC) ───────────────────
if ! $SKIP_MAC; then
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        # ── AppArmor (Debian/Ubuntu) ──────────────────────────
        section "AppArmor"
        if command -v aa-enforce &>/dev/null; then
            run "systemctl enable --now apparmor"
            run "aa-enforce /etc/apparmor.d/* 2>/dev/null || true"
            log "AppArmor activé en mode enforce"
        else
            warn "AppArmor non disponible (kernel sans support ?)"
        fi
    else
        # ── SELinux (RHEL/Fedora) ─────────────────────────────
        section "SELinux"
        if command -v setenforce &>/dev/null; then
            run "setenforce 1"
            run "sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config"
            log "SELinux : mode enforcing activé"
        else
            warn "SELinux non disponible"
        fi
    fi
fi

# ─── 6. Auditd ───────────────────────────────────────────────
section "Audit système (auditd)"
AUDIT_RULES="/etc/audit/rules.d/defendos.rules"
run "mkdir -p /etc/audit/rules.d"
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

AUDITD_SVC="auditd"
if ! systemctl is-active auditd &>/dev/null 2>&1; then AUDITD_SVC="auditd"; fi

if command -v auditd &>/dev/null; then
    if ! $DRY_RUN; then
        systemctl enable "$AUDITD_SVC" 2>/dev/null || true
        augenrules --load 2>/dev/null && systemctl restart "$AUDITD_SVC" && \
            log "Règles auditd chargées" || \
            warn "augenrules échoué – rechargement manuel : auditctl -R $AUDIT_RULES"
    fi
else
    warn "auditd non installé"
fi

# ─── 7. Fail2Ban ─────────────────────────────────────────────
section "Fail2Ban"
if command -v fail2ban-client &>/dev/null; then
    F2B_LOCAL="/etc/fail2ban/jail.local"
    if [[ ! -f "$F2B_LOCAL" ]]; then
        BACKEND="systemd"
        # Vérifier si systemd est disponible
        command -v systemctl &>/dev/null || BACKEND="auto"
        run "cat > $F2B_LOCAL <<EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = $BACKEND
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
