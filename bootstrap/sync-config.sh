#!/usr/bin/env bash
set -euo pipefail

# ---------- user-configurable ----------
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
PACKAGES_DIR="$DOTFILES_DIR/packages"
MANIFEST="${MANIFEST:-$DOTFILES_DIR/manifest.conf}"
CONFIG_ROOT="$HOME/.config"

# set to 1 to run `stow` after syncing
RUN_STOW="${RUN_STOW:-0}"

# set to 1 to do a light secret-string scan over copied files
SCAN_SECRETS="${SCAN_SECRETS:-1}"

# ---------- helpers ----------
err() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }

# ---------- safety rails ----------
DENY_PREFIXES=(
  "gcloud"
  "op"
  "1Password"
  "entire"
)

DENY_CONTAINS=(
  "/conversations"
  "/prompts"
  "prompts-library-db"
  ".mdb"
  ".sqlite"
  ".db"
  "/Cache"
  "/State"
  ".log"
)

DENY_BASENAMES=(
  "hosts.yml"
  "zed.env"
)

is_denied_path() {
  local rel="$1"

  for p in "${DENY_PREFIXES[@]}"; do
    [[ "$rel" == "$p"* ]] && return 0
  done

  local base
  base="$(basename "$rel")"
  for b in "${DENY_BASENAMES[@]}"; do
    [[ "$base" == "$b" ]] && return 0
  done

  for pat in "${DENY_CONTAINS[@]}"; do
    [[ "$rel" == *"$pat"* ]] && return 0
  done

  return 1
}

copy_item() {
  local tool="$1"
  local rel="$2"
  local src="$CONFIG_ROOT/$rel"
  # Prevent symlink loops: if ~/.config entry is a symlink, it's already managed by dotfiles.
  if [[ -L "$src" ]]; then
    warn "Source is a symlink (already managed). Skipping: $rel"
    return 0
  fi

  local dst_root="$PACKAGES_DIR/$tool/.config"
  local dst="$dst_root/$rel"

  [[ -e "$src" ]] || err "Missing source: $src"

  if is_denied_path "$rel"; then
    err "Refusing to copy denied path: $rel (tool=$tool)"
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -d "$src" ]]; then
    rsync -a --delete --exclude ".DS_Store" "$src/" "$dst/"
  else
    rsync -a "$src" "$dst"
  fi

  echo "OK  $tool:$rel"
}

secret_scan() {
  local root="$1"
  local hits
  hits="$(grep -RInE \
    '(op://|AKIA[0-9A-Z]{16}|xox[baprs]-|ghp_[A-Za-z0-9]{30,}|AIzaSy|BEGIN (RSA|OPENSSH) PRIVATE KEY|-----BEGIN PRIVATE KEY-----)' \
    "$root" 2>/dev/null || true)"

  if [[ -n "$hits" ]]; then
    echo "$hits" >&2
    err "Secret-scan found suspicious strings in copied files. Fix before committing."
  fi
}

main() {
  [[ -d "$DOTFILES_DIR" ]] || err "DOTFILES_DIR not found: $DOTFILES_DIR"
  [[ -f "$MANIFEST" ]] || err "Manifest not found: $MANIFEST"

  mkdir -p "$PACKAGES_DIR"

  echo "Syncing from $CONFIG_ROOT -> $PACKAGES_DIR"
  echo "Using manifest: $MANIFEST"
  echo

  while IFS= read -r line; do
    [[ -z "${line// }" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    [[ "$line" == *":"* ]] || err "Bad manifest line (expected tool:path): $line"

    tool="${line%%:*}"
    rel="${line#*:}"

    tool="${tool//[[:space:]]/}"
    rel="${rel#"${rel%%[![:space:]]*}"}"
    rel="${rel%"${rel##*[![:space:]]}"}"

    [[ -n "$tool" && -n "$rel" ]] || err "Bad manifest line: $line"
    [[ "$rel" != /* ]] || err "Manifest must use paths relative to ~/.config: $line"
    [[ "$rel" != *".."* ]] || err "Manifest path cannot contain '..': $line"

    copy_item "$tool" "$rel"
  done < "$MANIFEST"

  echo
  if [[ "$SCAN_SECRETS" == "1" ]]; then
    echo "Running secret scan..."
    secret_scan "$PACKAGES_DIR"
    echo "Secret scan: OK"
    echo
  fi

  if [[ "$RUN_STOW" == "1" ]]; then
    command -v stow >/dev/null 2>&1 || err "stow not found; install with: brew install stow"

    ts="$(date +%Y%m%d-%H%M%S)"
    backup_root="$HOME/.config/.dotfiles-backup/$ts"
    mkdir -p "$backup_root"

    echo "Checking stow conflicts (dry run)..."
    dry_out="$(cd "$DOTFILES_DIR" && stow -n -d packages -t "$HOME" $(ls -1 "$PACKAGES_DIR") 2>&1 || true)"

    if echo "$dry_out" | grep -q "would cause conflicts"; then
      echo "$dry_out" >&2
      echo
      echo "Conflicts detected. Backing up conflicting targets to:"
      echo "  $backup_root"
      echo

      echo "$dry_out" | awk '
        /cannot stow/ {
          for (i=1; i<=NF; i++) {
            if ($i == "target") { print $(i+1) }
          }
        }
      ' | while IFS= read -r rel_target; do
        [[ -n "$rel_target" ]] || continue
        src="$HOME/$rel_target"
        dst="$backup_root/$rel_target"

        if [[ -e "$src" && ! -L "$src" ]]; then
          mkdir -p "$(dirname "$dst")"
          mv "$src" "$dst"
          echo "BACKUP $rel_target"
        fi
      done
      echo
    fi

    echo "Running stow..."
    (cd "$DOTFILES_DIR" && stow -d packages -t "$HOME" $(ls -1 "$PACKAGES_DIR"))
    echo "Stow done."
  else
    echo "Skipping stow (set RUN_STOW=1 to enable)."
  fi

  echo
  echo "Done."
}

main "$@"
