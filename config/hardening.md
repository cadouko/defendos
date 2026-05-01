# DefendOS – Guide Hardening

## Application rapide

```bash
sudo ./scripts/hardening.sh
```

## Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Simulation, aucune modification |
| `--no-ssh` | Sauter le hardening SSH |
| `--no-firewall` | Sauter UFW |
| `--no-apparmor` | Sauter AppArmor |

## Vérification post-hardening

```bash
lynis audit system        # Audit complet
ufw status verbose        # Vérifier pare-feu
aa-status                 # Vérifier AppArmor
fail2ban-client status    # Vérifier Fail2Ban
auditctl -l               # Vérifier règles auditd
```

## Paramètres sysctl clés

| Paramètre | Valeur | Effet |
|-----------|--------|-------|
| `kernel.randomize_va_space` | 2 | ASLR complet |
| `kernel.kptr_restrict` | 2 | Masque adresses kernel |
| `kernel.yama.ptrace_scope` | 2 | ptrace restreint |
| `kernel.unprivileged_bpf_disabled` | 1 | BPF root only |
| `net.ipv4.tcp_syncookies` | 1 | Anti SYN flood |
| `fs.suid_dumpable` | 0 | Pas de core dump SUID |
