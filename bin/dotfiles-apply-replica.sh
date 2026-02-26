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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

OMARCHY_DIR="${OMARCHY_DIR:-"$HOME/.local/share/omarchy"}"
OMARCHY_REPO_URL="${OMARCHY_REPO_URL:-https://github.com/basecamp/omarchy}"

# Ensure local bin is in PATH for tools like stow (idempotent)
case ":$PATH:" in
*":$HOME/.local/bin:"*) ;;
*) export PATH="$HOME/.local/bin${PATH:+:${PATH}}" ;;
esac

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
            log_info "Neovim config already stowed correctly; skipping"
            return 0
        fi
    fi

    log_info "Setting up Neovim config with stow..."

    # Change to dotfiles directory for stow
    local original_pwd="$PWD"
    cd "$dotfiles_dir" || {
        log_error "Failed to cd to dotfiles directory"
        return 1
    }

    # Use stow to merge nvim config (allows coexistence with LazyVim)
    if stow -d default -t "$HOME/.config" --dotfiles -S dot-config --adopt -v 2>/dev/null; then
        log_info "Successfully stowed nvim config"
    else
        log_warning "Stow failed, trying without --adopt"
        if stow -d default -t "$HOME" --dotfiles -S dot-config 2>/dev/null; then
            log_info "Successfully stowed nvim config"
        else
            log_error "Failed to stow nvim config"
            cd "$original_pwd" || true
            return 1
        fi
    fi

    # Return to original directory
    cd "$original_pwd" || true
}

setup_tmux_config() {
    local dotfiles_dir="$HOME/.dotfiles"
    local tmux_source="$dotfiles_dir/default/dot-config/tmux/tmux.conf"
    local tmux_target="$HOME/.tmux.conf"

    create_symlink_with_backup "$tmux_source" "$tmux_target" "Tmux config"
}

ensure_bashrc_source() {
    local bashrc_path="$HOME/.bashrc"
    local source_line="source '$HOME/.dotfiles/default/dot-bashrc'"

    # Check if already sourced
    if grep -qF "$source_line" "$bashrc_path" 2>/dev/null; then
        log_info "dot-bashrc already sourced in $bashrc_path; skipping"
        return 0
    fi

    log_info "Adding source line for dot-bashrc to $bashrc_path"
    printf '\n# Omarchy tweaks (added by dotfiles-apply-replica)\n%s\n' "$source_line" >>"$bashrc_path"
}

main() {
    ensure_cmd git stow curl

    # Ensure omarchy repo is available
    clone_or_update_omarchy "$OMARCHY_DIR" "$OMARCHY_REPO_URL"

    # Run Julia setup only if Julia is already installed (installation happens in setup script)
    if command -v julia >/dev/null 2>&1; then
        log_info "Running Julia setup script"
        "$SCRIPT_DIR/julia-setup.jl" || log_warning "julia-setup.jl failed"
    else
        log_warning "Julia not found; install it via dotfiles-setup-replica.sh first"
    fi

    # Create symlinks for specific configs
    setup_julia_config
    setup_nvim_config # This stows entire dot-config (includes starship.toml)

    # Handle tmux.conf
    setup_tmux_config

    # Ensure our bashrc is sourced from server's ~/.bashrc
    ensure_bashrc_source

    log_info "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"
