#!/bin/bash

# Simple Omarchy Tweaks Application Script
# Copies config files from dotfiles to system locations

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

# Script lives in bin/, configs live one directory up in ../config
CONFIG_SOURCE="$(realpath "$SCRIPT_DIR/../config")"
TARGET_CONFIG="$HOME/.config"
TARGET_HOME="$HOME"

# Colors for output
# Simple function to unstow any existing profile packages at repo root
unstow_all_profiles() {
    local packages_dir="$1"
    local target_dir="$2"
    log_info "Unstowing any existing profiles..."
    shopt -s nullglob
    for pkg_dir in "$packages_dir"/*; do
        [[ -d "$pkg_dir" ]] || continue
        local pkg_name
        pkg_name=$(basename "$pkg_dir")
        # Skip non-profile packages
        if [[ "$pkg_name" == "default" || "$pkg_name" == "bin" ]]; then
            continue
        fi
        stow -d "$packages_dir" -t "$target_dir" -D "$pkg_name" 2>/dev/null || true
    done
    shopt -u nullglob
}

stow_with_conflict_detection() {
    local packages_dir="$1" # e.g. /path/to/dotfiles
    local package_name="$2" # e.g. "dot-config" or "home"
    local target_dir="$3"   # e.g. ~/.config or ~
    local description="$4"  # e.g. "config files" or "home files"
    shift 4
    # Any remaining args are extra stow flags (e.g., --override, etc.)
    local extra_flags=("$@")

    # Check if package exists
    [[ -d "$packages_dir/$package_name" ]] || return 0

    log_info "Checking for conflicts in $description..."

    # Dry run to detect conflicts
    set +e
    local dry_run_output
    # Use -S for stow (not -R) when we have --override to avoid restow conflicts
    local stow_op="-R"
    for __flag in "${extra_flags[@]}"; do
        if [[ "$__flag" == --override* ]]; then
            stow_op="-S"
            break
        fi
    done
    dry_run_output=$(stow -n -d "$packages_dir" -t "$target_dir" $stow_op -v --dotfiles "${extra_flags[@]}" "$package_name" 2>&1)
    local dry_run_status=$?
    set -e

    if [[ $dry_run_status -eq 0 ]]; then
        # No conflicts, proceed with normal stow
        log_info "No conflicts detected, proceeding with $description symlinks..."
        stow -d "$packages_dir" -t "$target_dir" $stow_op -v --dotfiles "${extra_flags[@]}" "$package_name"
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
            --header "How should conflicts be resolved for $description?") || choice="Abort (keep existing files)"

        case "$choice" in
        "Adopt conflicting files"*)
            log_info "Adopting conflicting files for $description..."
            stow -d "$packages_dir" -t "$target_dir" $stow_op -v --dotfiles --adopt "${extra_flags[@]}" "$package_name" || {
                log_warning "Adopt failed; attempting plain stow with override..."
                stow -d "$packages_dir" -t "$target_dir" $stow_op -v --dotfiles "${extra_flags[@]}" "$package_name"
            }
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

    ensure_cmd "stow"

    # Packages directory (repo root of omarchy-tweaks)
    PACKAGES_DIR="$(realpath "$SCRIPT_DIR/..")"
    # Optional profile argument (e.g. "work" -> config-work)
    local profile="${1:-}"

    # Apply base default package (includes dotfiles under dot-* inside it)
    stow_with_conflict_detection "$PACKAGES_DIR" "default" "$TARGET_HOME" "default files" --override='.*'

    # If a profile was provided, handle profile switching via top-level packages named by profile
    if [[ -n "$profile" ]]; then
        local profile_pkg_name="$profile"
        if [[ -d "$PACKAGES_DIR/$profile_pkg_name" ]]; then
            # First, unstow any existing profile overlays
            unstow_all_profiles "$PACKAGES_DIR" "$TARGET_HOME"

            # Then overlay the selected profile using override to replace base-owned files
            stow_with_conflict_detection "$PACKAGES_DIR" "$profile_pkg_name" "$TARGET_HOME" "profile files" --override='.*'
        else
            log_info "No profile package '$profile_pkg_name' found; skipping profile overlay"
        fi
    fi

    log_success "Configuration linking completed"
}

# Removed bashrc manual sourcing; handled by Stow 'home' package

# Sync all Claude skills into dotfiles if they exist and differ
sync_claude_skills() {
    local claude_skills_dir="$HOME/.claude/skills"
    local packages_dir
    local dotfiles_skills_dir
    packages_dir="$(realpath "$SCRIPT_DIR/..")"
    dotfiles_skills_dir="$packages_dir/default/dot-cursor/skills"

    if [[ ! -d "$claude_skills_dir" ]]; then
        return 0
    fi

    mkdir -p "$dotfiles_skills_dir"

    shopt -s nullglob
    for skill_dir in "$claude_skills_dir"/*; do
        [[ -d "$skill_dir" ]] || continue

        local skill_name
        local target_dir
        skill_name="$(basename "$skill_dir")"
        target_dir="$dotfiles_skills_dir/$skill_name"

        if [[ -d "$target_dir" ]] && diff -qr "$skill_dir" "$target_dir" >/dev/null 2>&1; then
            continue
        fi

        if [[ -d "$target_dir" ]]; then
            log_info "Updating Claude skill '$skill_name' in dotfiles..."
        else
            log_info "Copying Claude skill '$skill_name' to dotfiles..."
            mkdir -p "$target_dir"
        fi

        if command -v rsync >/dev/null 2>&1; then
            rsync -a --delete "$skill_dir"/ "$target_dir"/
        else
            rm -rf "$target_dir"
            cp -a "$skill_dir" "$target_dir"
        fi

        log_success "Synced Claude skill '$skill_name'"
    done
    shopt -u nullglob
}

# Check for blank monitors (0x0 resolution) and fix them
check_and_fix_monitors() {
    if ! command -v hyprctl &>/dev/null || ! command -v jq &>/dev/null; then
        return 0
    fi

    local monitors_json
    monitors_json=$(hyprctl monitors -j 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        return 0
    fi

    # Check for monitors with 0x0 resolution
    local blank_monitors
    blank_monitors=$(echo "$monitors_json" | jq -r '.[] | select(.width == 0 or .height == 0) | .name' 2>/dev/null)

    if [[ -n "$blank_monitors" ]]; then
        log_warning "Detected blank monitors (0x0 resolution): $(echo "$blank_monitors" | tr '\n' ' ')"
        log_info "Attempting to refresh monitors..."

        # Try safe refresh methods first
        # Turn DPMS off and on for each blank monitor
        while IFS= read -r monitor; do
            [[ -z "$monitor" ]] && continue
            hyprctl dispatch dpms off "$monitor" >/dev/null 2>&1
            sleep 0.2
            hyprctl dispatch dpms on "$monitor" >/dev/null 2>&1
        done <<<"$blank_monitors"

        sleep 0.5

        # Check if still blank
        monitors_json=$(hyprctl monitors -j 2>/dev/null)
        blank_monitors=$(echo "$monitors_json" | jq -r '.[] | select(.width == 0 or .height == 0) | .name' 2>/dev/null)

        if [[ -n "$blank_monitors" ]]; then
            log_warning "Some monitors are still blank after refresh"
            log_info "You may need to manually restart Hyprland (Super+Esc -> Relaunch) or reconnect monitors"
            return 1
        else
            log_success "Monitors refreshed successfully"
        fi
    fi
}

# Reload hyprland
reload_hyprland() {
    if command -v hyprctl &>/dev/null; then
        # When switching profiles, workspace bindings to non-existent monitors can cause issues.
        # Hyprland should handle this gracefully, but we ensure a clean reload.
        log_info "Reloading Hyprland configuration..."

        # Reload configuration - capture both stdout and stderr to check for issues
        local reload_output
        reload_output=$(hyprctl reload 2>&1)
        local reload_status=$?

        if [[ $reload_status -eq 0 ]]; then
            # Check for warnings about workspace/monitor bindings in the output
            # These are often non-fatal when switching profiles
            if echo "$reload_output" | grep -qiE "(workspace.*monitor|monitor.*not found|monitor.*does not exist)"; then
                log_info "Note: Some workspace bindings reference monitors that may not be available"
                log_info "This is normal when switching profiles - workspaces will use available monitors"
            fi

            # Wait a moment for monitors to initialize, then check for blank monitors
            sleep 0.5
            check_and_fix_monitors || true

            # Restart waybar after monitor configuration changes to ensure it appears on all monitors
            # Wait a bit longer for monitors to be fully initialized before restarting waybar
            # Waybar queries monitors at startup, so we need to ensure all monitors are ready
            if command -v omarchy-restart-waybar &>/dev/null; then
                log_info "Restarting waybar to ensure it appears on all monitors..."
                # Wait longer to ensure monitors are fully initialized
                sleep 2
                omarchy-restart-waybar >/dev/null 2>&1 || true
                # Give waybar time to detect all monitors
                sleep 1
            fi

            log_success "Reloaded Hyprland configuration"
        else
            # Check if it's warnings about missing monitors (common when switching profiles)
            if echo "$reload_output" | grep -qiE "(workspace|monitor)" && echo "$reload_output" | grep -qiE "(not found|does not exist|ignored|warning)"; then
                log_warning "Hyprland reloaded with warnings about workspace/monitor bindings"
                log_info "This is normal when switching profiles with different monitor setups"

                # Still check for blank monitors
                sleep 0.5
                check_and_fix_monitors || true

                # Restart waybar after monitor configuration changes
                # Wait a bit longer for monitors to be fully initialized before restarting waybar
                # Waybar queries monitors at startup, so we need to ensure all monitors are ready
                if command -v omarchy-restart-waybar &>/dev/null; then
                    log_info "Restarting waybar to ensure it appears on all monitors..."
                    # Wait longer to ensure monitors are fully initialized
                    sleep 2
                    omarchy-restart-waybar >/dev/null 2>&1 || true
                    # Give waybar time to detect all monitors
                    sleep 1
                fi

                log_success "Configuration applied successfully"
            else
                log_warning "Hyprland reload failed:"
                echo "$reload_output" | head -10
                log_info "Tip: If workspace bindings are causing issues, try moving workspaces manually"
                return 1
            fi
        fi
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

    # Sync Claude skills before applying configs
    sync_claude_skills

    apply_configs "$profile_arg"
    reload_hyprland
    log_success "All tweaks applied successfully!"
}

main "$@"
exit $?
