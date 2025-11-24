#!/bin/bash
# Test script for idle blur overlay
# Shows the overlay for a few seconds, then hides it
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib-dotfiles.sh"

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
WAIT_SECONDS="${1:-5}"

log_info "Testing idle blur overlay (will show for ${WAIT_SECONDS} seconds)..."

# Show overlay
if ! "$SCRIPT_DIR/dotfiles-show-idle-blur"; then
    log_error "Failed to show overlay"
    exit 1
fi

log_info "Overlay is now visible. Waiting ${WAIT_SECONDS} seconds..."
sleep "$WAIT_SECONDS"

# Hide overlay
if ! "$SCRIPT_DIR/dotfiles-hide-idle-blur"; then
    log_error "Failed to hide overlay"
    exit 1
fi

log_success "Test complete!"
