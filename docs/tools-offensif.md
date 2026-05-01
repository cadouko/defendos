# 🔴 Outils Offensifs – DefendOS

## Reconnaissance
| Outil | Description | Usage rapide |
|-------|-------------|--------------|
| `nmap` | Scanner réseau | `nmap -sV -sC -p- <cible>` |
| `masscan` | Scanner ultra-rapide | `masscan -p1-65535 <cible> --rate=1000` |
| `rustscan` | Scanner moderne | `rustscan -a <cible> -- -sV` |
| `subfinder` | Sous-domaines | `subfinder -d example.com` |
| `amass` | OSINT / sous-domaines | `amass enum -d example.com` |
| `httpx` | Probe HTTP | `httpx -l urls.txt -status-code` |
| `nuclei` | Scanner de vulnérabilités | `nuclei -u https://example.com` |

## Web
| Outil | Description | Usage rapide |
|-------|-------------|--------------|
| `ffuf` | Fuzzer web | `ffuf -u https://site/FUZZ -w wordlist.txt` |
| `gobuster` | Dir busting | `gobuster dir -u https://site -w /usr/share/wordlists/dirb/common.txt` |
| `sqlmap` | SQLi automatisé | `sqlmap -u "https://site/?id=1" --dbs` |
| `burpsuite` | Proxy intercepteur | Interface graphique |
| `nikto` | Scanner web | `nikto -h https://site` |

## Exploitation
| Outil | Description | Usage rapide |
|-------|-------------|--------------|
| `metasploit` | Framework d'exploitation | `msfconsole -q` |
| `searchsploit` | Recherche exploits | `searchsploit apache 2.4` |

## Passwords
| Outil | Description | Usage rapide |
|-------|-------------|--------------|
| `hashcat` | Cracking GPU | `hashcat -m 1000 hash.txt rockyou.txt` |
| `john` | Cracking CPU | `john --wordlist=rockyou.txt hash.txt` |
| `hydra` | Brute-force | `hydra -l admin -P pass.txt ssh://cible` |

## Wireless
| Outil | Description | Usage rapide |
|-------|-------------|--------------|
| `aircrack-ng` | Audit WiFi | `airmon-ng start wlan0` |
| `hcxdumptool` | Capture WPA | `hcxdumptool -i wlan0mon -o cap.pcapng` |
