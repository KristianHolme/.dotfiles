#!/bin/bash
# Build script for idle blur overlay
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib-dotfiles.sh"

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
SOURCE_FILE="$SCRIPT_DIR/dotfiles-idle-blur-overlay.c"
OUTPUT_FILE="$SCRIPT_DIR/dotfiles-idle-blur-overlay"
PROTOCOL_HEADER="$SCRIPT_DIR/wlr-layer-shell-unstable-v1-client-protocol.h"
PROTOCOL_CODE="$SCRIPT_DIR/wlr-layer-shell-unstable-v1-client-protocol.c"
XDG_SHELL_HEADER="$SCRIPT_DIR/xdg-shell-client-protocol.h"
XDG_SHELL_CODE="$SCRIPT_DIR/xdg-shell-client-protocol.c"

# Check for required tools
if ! command -v gcc >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then
    log_error "No C compiler found (gcc or clang required)"
    exit 1
fi

CC="${CC:-$(command -v gcc || command -v clang)}"

# Check for wayland-scanner (try wayland-scanner first, then hyprwayland-scanner)
WAYLAND_SCANNER="${WAYLAND_SCANNER:-$(command -v wayland-scanner 2>/dev/null || command -v hyprwayland-scanner 2>/dev/null || true)}"

# Find protocol XML file
PROTOCOL_DIRS=(
    "/usr/share/wlr-protocols"  # wlr-protocols package
    "/usr/local/share/wlr-protocols"
    "/usr/share/wayland-protocols/unstable/wlr-layer-shell"  # Alternative location
    "/usr/local/share/wayland-protocols/unstable/wlr-layer-shell"
    "$HOME/.local/share/wayland-protocols/unstable/wlr-layer-shell"
)

PROTOCOL_XML=""
TMP_XML=""
for dir in "${PROTOCOL_DIRS[@]}"; do
    if [[ -f "$dir/wlr-layer-shell-unstable-v1.xml" ]]; then
        PROTOCOL_XML="$dir/wlr-layer-shell-unstable-v1.xml"
        break
    fi
done

# If not found locally, try to download from wlroots repository
if [[ -z "$PROTOCOL_XML" ]]; then
    log_info "Protocol XML not found locally, attempting to download from wlroots repository..."
    TMP_XML="$(mktemp)"
    if curl -fsSL "https://raw.githubusercontent.com/swaywm/wlr-protocols/master/unstable/wlr-layer-shell-unstable-v1.xml" -o "$TMP_XML" 2>/dev/null; then
        PROTOCOL_XML="$TMP_XML"
        log_info "Downloaded protocol XML from wlroots repository"
    else
        rm -f "$TMP_XML"
        TMP_XML=""
        log_warning "Failed to download protocol XML"
    fi
fi

# Find xdg-shell protocol XML (required dependency)
XDG_SHELL_XML=""
XDG_SHELL_PATHS=(
    "/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml"
    "/usr/local/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml"
)
for path in "${XDG_SHELL_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        XDG_SHELL_XML="$path"
        break
    fi
done

# Generate wlr-layer-shell protocol header and code if needed
if [[ ! -f "$PROTOCOL_HEADER" ]] || [[ ! -f "$PROTOCOL_CODE" ]]; then
    if [[ -n "$WAYLAND_SCANNER" ]] && [[ -n "$PROTOCOL_XML" ]]; then
        log_info "Generating wlr-layer-shell protocol files from $PROTOCOL_XML"
        "$WAYLAND_SCANNER" client-header "$PROTOCOL_XML" "$PROTOCOL_HEADER"
        "$WAYLAND_SCANNER" private-code "$PROTOCOL_XML" "$PROTOCOL_CODE"
        # Clean up temporary downloaded file
        if [[ "$PROTOCOL_XML" == "$TMP_XML" ]]; then
            rm -f "$TMP_XML"
            TMP_XML=""
        fi
    else
        log_error "Protocol files not found and cannot generate them"
        if [[ -z "$WAYLAND_SCANNER" ]]; then
            log_error "wayland-scanner or hyprwayland-scanner not found"
            log_error "Install wayland package (provides wayland-scanner) or hyprwayland-scanner"
        fi
        if [[ -z "$PROTOCOL_XML" ]]; then
            log_error "wlr-layer-shell-unstable-v1.xml not found"
            log_error "Install wlr-protocols package, or the file will be downloaded automatically"
        fi
        exit 1
    fi
else
    log_info "wlr-layer-shell protocol files already exist: $PROTOCOL_HEADER, $PROTOCOL_CODE"
fi

# Generate xdg-shell protocol files if needed (dependency of wlr-layer-shell)
if [[ ! -f "$XDG_SHELL_HEADER" ]] || [[ ! -f "$XDG_SHELL_CODE" ]]; then
    if [[ -n "$WAYLAND_SCANNER" ]] && [[ -n "$XDG_SHELL_XML" ]]; then
        log_info "Generating xdg-shell protocol files from $XDG_SHELL_XML"
        "$WAYLAND_SCANNER" client-header "$XDG_SHELL_XML" "$XDG_SHELL_HEADER"
        "$WAYLAND_SCANNER" private-code "$XDG_SHELL_XML" "$XDG_SHELL_CODE"
    else
        log_warning "xdg-shell protocol files not found, but may be needed"
        log_warning "Install wayland-protocols package if build fails"
    fi
else
    log_info "xdg-shell protocol files already exist: $XDG_SHELL_HEADER, $XDG_SHELL_CODE"
fi

# Clean up temporary downloaded file if we had one
if [[ -n "$TMP_XML" ]] && [[ -f "$TMP_XML" ]]; then
    rm -f "$TMP_XML"
fi

# Check for wayland-client library
if ! pkg-config --exists wayland-client 2>/dev/null; then
    log_error "wayland-client not found (install libwayland-dev or wayland-devel)"
    exit 1
fi

# Compile
log_info "Compiling $SOURCE_FILE -> $OUTPUT_FILE"
SOURCES=("$SOURCE_FILE" "$PROTOCOL_CODE")
if [[ -f "$XDG_SHELL_CODE" ]]; then
    SOURCES+=("$XDG_SHELL_CODE")
fi
"$CC" -o "$OUTPUT_FILE" "${SOURCES[@]}" \
    $(pkg-config --cflags --libs wayland-client) \
    -Wall -Wextra -O2

# Make executable
chmod +x "$OUTPUT_FILE"

log_success "Build complete: $OUTPUT_FILE"
