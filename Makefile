# DefendOS – Makefile
# Usage : make <cible>

.PHONY: all iso lint clean install-deps help

PROFILE_DIR  := iso/defendos
BUILD_DIR    := build
WORK_DIR     := $(BUILD_DIR)/work
OUT_DIR      := $(BUILD_DIR)/iso
VERSION      := $(shell git describe --tags --always 2>/dev/null || echo "dev")

# Couleurs
GREEN  := \033[0;32m
YELLOW := \033[1;33m
CYAN   := \033[0;36m
NC     := \033[0m

help: ## Affiche cette aide
	@echo ""
	@echo "  $(CYAN)DefendOS $(VERSION) – Commandes disponibles$(NC)"
	@echo "  ─────────────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}'
	@echo ""

all: lint iso ## Lint + Build ISO

install-deps: ## Installer les dépendances de build (archiso, shellcheck)
	@echo -e "$(GREEN)[+]$(NC) Installation des dépendances..."
	pacman -S --noconfirm --needed archiso shellcheck python

lint: ## Vérifier la syntaxe des scripts (shellcheck + python)
	@echo -e "$(GREEN)[+]$(NC) Shellcheck..."
	@find . -name "*.sh" -not -path "./.git/*" | xargs shellcheck --severity=warning
	@echo -e "$(GREEN)[+]$(NC) Python syntax..."
	@python3 -m py_compile iso/defendos/airootfs/usr/local/bin/defendos-gui
	@python3 -m py_compile iso/defendos/airootfs/usr/local/bin/defendos-welcome
	@python3 -m py_compile iso/defendos/airootfs/usr/local/bin/tool-launcher
	@echo -e "$(GREEN)✔$(NC)  Lint OK"

iso: lint ## Construire l'ISO DefendOS
	@echo -e "$(GREEN)[+]$(NC) Construction de l'ISO DefendOS $(VERSION)..."
	@[ "$$(id -u)" = "0" ] || (echo "root requis pour mkarchiso" && exit 1)
	@mkdir -p $(WORK_DIR) $(OUT_DIR)
	mkarchiso -v \
		-w $(WORK_DIR) \
		-o $(OUT_DIR) \
		$(PROFILE_DIR)
	@ISO=$$(find $(OUT_DIR) -name "*.iso" | head -1); \
	    sha256sum "$$ISO" > "$$ISO.sha256"; \
	    sha512sum "$$ISO" > "$$ISO.sha512"; \
	    echo -e "$(GREEN)✔$(NC)  ISO : $$ISO"; \
	    echo -e "$(GREEN)✔$(NC)  SHA256 : $$(cat $$ISO.sha256 | awk '{print $$1}')"

test-qemu: ## Tester l'ISO dans QEMU (4 Go RAM)
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
	sudo ./install.sh full

clean: ## Nettoyer les artefacts de build
	@echo -e "$(YELLOW)[!]$(NC) Nettoyage de $(BUILD_DIR)..."
	@sudo rm -rf $(BUILD_DIR)
	@echo -e "$(GREEN)✔$(NC)  Nettoyé"
