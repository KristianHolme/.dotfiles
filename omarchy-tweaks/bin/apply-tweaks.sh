#!/bin/bash

# Simple Omarchy Tweaks Application Script
# Copies config files from dotfiles to system locations

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script lives in bin/, configs live one directory up in ../config
CONFIG_SOURCE="$(realpath "$SCRIPT_DIR/../config")"
TARGET_CONFIG="$HOME/.config"
CUSTOM_BASHRC="$(realpath "$SCRIPT_DIR/../.bashrc")"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Apply configs
apply_configs() {
  log_info "Syncing configs from $CONFIG_SOURCE to $TARGET_CONFIG (only existing files)..."

  if ! command -v rsync >/dev/null 2>&1; then
    log_warning "rsync not found. Please install rsync to use this script."
    return 1
  fi

  # Itemize changes for clear logging; --existing ensures we do not create new files
  RSYNC_OPTS=( -a --existing --itemize-changes )

  # Run rsync and capture output to display what changed
  SYNC_OUTPUT=$(rsync "${RSYNC_OPTS[@]}" "$CONFIG_SOURCE/" "$TARGET_CONFIG/" 2>&1 || true)

  if [[ -n "$SYNC_OUTPUT" ]]; then
    echo "$SYNC_OUTPUT" | sed 's/^/[SYNC] /'
    log_success "Applied configuration updates"
  else
    log_info "No matching existing files to update"
  fi
}

# Setup bashrc sourcing
setup_bashrc() {
  log_info "Setting up bashrc sourcing..."
  
  if [[ ! -f "$CUSTOM_BASHRC" ]]; then
    log_warning "Custom bashrc not found at $CUSTOM_BASHRC"
    return 1
  fi
  
  # Check if sourcing line already exists
  SOURCE_LINE="source $CUSTOM_BASHRC"
  if grep -q "^$SOURCE_LINE$" ~/.bashrc 2>/dev/null; then
    log_info "Bashrc sourcing already configured"
    return 0
  fi
  
  # Add sourcing line to ~/.bashrc
  echo "" >> ~/.bashrc
  echo "# Omarchy tweaks custom bashrc" >> ~/.bashrc
  echo "$SOURCE_LINE" >> ~/.bashrc
  log_success "Added bashrc sourcing to ~/.bashrc"
}

# Reload hyprland
reload_hyprland() {
  if command -v hyprctl &> /dev/null; then
    hyprctl reload || true
    log_success "Reloaded Hyprland configuration"
  else
    log_warning "hyprctl not found. Please reload Hyprland manually."
  fi
}

main() {
  log_info "Applying Omarchy tweaks..."
  apply_configs
  setup_bashrc
  reload_hyprland
  log_success "All tweaks applied successfully!"
}

main
exit $?