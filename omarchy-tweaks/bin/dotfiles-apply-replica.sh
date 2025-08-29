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

stow_with_conflict_detection() {
    local packages_dir="$1"  # e.g. "." (current directory)
    local package_name="$2"  # e.g. "dot-config"
    local target_dir="$3"    # e.g. $HOME
    local description="$4"   # e.g. "config files"
    shift 4
    local extra_flags=("$@")

    # Check if package exists (now using relative path since we're in the right directory)
    [[ -d "default/$package_name" ]] || {
        warn "Package $package_name not found in default/; skipping"
        return 0
    }

    # With --dotfiles, dot-julia becomes .julia, dot-config becomes .config, etc.
    local target_name="${package_name#dot-}"  # Remove "dot-" prefix
    local target_link="$target_dir/.$target_name"
    
    # Check if already correctly stowed by examining key files
    local already_stowed=true
    case "$package_name" in
        "dot-julia")
            local julia_startup="$target_dir/.julia/config/startup.jl"
            if [[ -L "$julia_startup" ]]; then
                local link_target="$(readlink "$julia_startup")"
                if [[ "$link_target" == *"/default/$package_name/"* ]] || [[ "$link_target" == *"default/$package_name/"* ]]; then
                    log "$package_name already stowed correctly; skipping"
                    return 0
                fi
            fi
            already_stowed=false
            ;;
        "dot-config")
            # Check a few key config files to see if they're stowed
            local files_to_check=(
                "$target_dir/.config/nvim/lua/config/options.lua"
                "$target_dir/.config/starship.toml"
            )
            local stowed_count=0
            for file in "${files_to_check[@]}"; do
                if [[ -L "$file" ]]; then
                    local link_target="$(readlink "$file")"
                    if [[ "$link_target" == *"/default/$package_name/"* ]] || [[ "$link_target" == *"default/$package_name/"* ]]; then
                        stowed_count=$((stowed_count + 1))
                    fi
                fi
            done
            if [[ $stowed_count -gt 0 ]]; then
                log "$package_name already stowed correctly; skipping"
                return 0
            fi
            already_stowed=false
            ;;
    esac

    log "Checking for conflicts in $description..."

    # Dry run to detect conflicts
    set +e
    local dry_run_output
    # Use -S for initial stow to avoid restow conflicts
    # -d points to directory containing packages, then specify package name without slashes
    dry_run_output=$(stow -n -d "default" -t "$target_dir" -S --dotfiles "${extra_flags[@]}" "$package_name" 2>&1)
    local dry_run_status=$?
    set -e

    if [[ $dry_run_status -eq 0 ]]; then
        # No conflicts, proceed with stow
        log "No conflicts detected, proceeding with $description symlinks..."
        if stow -d "default" -t "$target_dir" -S --dotfiles "${extra_flags[@]}" "$package_name"; then
            log "Successfully stowed $package_name"
        else
            warn "Stow command failed for $package_name"
            return 1
        fi
    else
        # Conflicts detected, present user with options
        warn "Conflicts detected in $description:"
        echo "$dry_run_output" | grep -E "(WARNING|ERROR|existing)" || echo "$dry_run_output"
        echo

        if ! command -v gum >/dev/null 2>&1; then
            warn "gum not found. Install with: bash ~/.dotfiles/omarchy-tweaks/bin/dotfiles-setup-replica.sh"
            warn "Manual resolution required for $description conflicts"
            return 1
        fi

        local choice
        choice=$(gum choose \
            "Adopt conflicting files (move them to dotfiles repo)" \
            "Abort (keep existing files)" \
            --header "How should conflicts be resolved for $description?") || choice="Abort (keep existing files)"

        case "$choice" in
        "Adopt conflicting files"*)
            log "Adopting conflicting files for $description..."
            if stow -d "default" -t "$target_dir" -S --dotfiles --adopt "${extra_flags[@]}" "$package_name"; then
                log "Successfully adopted conflicts and stowed $package_name"
                warn "Conflicting files moved to dotfiles repo - review and commit changes"
            else
                warn "Adopt failed; falling back to manual symlinks"

                # Manual symlink fallback - create the correct target with --dotfiles transformation
                local target_name="${package_name#dot-}"  # Remove "dot-" prefix  
                local target_dir_full="$target_dir/.$target_name"
                local source_path="$(pwd)/default/$package_name"

                # Remove existing symlink if it exists
                if [[ -L "$target_dir_full" ]]; then
                    rm "$target_dir_full"
                fi

                # Create new symlink if target doesn't exist
                if [[ ! -e "$target_dir_full" ]]; then
                    log "Creating manual symlink: $target_dir_full -> $source_path"
                    ln -sf "$source_path" "$target_dir_full"
                else
                    warn "Target $target_dir_full exists and is not a symlink; manual intervention required"
                fi
            fi
            ;;
        "Abort"*)
            log "Aborted $description linking due to conflicts"
            return 1
            ;;
        esac
    fi
}

stow_config() {
    local package="$1"
    # Change to the correct directory to avoid stow directory marker issues
    local original_pwd="$PWD"
    cd "$HOME/.dotfiles/omarchy-tweaks" || {
        err "Failed to cd to dotfiles directory"
        return 1
    }

    stow_with_conflict_detection "." "$package" "$STOW_TARGET" "$package config" --override='.*'

    # Return to original directory
    cd "$original_pwd" || true
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
