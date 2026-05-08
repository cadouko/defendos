# ⚔️ DefendOS v2.0

> **Distribution cybersécurité modulaire – Debian / Ubuntu / RHEL / Fedora / Rocky**
> Mix équilibré Red Team / Pentest + Blue Team / SIEM – Compatible Windows WSL2 inclus

[![Build Status](https://github.com/defendos/defendos/actions/workflows/build.yml/badge.svg)](https://github.com/defendos/defendos/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Debian](https://img.shields.io/badge/Debian-12%2B-red)](https://debian.org)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%2B-orange)](https://ubuntu.com)
[![RHEL](https://img.shields.io/badge/RHEL%2FFedora%2FRocky-9%2B-blue)](https://rockylinux.org)

---

## 📋 Table des matières

- [À propos](#à-propos)
- [Compatibilité](#compatibilité)
- [Fonctionnalités](#fonctionnalités)
- [Démarrage rapide](#démarrage-rapide)
- [Modules](#modules)
- [Construire l'ISO Live](#construire-liso-live)
- [Hardening](#hardening)
- [Interface graphique](#interface-graphique)
- [Différences v1 → v2](#différences-v1--v2)

---

## À propos

DefendOS est une distribution Linux live et installable orientée cybersécurité,
désormais construite sur **Debian GNU/Linux** (ISO) avec support complet de
**Ubuntu**, **RHEL**, **Fedora** et **Rocky Linux** pour l'installation sur
système existant.

La version 2.0 supprime toute dépendance à Arch Linux et BlackArch, remplacées
par des équivalents maintenus dans les dépôts officiels Debian/RHEL, des
binaires Go (ProjectDiscovery, ffuf…) et des paquets pip/gem.

---

## Compatibilité

| Distribution          | Install `install.sh` | ISO live-build | Kickstart |
|-----------------------|:--------------------:|:--------------:|:---------:|
| Debian 12 (Bookworm)  | ✅                   | ✅             | –         |
| Ubuntu 22.04 / 24.04  | ✅                   | ✅             | –         |
| Fedora 39+            | ✅                   | –              | ✅        |
| Rocky Linux 9+        | ✅                   | –              | ✅        |
| AlmaLinux 9+          | ✅                   | –              | ✅        |
| Windows (WSL2 Ubuntu) | ✅ (sans GUI)        | –              | –         |

---

## Fonctionnalités

| Catégorie       | Outils principaux |
|----------------|-------------------|
| 🔴 Offensif     | Metasploit, Nuclei, SQLMap, ffuf, Burp Suite, Nmap, Hashcat, Aircrack-ng |
| 🔵 Défensif     | Suricata IDS, Zeek NSM, Wazuh Agent, Lynis, Fail2Ban, ClamAV, Auditd |
| 🟣 Forensics    | Volatility3, Autopsy, Binwalk, Radare2, GDB+pwndbg, Foremost |
| ⚙️ Hardening   | SSH, sysctl, AppArmor (Debian) / SELinux (RHEL), UFW / firewalld, auditd |
| 🖥 GUI          | XFCE4, Launcher GTK3, écran de bienvenue, thème sombre |

---

## Prérequis

| Élément              | Debian/Ubuntu          | RHEL/Fedora/Rocky      |
|----------------------|------------------------|------------------------|
| OS minimum           | Debian 12 / Ubuntu 22.04 | RHEL 9 / Fedora 39   |
| Droits               | root (`sudo`)          | root (`sudo`)          |
| Connexion internet   | ✅                     | ✅                     |
| Espace disque        | 10 Go minimum          | 10 Go minimum          |
| Build ISO            | `live-build` + 20 Go   | `livecd-tools` + 20 Go |

---

## Démarrage rapide

```bash
# Cloner le dépôt
git clone https://github.com/defendos/defendos.git
cd defendos

# La distribution est auto-détectée (Debian/Ubuntu ou RHEL/Fedora/Rocky)
sudo ./install.sh full

# Avec confirmation automatique
sudo ./install.sh full --yes

# Sans hardening
sudo ./install.sh full --no-hardening
```

---

## Modules

| Commande                      | Description                           |
|-------------------------------|---------------------------------------|
| `sudo ./install.sh full`      | Offensif + Défensif (recommandé)      |
| `sudo ./install.sh offensive` | Pentest / Red Team uniquement         |
| `sudo ./install.sh defensive` | Blue Team / SIEM uniquement           |
| `sudo ./install.sh iso`       | Construire l'ISO (Debian live-build)  |

Options supplémentaires :

```bash
--yes           # Pas de confirmation interactive
--no-hardening  # Sauter l'étape de hardening
```

---

## Construire l'ISO Live

### Debian / Ubuntu (live-build)

```bash
# Installer les dépendances
sudo make install-deps

# Build complet (lint + ISO)
sudo make all

# Ou ISO seule
sudo make iso

# Tester dans QEMU
sudo make test-qemu
```

L'ISO est générée dans `build/iso/` avec ses checksums SHA256/SHA512.

### Fedora / Rocky / AlmaLinux (Kickstart)

```bash
# Installer livecd-tools
sudo dnf install -y livecd-tools

# Générer l'ISO
sudo make iso-fedora

# Ou directement
sudo livecd-creator \
    --config=iso/fedora/defendos.ks \
    --fslabel=DefendOS
```

### Modes de boot GRUB

| Entrée                        | Description                        |
|-------------------------------|------------------------------------|
| Mode Complet (GUI)            | Démarre XFCE + tous les outils     |
| Mode Console                  | Sans interface graphique            |
| Mode Forensic (noswap)        | Préserve la RAM, pas de swap        |

---

## Hardening

```bash
# Appliquer le hardening avancé (auto-détecte AppArmor ou SELinux)
sudo ./scripts/hardening.sh

# Simulation (aucune modification)
sudo ./scripts/hardening.sh --dry-run

# Sans SSH (si vous êtes en SSH)
sudo ./scripts/hardening.sh --no-ssh

# Sans pare-feu (UFW ou firewalld)
sudo ./scripts/hardening.sh --no-firewall

# Sans contrôle d'accès MAC (AppArmor / SELinux)
sudo ./scripts/hardening.sh --no-mac
```

### Ce que fait le hardening

| Action                  | Debian/Ubuntu              | RHEL/Fedora/Rocky          |
|-------------------------|----------------------------|----------------------------|
| Pare-feu                | UFW (deny incoming)        | firewalld (zone drop)      |
| Contrôle d'accès (MAC)  | AppArmor (enforce)         | SELinux (enforcing)        |
| SSH                     | Clés uniquement, no root   | Identique                  |
| sysctl                  | TCP syncookies, ASLR, BPF  | Identique                  |
| Auditd                  | Règles DefendOS            | Identique                  |
| Fail2Ban                | SSH (3 essais, ban 24h)    | Identique                  |
| Politique mdp           | 14 chars min, complexité   | Identique                  |

---

## Interface graphique

```bash
# Launcher principal (GTK3)
defendos-gui

# Écran de bienvenue
defendos-welcome

# Sélecteur CLI (fzf)
tool-launcher
```

---

## Structure du projet

```
defendos/
├── install.sh                      # Installateur multi-distro (auto-détection)
├── Makefile                        # Cibles de build
├── modules/
│   ├── offensive.sh                # Outils red team (apt/dnf + binaires Go/pip)
│   ├── defensive.sh                # Outils blue team
│   └── full.sh                     # Les deux
├── scripts/
│   └── hardening.sh                # Hardening multi-distro (AppArmor/SELinux)
├── iso/
│   ├── debian/                     # Profil live-build (Debian/Ubuntu)
│   │   ├── auto/
│   │   │   ├── config              # lb config (bookworm, XFCE, etc.)
│   │   │   └── build               # lb build wrapper
│   │   └── config/
│   │       ├── package-lists/
│   │       │   └── defendos.list.chroot   # Paquets Debian
│   │       ├── hooks/live/
│   │       │   └── 9900-defendos.hook.chroot  # Post-install (pip/gem/binaires)
│   │       └── includes.chroot/    # Overlay système de fichiers
│   │           ├── etc/            # Configs SSH, sysctl, auditd, LightDM
│   │           ├── root/           # defendos-post.sh (boot live)
│   │           └── usr/local/bin/  # Launchers GUI et CLI
│   └── fedora/
│       └── defendos.ks             # Kickstart Fedora/Rocky/Alma
├── config/
│   ├── suricata/                   # Config Suricata exemple
│   └── wazuh/                      # Config Wazuh Agent exemple
├── docs/
│   ├── tools-offensif.md
│   └── tools-defensif.md
└── .github/workflows/build.yml     # CI/CD GitHub Actions (Ubuntu runner)
```

---

## Différences v1 → v2

| Aspect              | v1.0 (Arch)              | v2.0 (Debian/RHEL)            |
|---------------------|--------------------------|-------------------------------|
| Base ISO            | Arch Linux + archiso     | Debian 12 + live-build        |
| Dépôt étendu        | BlackArch repo           | EPEL + dépôts ProjectDiscovery |
| AUR / yay           | Requis                   | ❌ Supprimé                   |
| Gestionnaire        | pacman                   | apt-get / dnf (auto-détecté)  |
| MAC                 | AppArmor uniquement       | AppArmor (Debian) / SELinux (RHEL) |
| Pare-feu            | UFW uniquement            | UFW (Debian) / firewalld (RHEL) |
| CI/CD runner        | `archlinux:latest`       | `ubuntu-latest` (natif)       |
| Outils Go           | Via BlackArch            | Binaires GitHub officiels     |
| Build ISO RHEL      | ❌                        | Kickstart (`defendos.ks`)     |

---

## Contribuer

```bash
# Fork + branche
git checkout -b feature/mon-outil

# Linter avant commit
make lint

# Tests
bash -n modules/offensive.sh
shellcheck --severity=warning scripts/hardening.sh
```

---

## ⚠️ Avertissement légal

DefendOS et tous les outils inclus sont destinés **exclusivement** à des tests
sur des systèmes dont vous êtes propriétaire, à des environnements de lab et
à la recherche en sécurité dans un cadre légal.

**Toute utilisation non autorisée est illégale.**

---

## Licence

MIT – voir [LICENSE](LICENSE)
