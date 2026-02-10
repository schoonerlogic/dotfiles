SHELL := /bin/sh

DOTFILES_DIR := $(HOME)/dotfiles
BOOTSTRAP := $(DOTFILES_DIR)/bootstrap/sync-config.sh

.PHONY: help sync stow sync-stow status check clean

help:
	@echo "Dotfiles commands:"
	@echo "  make sync       - Sync allow-listed configs from ~/.config into packages/"
	@echo "  make stow       - Symlink packages into $$HOME using stow"
	@echo "  make sync-stow  - Sync + stow in one go"
	@echo "  make status     - Show git status"
	@echo "  make check      - Run sync + secret scan only (no stow)"
	@echo "  make clean      - Show untracked/ignored files (no deletion)"

sync:
	@echo "==> Syncing configs (no stow)"
	@$(BOOTSTRAP)

stow:
	@echo "==> Stowing packages into $$HOME"
	@command -v stow >/dev/null 2>&1 || (echo "stow not found. Install with: brew install stow" && exit 1)
	@cd $(DOTFILES_DIR) && stow -d packages -t $(HOME) $$(ls -1 packages)

sync-stow:
	@echo "==> Syncing configs and stowing"
	@RUN_STOW=1 $(BOOTSTRAP)

check:
	@echo "==> Running sync + safety checks (no stow)"
	@SCAN_SECRETS=1 RUN_STOW=0 $(BOOTSTRAP)

status:
	@echo "==> Git status"
	@cd $(DOTFILES_DIR) && git status

clean:
	@echo "==> Untracked and ignored files (dry run)"
	@cd $(DOTFILES_DIR) && git status --ignored

