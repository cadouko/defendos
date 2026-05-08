#!/usr/bin/env bash
# DefendOS – Module Full (Offensif + Défensif)

set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[+]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Propager les variables de distro
export DISTRO_FAMILY="${DISTRO_FAMILY:-}"
export PKG_MGR="${PKG_MGR:-}"
export DISTRO_ID="${DISTRO_ID:-}"
export AUTO_YES="${AUTO_YES:-false}"

log "Installation du mode FULL (Offensif + Défensif)..."
bash "${SCRIPT_DIR}/offensive.sh"
bash "${SCRIPT_DIR}/defensive.sh"
log "✅ Mode FULL terminé"
