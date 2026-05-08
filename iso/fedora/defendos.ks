# ============================================================
# DefendOS – Kickstart pour Fedora / Rocky Linux / AlmaLinux
# Usage : livecd-creator --config=defendos.ks --fslabel=DefendOS
#         ou : mkksiso defendos.ks fedora.iso defendos-live.iso
# ============================================================

#version=DEVEL

# ── Langue & clavier ──────────────────────────────────────────
lang fr_FR.UTF-8
keyboard --vckeymap=fr --xlayouts='fr'
timezone Africa/Abidjan --utc

# ── Réseau ───────────────────────────────────────────────────
network --bootproto=dhcp --device=link --activate
network --hostname=defendos

# ── Mot de passe root ─────────────────────────────────────────
# CHANGER AVANT TOUTE UTILISATION EN PRODUCTION
rootpw --plaintext defendos

# ── Source d'installation (Live) ─────────────────────────────
url --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-39&arch=x86_64

# ── Bootloader ───────────────────────────────────────────────
bootloader --location=mbr --driveorder=sda --append="rhgb quiet"

# ── Partitionnement (live – pas de disk writing) ─────────────
# Pour un live CD, pas de partitionnement réel nécessaire
# zerombr
# clearpart --all --initlabel
# autopart

# ── Services ─────────────────────────────────────────────────
services --enabled=NetworkManager,auditd,fail2ban,firewalld
services --disabled=avahi-daemon,bluetooth,cups

# ── Paquets ───────────────────────────────────────────────────
%packages
@core
@standard
@hardware-support
@base-x
@xfce-desktop
@xfce-apps

# Shell & utilitaires
zsh
tmux
neovim
vim-enhanced
nano
git
htop
btop
tree
jq
unzip
p7zip
ripgrep
fzf
lsof
strace
ltrace

# Réseau
NetworkManager
NetworkManager-wifi
openssh-clients
openssh-server
iw
wireless-tools
wpa_supplicant

# Sécurité
ufw
fail2ban
audit
libpwquality
lynis
rkhunter
clamav
clamav-update
chkrootkit

# Pare-feu
firewalld

# SELinux
policycoreutils
policycoreutils-python-utils
selinux-policy
selinux-policy-targeted

# Monitoring
syslog-ng
logrotate
iotop
nethogs
iftop

# IDS
suricata
snort

# Pentest – dépôts Fedora
nmap
masscan
nikto
sqlmap
hashcat
john
hydra
medusa
crunch
ncat
socat
proxychains-ng
tcpdump
wireshark-cli
tshark
ngrep
aircrack-ng

# Forensics
sleuthkit
foremost
binwalk
radare2
gdb

# Cryptographie
openssl
gnupg2

# Python
python3
python3-pip
python3-requests
python3-scapy
python3-cryptography
python3-gobject

# Ruby
ruby

# Virtualisation
docker
docker-compose
qemu-kvm
libvirt
virt-manager

# Firefox
firefox

# KeePassXC
keepassxc

# Wireshark GUI
wireshark

%end

# ── Post-installation ─────────────────────────────────────────
%post --erroronfail
set -euo pipefail
LOG="/var/log/defendos-ks-post.log"
exec > >(tee -a "$LOG") 2>&1

echo "[+] DefendOS Kickstart – post-install"

# ── Outils Go (binaires) ──────────────────────────────────────
ARCH_SUFFIX="linux_amd64"
install_go_binary() {
    local name="$1" binary="$2" url="$3"
    echo "  → $name"
    local tmp; tmp=$(mktemp -d)
    curl -fsSL "${url/\{\{ARCH_SUFFIX\}\}/$ARCH_SUFFIX}" -o "$tmp/t.pkg" 2>/dev/null || \
        { echo "  [WARN] $name : dl échoué"; rm -rf "$tmp"; return 0; }
    tar -xzf "$tmp/t.pkg" -C "$tmp/" 2>/dev/null || \
        unzip -q "$tmp/t.pkg" -d "$tmp/" 2>/dev/null || true
    local b; b=$(find "$tmp" -name "$binary" -type f 2>/dev/null | head -1)
    [[ -n "$b" ]] && install -m755 "$b" "/usr/local/bin/$binary"
    rm -rf "$tmp"
}

install_go_binary "nuclei"    "nuclei"    "https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_{{ARCH_SUFFIX}}.zip"
install_go_binary "subfinder" "subfinder" "https://github.com/projectdiscovery/subfinder/releases/latest/download/subfinder_{{ARCH_SUFFIX}}.zip"
install_go_binary "httpx"     "httpx"     "https://github.com/projectdiscovery/httpx/releases/latest/download/httpx_{{ARCH_SUFFIX}}.zip"
install_go_binary "ffuf"      "ffuf"      "https://github.com/ffuf/ffuf/releases/latest/download/ffuf_{{ARCH_SUFFIX}}.tar.gz"
install_go_binary "gobuster"  "gobuster"  "https://github.com/OJ/gobuster/releases/latest/download/gobuster_Linux_{{ARCH_SUFFIX}}.tar.gz"
install_go_binary "amass"     "amass"     "https://github.com/owasp-amass/amass/releases/latest/download/amass_Linux_{{ARCH_SUFFIX}}.zip"

# ── Pip ───────────────────────────────────────────────────────
pip3 install --quiet theHarvester recon-ng wapiti3 \
    crackmapexec volatility3 pwntools 2>/dev/null || true

# ── Ruby gems ─────────────────────────────────────────────────
gem install cewl evil-winrm --no-document 2>/dev/null || true

# ── testssl.sh ────────────────────────────────────────────────
curl -fsSL https://testssl.sh/testssl.sh -o /usr/local/bin/testssl.sh 2>/dev/null && \
    chmod +x /usr/local/bin/testssl.sh && \
    ln -sf /usr/local/bin/testssl.sh /usr/local/bin/testssl || true

# ── SELinux enforcing ─────────────────────────────────────────
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null || true

# ── firewalld ─────────────────────────────────────────────────
systemctl enable firewalld 2>/dev/null || true
firewall-cmd --set-default-zone=drop 2>/dev/null || true
firewall-cmd --permanent --add-service=ssh 2>/dev/null || true

# ── Fail2Ban ─────────────────────────────────────────────────
systemctl enable fail2ban 2>/dev/null || true
cat > /etc/fail2ban/jail.local <<'F2B'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd

[sshd]
enabled  = true
port     = ssh
maxretry = 3
bantime  = 86400
F2B

# ── sysctl hardening ─────────────────────────────────────────
cat > /etc/sysctl.d/99-defendos.conf <<'SYSCTL'
net.ipv4.tcp_syncookies               = 1
net.ipv4.conf.all.rp_filter          = 1
net.ipv4.conf.all.accept_redirects   = 0
net.ipv4.conf.all.send_redirects     = 0
net.ipv4.conf.all.log_martians       = 1
net.ipv4.tcp_timestamps              = 0
kernel.randomize_va_space            = 2
kernel.kptr_restrict                 = 2
kernel.dmesg_restrict                = 1
kernel.yama.ptrace_scope             = 2
kernel.sysrq                         = 0
fs.protected_hardlinks               = 1
fs.protected_symlinks                = 1
fs.suid_dumpable                     = 0
SYSCTL

# ── Zsh root ──────────────────────────────────────────────────
chsh -s /bin/zsh root 2>/dev/null || true
cat > /root/.zshrc <<'ZSHRC'
# DefendOS .zshrc – RHEL/Fedora
export HISTSIZE=10000
export HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS SHARE_HISTORY
PROMPT='%F{196}[DefendOS]%f %F{39}%~%f %# '
alias ll='ls -lahF --color=auto'
alias update='dnf upgrade -y'
alias ports='ss -tulnp'
alias firewall='firewall-cmd --list-all'
alias defendos='defendos-gui &'
alias tools='tool-launcher'
export PATH="$PATH:/usr/local/bin:/opt/metasploit-framework/bin"
ZSHRC

# ── Workspace ─────────────────────────────────────────────────
mkdir -p /root/workspace/{reports,captures,wordlists,exploits,forensics}

echo "[+] DefendOS Kickstart post-install terminé"
%end
