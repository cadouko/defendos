# ⚔️ DefendOS

> **Distribution cybersécurité modulaire – Arch Linux + BlackArch**
> Mix équilibré Red Team / Pentest + Blue Team / SIEM light

[![Build Status](https://github.com/defendos/defendos/actions/workflows/build.yml/badge.svg)](https://github.com/defendos/defendos/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📋 Table des matières

- [À propos](#à-propos)
- [Fonctionnalités](#fonctionnalités)
- [Prérequis](#prérequis)
- [Démarrage rapide](#démarrage-rapide)
- [Modules](#modules)
- [Construire l'ISO Live](#construire-liso-live)
- [Hardening](#hardening)
- [Interface graphique](#interface-graphique)
- [Configuration](#configuration)
- [Contribuer](#contribuer)
- [Avertissement légal](#avertissement-légal)

---

## À propos

DefendOS est une distribution Linux live et installable orientée cybersécurité,
construite sur **Arch Linux + BlackArch**. Elle combine en un seul environnement :

- Les outils **offensifs** (pentest, red team, exploitation)
- Les outils **défensifs** (blue team, IDS, SIEM, hardening)
- Un **hardening système** avancé et reproductible
- Une **interface graphique** XFCE avec launcher dédié

---

## Fonctionnalités

| Catégorie       | Outils principaux |
|----------------|-------------------|
| 🔴 Offensif     | Metasploit, Nuclei, SQLMap, ffuf, Burp Suite, Nmap, Hashcat, Aircrack-ng |
| 🔵 Défensif     | Suricata IDS, Zeek NSM, Wazuh Agent, Lynis, Fail2Ban, ClamAV, Auditd |
| 🟣 Forensics    | Volatility3, Autopsy, Binwalk, Radare2, GDB+pwndbg, Foremost |
| ⚙️ Hardening    | SSH, sysctl, AppArmor, auditd, UFW, limites système, politique mdp |
| 🖥 GUI          | XFCE4, Launcher GTK3, écran de bienvenue, thème sombre |

---

## Prérequis

- **Arch Linux** (pour l'installation sur système existant)
- **Droits root** (`sudo`)
- **Connexion internet**
- **10 Go d'espace disque** minimum
- Pour builder l'ISO : `archiso` + **20 Go** libres

---

## Démarrage rapide

```bash
# Cloner le dépôt
git clone https://github.com/defendos/defendos.git
cd defendos

# Installation mode Full (Offensif + Défensif)
sudo ./install.sh full

# Ou avec confirmation automatique
sudo ./install.sh full --yes
```

---

## Modules

| Commande                      | Description                          |
|-------------------------------|--------------------------------------|
| `sudo ./install.sh full`      | Offensif + Défensif (recommandé)     |
| `sudo ./install.sh offensive` | Pentest / Red Team uniquement        |
| `sudo ./install.sh defensive` | Blue Team / SIEM uniquement          |
| `sudo ./install.sh iso`       | Construire l'ISO live (via archiso)  |

Options supplémentaires :

```bash
--yes           # Pas de confirmation interactive
--no-hardening  # Sauter l'étape de hardening
```

---

## Construire l'ISO Live

```bash
# Via make (recommandé)
sudo make iso

# Ou directement
sudo ./install.sh iso

# Tester dans QEMU
sudo make test-qemu
```

L'ISO est générée dans `build/iso/` avec ses checksums SHA256/SHA512.

### Boot options

| Entrée GRUB                    | Description                       |
|-------------------------------|-----------------------------------|
| Mode Complet (GUI)            | Démarre XFCE + tous les outils    |
| Mode Console                  | Sans interface graphique          |
| Mode Forensic (noswap)        | Préserve la RAM, pas de swap      |

---

## Hardening

```bash
# Appliquer le hardening avancé
sudo ./scripts/hardening.sh

# Simulation (aucune modification)
sudo ./scripts/hardening.sh --dry-run

# Sans SSH (si vous êtes en SSH)
sudo ./scripts/hardening.sh --no-ssh
```

### Ce que fait le hardening

- **sysctl** : TCP syncookies, rp_filter, ASLR max, kptr_restrict, BPF restreint
- **SSH** : Pas de root login, clés uniquement, chiffrement fort
- **UFW** : deny incoming / allow outgoing, SSH rate-limited
- **AppArmor** : Profils en mode enforce
- **Auditd** : Règles de traçabilité (identité, sudo, réseau, modules)
- **Fail2Ban** : SSH protégé (3 essais, ban 24h)
- **Permissions** : `/etc/shadow`, `/boot`, `/var/log` durcis
- **Politique mots de passe** : 14 caractères minimum, complexité requise

---

## Interface graphique

En mode live, l'interface se lance automatiquement avec LightDM + XFCE.

```bash
# Launcher principal (GTK3)
defendos-gui

# Écran de bienvenue
defendos-welcome

# Sélecteur CLI (fzf)
tool-launcher
```

---

## Configuration

| Fichier                               | Usage                         |
|---------------------------------------|-------------------------------|
| `config/suricata/suricata.yaml.example` | Config Suricata à adapter   |
| `config/wazuh/wazuh-agent.conf.example` | Config Wazuh Agent          |
| `iso/defendos/packages.x86_64`         | Liste des paquets de l'ISO   |
| `iso/defendos/profiledef.sh`           | Profil archiso               |
| `iso/defendos/grub/grub.cfg`           | Menu de boot GRUB            |

---

## Structure du projet

```
defendos/
├── install.sh                    # Installateur principal
├── Makefile                      # Cibles de build
├── modules/
│   ├── offensive.sh              # Outils red team
│   ├── defensive.sh              # Outils blue team
│   └── full.sh                   # Les deux
├── scripts/
│   └── hardening.sh              # Hardening système avancé
├── iso/defendos/                 # Profil archiso
│   ├── profiledef.sh             # Définition ISO
│   ├── pacman.conf               # Dépôts (Arch + BlackArch)
│   ├── packages.x86_64           # Paquets inclus
│   ├── grub/grub.cfg             # Boot GRUB
│   └── airootfs/                 # Système de fichiers live
│       ├── etc/                  # Configs système
│       ├── root/defendos-post.sh # Script post-boot
│       └── usr/local/bin/        # Launchers & outils
├── config/
│   ├── suricata/                 # Config Suricata
│   └── wazuh/                    # Config Wazuh
└── .github/workflows/build.yml   # CI/CD GitHub Actions
```

---

## Contribuer

1. Fork le dépôt
2. Crée une branche : `git checkout -b feature/mon-outil`
3. Commit : `git commit -m 'feat: ajouter mon-outil'`
4. Push : `git push origin feature/mon-outil`
5. Ouvre une Pull Request

Merci de tester avec `shellcheck` avant de soumettre :
```bash
make lint
```

---

## ⚠️ Avertissement légal

DefendOS et tous les outils inclus sont destinés **exclusivement** à :
- Des tests d'intrusion sur des systèmes dont vous êtes propriétaire
- Des environnements de lab et de formation
- De la recherche en sécurité dans un cadre légal
- La défense de systèmes dont vous avez l'autorisation explicite

**Toute utilisation non autorisée est illégale** et peut entraîner des poursuites
judiciaires. Les auteurs déclinent toute responsabilité pour une utilisation abusive.

---

## Licence

MIT – voir [LICENSE](LICENSE)
