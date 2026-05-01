#!/usr/bin/env bash
# DefendOS – Module Full (Offensif + Défensif)

set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[+]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR

log "Installation du mode FULL (Offensif + Défensif)..."
bash "${SCRIPT_DIR}/offensive.sh"
bash "${SCRIPT_DIR}/defensive.sh"
log "✅ Mode FULL terminé"
