shell := /bin/sh

dotfiles_dir := $(HOME)/dotfiles
bootstrap := $(dotfiles_dir)/bootstrap/sync-config.sh

# stow ignore patterns (space-separated, passed to --ignore)
stow_ignore := themes Cache logs "*.log"

.phony: help sync stow sync-stow status check clean relink

help:
	@echo "dotfiles commands:"
	@echo "  make sync       - sync allow-listed configs from ~/.config into packages/"
	@echo "  make stow       - symlink packages into $$home using stow"
	@echo "  make sync-stow  - sync + stow in one go"
	@echo "  make relink     - restow all packages (delete + recreate symlinks)"
	@echo "  make status     - show git status"
	@echo "  make check      - run sync + secret scan only (no stow)"
	@echo "  make clean      - show untracked/ignored files (no deletion)"

sync:
	@echo "==> syncing configs (no stow)"
	@$(bootstrap)

stow:
	@echo "==> stowing packages into $$home"
	@command -v stow >/dev/null 2>&1 || (echo "stow not found. install with: brew install stow" && exit 1)
	@cd $(dotfiles_dir) && stow -d packages -t $(home) $(foreach pattern,$(stow_ignore),--ignore='$(pattern)') $$(ls -1 packages)

sync-stow:
	@echo "==> syncing configs and stowing"
	@run_stow=1 $(bootstrap)

relink:
	@echo "==> restowing packages (delete + recreate symlinks)"
	@command -v stow >/dev/null 2>&1 || (echo "stow not found. install with: brew install stow" && exit 1)
	@cd $(dotfiles_dir) && stow -d packages -t $(home) --restow $(foreach pattern,$(stow_ignore),--ignore='$(pattern)') $$(ls -1 packages)

check:
	@echo "==> running sync + safety checks (no stow)"
	@scan_secrets=1 run_stow=0 $(bootstrap)

status:
	@echo "==> git status"
	@cd $(dotfiles_dir) && git status

clean:
	@echo "==> untracked and ignored files (dry run)"
	@cd $(dotfiles_dir) && git status --ignored
