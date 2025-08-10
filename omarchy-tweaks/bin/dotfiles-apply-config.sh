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

backup_conflicts_for_package() {
    local package_dir="$1" # e.g. /path/to/repo/config
    local target_root="$2" # e.g. ~/.config
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"

    [[ -d "$package_dir" ]] || return 0

    while IFS= read -r -d '' package_file; do
        local rel_path
        rel_path="${package_file#"$package_dir"/}"
        local target_path
        target_path="$target_root/$rel_path"

        if [[ -e "$target_path" && ! -L "$target_path" ]]; then
            local parent_dir backup_dir
            parent_dir="$(dirname "$target_path")"
            backup_dir="$parent_dir/_bak/$timestamp"
            mkdir -p "$backup_dir"
            mv "$target_path" "$backup_dir/"
            log_info "Backed up $(realpath --relative-to="$target_root" "$target_path") → ${backup_dir}/"
        fi
    done < <(find "$package_dir" -type f -print0)
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

    # Backup conflicts proactively so stow can place links
    backup_conflicts_for_package "$PACKAGES_DIR/config" "$TARGET_CONFIG"

    # We treat the 'config' directory as a Stow package and target ~/.config
    # -d: where packages live
    # -t: target directory for links
    # -R: restow (safe to re-run; updates links)
    # -v: verbose for helpful logging
    # Stow 'config' package to ~/.config
    set +e
    STOW_OUTPUT_CONFIG=$(stow -d "$PACKAGES_DIR" -t "$TARGET_CONFIG" -R -v config 2>&1)
    STOW_STATUS_CONFIG=$?
    set -e
    [[ -n "$STOW_OUTPUT_CONFIG" ]] && echo "$STOW_OUTPUT_CONFIG" | sed 's/^/[STOW config] /'
    if [[ $STOW_STATUS_CONFIG -ne 0 ]]; then
        log_warning "Stow (config) reported issues. Conflicts likely exist in $TARGET_CONFIG."
        log_warning "Preview: stow -n -d '$PACKAGES_DIR' -t '$TARGET_CONFIG' -v config"
        return $STOW_STATUS_CONFIG
    fi

    # If a profile was provided, try to apply config-<profile> as an additional package
    if [[ -n "$profile" ]]; then
        local profile_pkg="config-$profile"
        if [[ -d "$PACKAGES_DIR/$profile_pkg" ]]; then
            backup_conflicts_for_package "$PACKAGES_DIR/$profile_pkg" "$TARGET_CONFIG"
            set +e
            STOW_OUTPUT_PROFILE=$(stow -d "$PACKAGES_DIR" -t "$TARGET_CONFIG" -R -v "$profile_pkg" 2>&1)
            STOW_STATUS_PROFILE=$?
            set -e
            [[ -n "$STOW_OUTPUT_PROFILE" ]] && echo "$STOW_OUTPUT_PROFILE" | sed "s/^/[STOW $profile_pkg] /"
            if [[ $STOW_STATUS_PROFILE -ne 0 ]]; then
                log_warning "Stow ($profile_pkg) reported issues. Conflicts likely exist in $TARGET_CONFIG."
                log_warning "Preview: stow -n -d '$PACKAGES_DIR' -t '$TARGET_CONFIG' -v '$profile_pkg'"
                return $STOW_STATUS_PROFILE
            fi
        else
            log_info "No '$profile_pkg' package found; skipping profile package"
        fi
    fi

    # Stow 'home' package to ~ (for files like .bashrc)
    if [[ -d "$PACKAGES_DIR/home" ]]; then
        backup_conflicts_for_package "$PACKAGES_DIR/home" "$TARGET_HOME"
        set +e
        STOW_OUTPUT_HOME=$(stow -d "$PACKAGES_DIR" -t "$TARGET_HOME" -R -v home 2>&1)
        STOW_STATUS_HOME=$?
        set -e
        [[ -n "$STOW_OUTPUT_HOME" ]] && echo "$STOW_OUTPUT_HOME" | sed 's/^/[STOW home] /'
        if [[ $STOW_STATUS_HOME -ne 0 ]]; then
            log_warning "Stow (home) reported issues. Conflicts likely exist in $TARGET_HOME."
            log_warning "Preview: stow -n -d '$PACKAGES_DIR' -t '$TARGET_HOME' -v home"
            return $STOW_STATUS_HOME
        fi
    else
        log_info "No 'home' package found; skipping home-level links"
    fi

    log_success "Symlinked configuration with Stow"
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

