# 🔵 Outils Défensifs – DefendOS

## IDS / NDR
| Outil | Description | Commande |
|-------|-------------|----------|
| `suricata` | IDS/IPS réseau | `suricata -c /etc/suricata/suricata.yaml -i eth0` |
| `zeek` | NSM / analyse trafic | `zeek -i eth0 local` |

## Audit & Hardening
| Outil | Description | Commande |
|-------|-------------|----------|
| `lynis` | Audit système complet | `lynis audit system` |
| `rkhunter` | Détection rootkits | `rkhunter --check` |
| `clamav` | Antivirus | `clamscan -r /home --infected` |
| `chkrootkit` | Vérif rootkits | `chkrootkit` |

## Monitoring
| Outil | Description | Commande |
|-------|-------------|----------|
| `fail2ban` | Anti-brute-force | `fail2ban-client status sshd` |
| `ufw` | Pare-feu | `ufw status verbose` |
| `nethogs` | Trafic par process | `nethogs eth0` |
| `iftop` | Trafic réseau | `iftop -i eth0` |

## Forensics
| Outil | Description | Commande |
|-------|-------------|----------|
| `volatility3` | Analyse mémoire | `vol -f mem.dmp windows.pslist` |
| `autopsy` | Forensics disque | Interface graphique |
| `binwalk` | Analyse firmware | `binwalk -e firmware.bin` |
| `foremost` | Récupération fichiers | `foremost -i image.dd -o output/` |
