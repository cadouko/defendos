# DefendOS – Makefile v2.0
# Usage : make <cible>
# Compatible : Debian/Ubuntu (live-build), RHEL/Fedora (kickstart)

.PHONY: all iso iso-fedora lint clean install-deps install help check-distro

PROFILE_DIR  := iso/debian
BUILD_DIR    := build
OUT_DIR      := $(BUILD_DIR)/iso
VERSION      := $(shell git describe --tags --always 2>/dev/null || echo "2.0.0-dev")

# Détection automatique du gestionnaire de paquets
PKG_MGR := $(shell command -v apt-get 2>/dev/null || command -v dnf 2>/dev/null || command -v yum 2>/dev/null || echo "unknown")

GREEN  := \033[0;32m
YELLOW := \033[1;33m
CYAN   := \033[0;36m
NC     := \033[0m

help: ## Affiche cette aide
	@echo ""
	@echo "  $(CYAN)DefendOS $(VERSION) – Commandes disponibles$(NC)"
	@echo "  ─────────────────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

all: lint iso ## Lint + Build ISO Debian

check-distro: ## Vérifier la compatibilité de la distribution
	@echo -e "$(GREEN)[+]$(NC) Détection de la distribution..."
	@if [ -f /etc/os-release ]; then \
		. /etc/os-release; \
		echo -e "$(CYAN)   Distribution : $$PRETTY_NAME$(NC)"; \
		echo -e "$(CYAN)   Gestionnaire  : $(PKG_MGR)$(NC)"; \
	fi

install-deps: check-distro ## Installer les dépendances de build
	@echo -e "$(GREEN)[+]$(NC) Installation des dépendances..."
	@if command -v apt-get >/dev/null 2>&1; then \
		apt-get install -y live-build shellcheck python3 curl git isolinux syslinux-common; \
	elif command -v dnf >/dev/null 2>&1; then \
		dnf install -y livecd-tools lorax shellcheck python3 curl git; \
		echo -e "$(YELLOW)[!]$(NC) Pour Fedora, utilisez 'make iso-fedora' (livecd-creator)"; \
	else \
		echo -e "$(YELLOW)[!]$(NC) Gestionnaire de paquets non reconnu, installez manuellement :"; \
		echo "     live-build shellcheck python3 curl git"; \
		echo "     isolinux syslinux-common (pour les fichiers d'amorçage)"; \
	fi

lint: ## Vérifier la syntaxe des scripts (shellcheck + python)
	@echo -e "$(GREEN)[+]$(NC) Shellcheck..."
	@find . -name "*.sh" -not -path "./.git/*" -not -path "./build/*" | \
		xargs shellcheck --severity=warning || true
	@echo -e "$(GREEN)[+]$(NC) Python syntax..."
	@find iso/debian/config/includes.chroot/usr/local/bin -type f | \
		xargs -I{} python3 -m py_compile {} 2>/dev/null || true
	@echo -e "$(GREEN)✔$(NC)  Lint OK"

iso: lint ## Construire l'ISO DefendOS (Debian live-build)
	@echo -e "$(GREEN)[+]$(NC) Construction de l'ISO DefendOS $(VERSION) (Debian)..."
	@[ "$$(id -u)" = "0" ] || (echo "root requis pour lb build" && exit 1)
	@command -v lb >/dev/null 2>&1 || (echo "live-build requis : apt-get install live-build" && exit 1)
	@mkdir -p $(OUT_DIR)
	cd $(PROFILE_DIR) && \
		lb clean --purge 2>/dev/null || true && \
		bash auto/config && \
		lb build
	@ISO=$$(find $(PROFILE_DIR) -maxdepth 1 -name "*.iso" | head -1); \
	    [ -n "$$ISO" ] || (echo "Aucune ISO générée" && exit 1); \
	    cp "$$ISO" $(OUT_DIR)/; \
	    ISO=$(OUT_DIR)/$$(basename $$ISO); \
	    sha256sum "$$ISO" > "$$ISO.sha256"; \
	    sha512sum "$$ISO" > "$$ISO.sha512"; \
	    echo -e "$(GREEN)✔$(NC)  ISO : $$ISO"; \
	    echo -e "$(GREEN)✔$(NC)  SHA256 : $$(awk '{print $$1}' $$ISO.sha256)"

iso-fedora: ## Générer l'ISO Fedora via kickstart (nécessite livecd-creator)
	@echo -e "$(GREEN)[+]$(NC) Construction de l'ISO DefendOS (Fedora/Rocky)..."
	@[ "$$(id -u)" = "0" ] || (echo "root requis" && exit 1)
	@command -v livecd-creator >/dev/null 2>&1 || \
		(echo "livecd-tools requis : dnf install livecd-tools" && exit 1)
	@mkdir -p $(OUT_DIR)
	livecd-creator \
		--config=iso/fedora/defendos.ks \
		--fslabel=DefendOS \
		--title="DefendOS Cybersecurity OS" \
		--cache=/tmp/defendos-yum-cache \
		--tmpdir=/tmp \
		-d
	@mv DefendOS.iso $(OUT_DIR)/defendos-fedora-$(VERSION).iso 2>/dev/null || true
	@echo -e "$(GREEN)✔$(NC)  ISO Fedora générée dans $(OUT_DIR)"

test-qemu: ## Tester l'ISO dans QEMU (4 Go RAM, KVM)
	@ISO=$$(find $(OUT_DIR) -name "*.iso" | head -1); \
	    [ -f "$$ISO" ] || (echo "Pas d'ISO trouvée dans $(OUT_DIR)" && exit 1); \
	    echo -e "$(CYAN)Démarrage QEMU avec : $$ISO$(NC)"; \
	    qemu-system-x86_64 \
	        -enable-kvm \
	        -m 4G \
	        -smp 2 \
	        -cdrom "$$ISO" \
	        -boot d \
	        -vga virtio \
	        -display gtk

install: ## Installer DefendOS (mode full) sur le système courant
	@echo -e "$(YELLOW)[!]$(NC) Installation en mode FULL sur ce système..."
	sudo bash ./install.sh full

hardening: ## Appliquer uniquement le hardening
	sudo bash ./scripts/hardening.sh

hardening-dry: ## Simuler le hardening (dry-run)
	sudo bash ./scripts/hardening.sh --dry-run

clean: ## Nettoyer les artefacts de build
	@echo -e "$(YELLOW)[!]$(NC) Nettoyage de $(BUILD_DIR) et du cache live-build..."
	@if [ -d $(PROFILE_DIR) ]; then \
		cd $(PROFILE_DIR) && lb clean --purge 2>/dev/null || true; \
	fi
	@sudo rm -rf $(BUILD_DIR)
	@echo -e "$(GREEN)✔$(NC)  Nettoyé"
