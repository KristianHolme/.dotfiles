#!/bin/bash

# Simple Omarchy Tweaks Application Script
# Copies config files from dotfiles to system locations

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script lives in bin/, configs live one directory up in ../config
CONFIG_SOURCE="$(realpath "$SCRIPT_DIR/../config")"
TARGET_CONFIG="$HOME/.config"
TARGET_HOME="$HOME"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Simple function to unstow all profiles using GNU Stow -D
unstow_all_profiles() {
    local packages_dir="$1"
    local target_dir="$2"
    
    local profiles_dir="$packages_dir/profiles"
    [[ -d "$profiles_dir" ]] || return 0
    
    log_info "Unstowing any existing profiles..."
    
    # Unstow all profiles (ignore errors if not currently stowed)
    for profile_path in "$profiles_dir"/*; do
        if [[ -d "$profile_path/.config" ]]; then
            stow -d "$profile_path" -t "$target_dir" -D ".config" 2>/dev/null || true
        fi
    done
}

stow_with_conflict_detection() {
    local packages_dir="$1"    # e.g. /path/to/dotfiles
    local package_name="$2"    # e.g. ".config" or "home"  
    local target_dir="$3"      # e.g. ~/.config or ~
    local description="$4"     # e.g. "config files" or "home files"

    # Check if package exists
    [[ -d "$packages_dir/$package_name" ]] || return 0

    log_info "Checking for conflicts in $description..."
    
    # Dry run to detect conflicts
    set +e
    local dry_run_output
    dry_run_output=$(stow -n -d "$packages_dir" -t "$target_dir" -R -v "$package_name" 2>&1)
    local dry_run_status=$?
    set -e

    if [[ $dry_run_status -eq 0 ]]; then
        # No conflicts, proceed with normal stow
        log_info "No conflicts detected, proceeding with $description symlinks..."
        stow -d "$packages_dir" -t "$target_dir" -R -v "$package_name"
        log_success "Successfully linked $description"
    else
        # Conflicts detected, present user with options
        log_warning "Conflicts detected in $description:"
        echo "$dry_run_output" | grep -E "(WARNING|ERROR|existing)" || echo "$dry_run_output"
        echo
        
        if ! command -v gum >/dev/null 2>&1; then
            log_warning "gum not found. Install with: pacman -S gum"
            log_warning "Manual resolution required for $description conflicts"
            return 1
        fi

        local choice
        choice=$(gum choose \
            "Adopt conflicting files (move them to dotfiles repo)" \
            "Abort (keep existing files)" \
            --header "How should conflicts be resolved for $description?")

        case "$choice" in
            "Adopt conflicting files"*)
                log_info "Adopting conflicting files for $description..."
                stow -d "$packages_dir" -t "$target_dir" -R -v --adopt "$package_name"
                log_success "Adopted conflicts and linked $description"
                log_warning "Conflicting files moved to dotfiles repo - review and commit changes"
                ;;
            "Abort"*)
                log_info "Aborted $description linking due to conflicts"
                return 1
                ;;
        esac
    fi
}

########################################
# Apply configs using GNU Stow (symlinks)
########################################
apply_configs() {
    log_info "Linking with GNU Stow"

    if ! command -v stow >/dev/null 2>&1; then
        log_warning "stow not found. Please install GNU Stow (e.g. pacman -S stow) and re-run."
        return 1
    fi

    # Packages directory (repo root of omarchy-tweaks)
    PACKAGES_DIR="$(realpath "$SCRIPT_DIR/..")"
    # Optional profile argument (e.g. "work" -> config-work)
    local profile="${1:-}"

    # Apply .config package with conflict detection
    stow_with_conflict_detection "$PACKAGES_DIR" ".config" "$TARGET_CONFIG" "config files"
    
    # If a profile was provided, handle profile switching
    if [[ -n "$profile" ]]; then
        local profile_packages_dir="$PACKAGES_DIR/profiles/$profile"
        if [[ -d "$profile_packages_dir/.config" ]]; then
            # First, unstow all existing profiles to avoid profile-to-profile conflicts
            unstow_all_profiles "$PACKAGES_DIR" "$TARGET_CONFIG"
            
            # Then use conflict detection for any remaining conflicts (user files, etc.)
            stow_with_conflict_detection "$profile_packages_dir" ".config" "$TARGET_CONFIG" "profile config files"
        else
            log_info "No profile .config found for '$profile'; skipping profile config"
        fi
    fi

    # Apply home package with conflict detection
    stow_with_conflict_detection "$PACKAGES_DIR" "home" "$TARGET_HOME" "home files"

    log_success "Configuration linking completed"
}


# Removed bashrc manual sourcing; handled by Stow 'home' package

# Reload hyprland
reload_hyprland() {
    if command -v hyprctl &>/dev/null; then
        hyprctl reload || true
        log_success "Reloaded Hyprland configuration"
    else
        log_warning "hyprctl not found. Please reload Hyprland manually."
    fi
}

main() {
    local profile_arg="${1:-}"
    if [[ -n "$profile_arg" ]]; then
        log_info "Applying Omarchy tweaks (profile: $profile_arg)..."
    else
        log_info "Applying Omarchy tweaks..."
    fi
    apply_configs "$profile_arg"
    reload_hyprland
    log_success "All tweaks applied successfully!"
}

main "$@"
exit $?

