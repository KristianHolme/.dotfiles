#!/usr/bin/env bash
set -Eeuo pipefail

# Applies omarchy-tweaks configs for university servers:
# - Creates symlinks for: julia config, starship.toml, tmux.conf  
# - Uses stow for nvim config (to merge with LazyVim)
# - Adds source line to server's ~/.bashrc for our dot-bashrc (idempotent)
# - Ensures omarchy repo is cloned/updated first
#
# Config via env vars:
#   OMARCHY_DIR       - omarchy clone dir (default: ~/.local/share/omarchy)
#   OMARCHY_REPO_URL  - git URL for omarchy (default: https://github.com/basecamp/omarchy)

OMARCHY_DIR="${OMARCHY_DIR:-"$HOME/.local/share/omarchy"}"
OMARCHY_REPO_URL="${OMARCHY_REPO_URL:-https://github.com/basecamp/omarchy}"

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

create_symlink_with_backup() {
    local source_path="$1"
    local target_path="$2"
    local description="$3"

    # Check if source exists
    if [[ ! -e "$source_path" ]]; then
        warn "Source $description not found: $source_path; skipping"
        return 0
    fi

    # Check if already correctly symlinked
    if [[ -L "$target_path" ]]; then
        local current_target="$(readlink "$target_path")"
        if [[ "$current_target" == "$source_path" ]] || [[ "$(realpath "$target_path" 2>/dev/null)" == "$(realpath "$source_path" 2>/dev/null)" ]]; then
            log "$description already symlinked correctly; skipping"
            return 0
        fi
        
        # Different symlink exists, remove it
        warn "Removing existing symlink: $target_path -> $current_target"
        rm "$target_path"
    elif [[ -e "$target_path" ]]; then
        # File/directory exists but isn't a symlink, backup it
        local backup_path="$target_path.backup.$(date +%Y%m%d_%H%M%S)"
        log "Backing up existing $description: $target_path -> $backup_path"
        mv "$target_path" "$backup_path"
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$target_path")"

    # Create the symlink
    log "Creating symlink: $target_path -> $source_path"
    ln -sf "$source_path" "$target_path"
}

setup_julia_config() {
    local dotfiles_dir="$HOME/.dotfiles/"
    local julia_config_source="$dotfiles_dir/default/dot-julia/config"
    local julia_config_target="$HOME/.julia/config"
    
    create_symlink_with_backup "$julia_config_source" "$julia_config_target" "Julia config"
}

setup_nvim_config() {
    local dotfiles_dir="$HOME/.dotfiles"
    
    # Check if already stowed properly
    local test_file="$HOME/.config/nvim/lua/config/options.lua"
    if [[ -L "$test_file" ]]; then
        local link_target="$(readlink "$test_file")"
        if [[ "$link_target" == *"default/dot-config/nvim"* ]]; then
            log "Neovim config already stowed correctly; skipping"
            return 0
        fi
    fi
    
    log "Setting up Neovim config with stow..."
    
    # Change to dotfiles directory for stow
    local original_pwd="$PWD"
    cd "$dotfiles_dir" || {
        err "Failed to cd to dotfiles directory"
        return 1
    }
    
    # Use stow to merge nvim config (allows coexistence with LazyVim)
    if stow -d default -t "$HOME" --dotfiles -S dot-config --adopt 2>/dev/null; then
        log "Successfully stowed nvim config"
    else
        warn "Stow failed, trying without --adopt"
        if stow -d default -t "$HOME" --dotfiles -S dot-config 2>/dev/null; then
            log "Successfully stowed nvim config"
        else
            err "Failed to stow nvim config"
            cd "$original_pwd" || true
            return 1
        fi
    fi
    
    # Return to original directory
    cd "$original_pwd" || true
}

setup_tmux_config() {
    local dotfiles_dir="$HOME/.dotfiles"
    local tmux_source="$dotfiles_dir/default/dot-tmux.conf"
    local tmux_target="$HOME/.tmux.conf"
    
    create_symlink_with_backup "$tmux_source" "$tmux_target" "Tmux config"
}

ensure_bashrc_source() {
    local bashrc_path="$HOME/.bashrc"
    local source_line="source '$HOME/.dotfiles/default/dot-bashrc'"

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
    ensure_cmd stow  # Needed for nvim config

    # Ensure omarchy repo is available
    clone_or_update_omarchy

    # Create symlinks for specific configs
    setup_julia_config
    setup_nvim_config  # This stows entire dot-config (includes starship.toml)

    # Handle tmux.conf 
    setup_tmux_config

    # Ensure our bashrc is sourced from server's ~/.bashrc
    ensure_bashrc_source

    log "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"
