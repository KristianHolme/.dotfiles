#!/usr/bin/env bash
set -Eeuo pipefail

# Applies omarchy-tweaks configs for university servers:
# - Uses stow to symlink: dot-julia, dot-config (includes nvim and starship.toml)
# - Manually symlinks: dot-tmux.conf -> ~/.tmux.conf
# - Adds source line to server's ~/.bashrc for our dot-bashrc (idempotent)
# - Ensures omarchy repo is cloned/updated first
#
# Config via env vars:
#   OMARCHY_DIR       - omarchy clone dir (default: ~/.local/share/omarchy)
#   OMARCHY_REPO_URL  - git URL for omarchy (default: https://github.com/basecamp/omarchy)
#   STOW_TARGET       - stow target dir (default: $HOME)
#   STOW_PREFIX       - stow package dir prefix (default: ~/.local)

OMARCHY_DIR="${OMARCHY_DIR:-"$HOME/.local/share/omarchy"}"
OMARCHY_REPO_URL="${OMARCHY_REPO_URL:-https://github.com/basecamp/omarchy}"
STOW_TARGET="${STOW_TARGET:-"$HOME"}"
STOW_PREFIX="${STOW_PREFIX:-"$HOME/.local"}"

log() { echo "[omarchy-replica] $*"; }
warn() { echo "[omarchy-replica][WARN] $*" >&2; }
err() { echo "[omarchy-replica][ERR] $*" >&2; }

ensure_cmd() {
    command -v "$1" >/dev/null 2>&1 || { err "Missing required command: $1"; exit 1; }
}

# Ensure local bin is in PATH for tools like stow (idempotent)
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin${PATH:+:${PATH}}" ;;
esac

clone_or_update_omarchy() {
    if [[ -d "$OMARCHY_DIR/.git" ]]; then
        log "Updating omarchy in $OMARCHY_DIR"
        git -C "$OMARCHY_DIR" pull --ff-only || warn "omarchy update failed; continuing"
        return 0
    fi
    if [[ -z "${OMARCHY_REPO_URL}" ]]; then
        warn "OMARCHY_REPO_URL not set and no existing clone at $OMARCHY_DIR; skipping clone"
        return 0
    fi
    mkdir -p "$(dirname "$OMARCHY_DIR")"
    log "Cloning omarchy from $OMARCHY_REPO_URL -> $OMARCHY_DIR"
    git clone "$OMARCHY_REPO_URL" "$OMARCHY_DIR" || warn "omarchy clone failed; continuing"
}

stow_config() {
    local package="$1"
    local package_dir="$HOME/.dotfiles/omarchy-tweaks/default/$package"

    if [[ ! -d "$package_dir" ]]; then
        warn "Package $package not found in $HOME/.dotfiles/omarchy-tweaks/default; skipping"
        return 0
    fi

    # Check if already stowed by looking for stow .stow files or symlinks
    local stow_file="$STOW_TARGET/.stow/$package"
    if [[ -f "$stow_file" ]] || [[ -L "$STOW_TARGET/.$package" ]]; then
        log "$package already stowed; skipping"
        return 0
    fi

    log "Stowing $package from $package_dir to $STOW_TARGET"
    mkdir -p "$STOW_TARGET/.stow"
    stow --dir="$HOME/.dotfiles/omarchy-tweaks/default" --target="$STOW_TARGET" --stow "$package" \
        || warn "Failed to stow $package; continuing"
}

symlink_config() {
    local source_file="$1"
    local target_file="$2"
    local source_path="$HOME/.dotfiles/omarchy-tweaks/default/$source_file"
    local target_path="$STOW_TARGET/$target_file"

    if [[ ! -f "$source_path" ]]; then
        warn "Source file $source_path not found; skipping"
        return 0
    fi

    # Check if symlink already exists and points to the right place
    if [[ -L "$target_path" ]] && [[ "$(readlink "$target_path")" == "$source_path" ]]; then
        log "$target_file already symlinked correctly; skipping"
        return 0
    fi

    # Backup existing file if it's not already a symlink
    if [[ -f "$target_path" ]] && [[ ! -L "$target_path" ]]; then
        local backup_path="$target_path.backup.$(date +%Y%m%d_%H%M%S)"
        log "Backing up existing $target_path to $backup_path"
        mv "$target_path" "$backup_path"
    fi

    log "Creating symlink: $target_path -> $source_path"
    ln -sf "$source_path" "$target_path"
}

ensure_bashrc_source() {
    local bashrc_path="$HOME/.bashrc"
    local source_line="source '$HOME/.dotfiles/omarchy-tweaks/default/dot-bashrc'"

    # Check if already sourced
    if grep -qF "$source_line" "$bashrc_path" 2>/dev/null; then
        log "dot-bashrc already sourced in $bashrc_path; skipping"
        return 0
    fi

    log "Adding source line for dot-bashrc to $bashrc_path"
    printf '\n# Omarchy tweaks (added by dotfiles-apply-replica)\n%s\n' "$source_line" >> "$bashrc_path"
}

main() {
    ensure_cmd git
    ensure_cmd stow

    # Ensure omarchy repo is available
    clone_or_update_omarchy

    # Stow specific packages (only those mentioned)
    stow_config "dot-julia"
    stow_config "dot-config"  # includes nvim config and starship.toml

    # Handle tmux.conf manually (stow doesn't work well with individual files)
    symlink_config "dot-tmux.conf" ".tmux.conf"

    # Ensure our bashrc is sourced from server's ~/.bashrc
    ensure_bashrc_source

    log "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"
