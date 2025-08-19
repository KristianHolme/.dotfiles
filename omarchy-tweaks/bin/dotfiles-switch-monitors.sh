#!/bin/bash
set -Eeuo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TWEAKS_ROOT="$(realpath "$SCRIPT_DIR/..")"

usage() {
    cat <<EOF
Usage: $0 <profile_name>

Switch monitor configuration for the specified omarchy-tweaks profile.

Arguments:
  profile_name    Name of the profile (e.g., sibir, bengal, kaspi)

Examples:
  $0 sibir        # Switch monitor config for sibir profile
  $0 bengal       # Switch monitor config for bengal profile

This script will:
1. Find available monitor configurations in the profile
2. Present them as choices using gum
3. Symlink the selected config to monitors.conf and tiling.conf
4. Reload Hyprland configuration
EOF
}

# Check dependencies
check_dependencies() {
    if ! command -v gum >/dev/null 2>&1; then
        log_error "gum not found. Install with: pacman -S gum"
        exit 1
    fi
}

# Find available monitor configurations
find_monitor_configs() {
    local profile="$1"
    local profile_dir="$TWEAKS_ROOT/profiles/$profile/.config/hypr"

    if [[ ! -d "$profile_dir" ]]; then
        log_error "Profile directory not found: $profile_dir"
        exit 1
    fi

    # Find monitors-*.conf files
    local configs=()
    while IFS= read -r -d '' file; do
        local basename=$(basename "$file")
        local config_name=${basename#monitors-}
        config_name=${config_name%.conf}
        configs+=("$config_name")
    done < <(find "$profile_dir" -name "monitors-*.conf" -print0 2>/dev/null || true)

    if [[ ${#configs[@]} -eq 0 ]]; then
        log_error "No monitor configurations found in $profile_dir"
        log_info "Expected files like monitors-1.conf, monitors-2.conf, etc."
        exit 1
    fi

    printf '%s\n' "${configs[@]}"
}

# Create description for each config
get_config_description() {
    local profile="$1"
    local config="$2"
    local profile_dir="$TWEAKS_ROOT/profiles/$profile/.config/hypr"
    local monitors_file="$profile_dir/monitors-$config.conf"

    # Extract description from comments in the file
    local description=""
    if [[ -f "$monitors_file" ]]; then
        description=$(grep -m 1 "^# .*Setup" "$monitors_file" 2>/dev/null | sed 's/^# //' || echo "Monitor configuration $config")
    else
        description="Monitor configuration $config"
    fi

    echo "$description"
}

# Switch monitor configuration
switch_config() {
    local profile="$1"
    local config="$2"
    local profile_dir="$TWEAKS_ROOT/profiles/$profile/.config/hypr"
    local target_config_dir="$HOME/.config/hypr"
    
    local monitors_src="$profile_dir/monitors-$config.conf"
    local tiling_src="$profile_dir/tiling-$config.conf"
    local monitors_target="$target_config_dir/monitors.conf"
    local tiling_target="$target_config_dir/tiling.conf"
    
    # Verify source files exist
    if [[ ! -f "$monitors_src" ]]; then
        log_error "Monitor config not found: $monitors_src"
        exit 1
    fi

    # Create target directory if it doesn't exist
    mkdir -p "$target_config_dir"
    
    # Remove existing symlinks/files
    [[ -e "$monitors_target" ]] && rm -f "$monitors_target"
    [[ -e "$tiling_target" ]] && rm -f "$tiling_target"

    # Create symlinks
    log_info "Linking monitors-$config.conf → monitors.conf"
    ln -sf "$monitors_src" "$monitors_target"

    # Link tiling config if it exists
    if [[ -f "$tiling_src" ]]; then
        log_info "Linking tiling-$config.conf → tiling.conf"
        ln -sf "$tiling_src" "$tiling_target"
    else
        log_warning "No tiling config found for $config (tiling-$config.conf)"
        # Create empty tiling.conf to avoid errors
        touch "$tiling_target"
    fi

    log_success "Monitor configuration switched to: $config"
}

# Reload Hyprland
reload_hyprland() {
    if command -v hyprctl >/dev/null 2>&1; then
        log_info "Reloading Hyprland configuration..."
        hyprctl reload || true
        log_success "Hyprland configuration reloaded"
    else
        log_warning "hyprctl not found. Please reload Hyprland manually (Super+Shift+R)"
    fi
}

main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        usage
        exit 1
    fi

    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        usage
        exit 0
    fi

    local profile="$1"

    # Validate profile
    if [[ ! -d "$TWEAKS_ROOT/profiles/$profile" ]]; then
        log_error "Profile not found: $profile"
        log_info "Available profiles:"
        find "$TWEAKS_ROOT/profiles" -maxdepth 1 -type d -exec basename {} \; | grep -v "^profiles$" | sort
        exit 1
    fi

    check_dependencies

    log_info "Finding monitor configurations for profile: $profile"

    # Get available configurations
    local configs
    readarray -t configs < <(find_monitor_configs "$profile")

    if [[ ${#configs[@]} -eq 1 ]]; then
        # Only one config, use it directly
        local config="${configs[0]}"
        log_info "Only one configuration found: $config"
        switch_config "$profile" "$config"
    else
        # Multiple configs, let user choose
        log_info "Found ${#configs[@]} monitor configurations"

        # Build menu options with descriptions
        local options=()
        for config in "${configs[@]}"; do
            local description=$(get_config_description "$profile" "$config")
            options+=("$config: $description")
        done

        # Show selection menu
        local selection
        selection=$(printf '%s\n' "${options[@]}" | gum choose --header "Choose monitor configuration:" || true)

        if [[ -z "$selection" ]]; then
            log_info "No configuration selected, exiting"
            exit 0
        fi

        # Extract config name from selection
        local config="${selection%%:*}"

        switch_config "$profile" "$config"
    fi

    reload_hyprland
    log_success "Monitor configuration switch completed!"
}

main "$@"
