#!/bin/bash
set -Eeuo pipefail

# Robust Zotero Better BibTeX setup script
# Downloads and installs Better BibTeX extension for Zotero

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

# Define paths
PROFILE_DIR="$HOME/Zotero"
EXTENSIONS_DIR="$PROFILE_DIR/extensions"
PREFS_FILE="$PROFILE_DIR/prefs.js"
GITHUB_API_URL="https://api.github.com/repos/retorquere/zotero-better-bibtex/releases/latest"
XPI_FILE="zotero-better-bibtex.xpi"
RENAMED_XPI="better-bibtex@iris-advies.com.xpi"

check_better_bibtex_installed() {
    # Check if Better BibTeX is already installed
    # Look for the extension in Zotero's extensions directory
    if [[ -d "$EXTENSIONS_DIR" ]]; then
        if find "$EXTENSIONS_DIR" -name "*better-bibtex*" -o -name "*@iris-advies.com*" | grep -q .; then
            return 0  # Found
        fi
    fi
    
    # Check if the XPI file was already downloaded
    if ls "$HOME/Downloads/"*better-bibtex*.xpi >/dev/null 2>&1; then
        return 0  # Downloaded but maybe not installed yet
    fi
    
    return 1  # Not found
}

main() {
    log_info "Setting up Zotero Better BibTeX extension..."

    # Check if Zotero is installed
    if ! command -v zotero >/dev/null 2>&1; then
        log_error "Zotero not found in PATH. Please install Zotero first."
        return 1
    fi

    # Check if Better BibTeX is already installed or downloaded
    if check_better_bibtex_installed; then
        log_success "Better BibTeX extension already downloaded/installed. Skipping download."
        return 0
    fi

    # Get the latest release download URL
    log_info "Fetching latest Better BibTeX release information..."
    local xpi_url
    xpi_url=$(curl -fsSL "$GITHUB_API_URL" | grep -o '"browser_download_url": *"[^"]*\.xpi"' | cut -d'"' -f4)

    if [[ -z "$xpi_url" ]]; then
        log_error "Failed to find XPI download URL from GitHub API"
        log_error "API response may have changed or network issue occurred"
        return 1
    fi

    log_info "Found latest release: $(basename "$xpi_url")"

    # Download the .xpi file to Downloads
    local download_path="$HOME/Downloads/$(basename "$xpi_url")"
    log_info "Downloading Better BibTeX extension to $download_path..."
    if ! curl -fsSL -o "$download_path" "$xpi_url"; then
        log_error "Failed to download Better BibTeX extension from $xpi_url"
        return 1
    fi

    # Verify download
    if [[ ! -f "$download_path" || ! -s "$download_path" ]]; then
        log_error "Downloaded file is missing or empty"
        [[ -f "$download_path" ]] && rm -f "$download_path"
        return 1
    fi

    log_success "Better BibTeX extension downloaded successfully!"
    log_info "To complete installation:"
    log_info "1. Open Zotero"
    log_info "2. Go to Tools → Plugins"
    log_info "3. Click the gear icon and select 'Install Plugin From File...'"
    log_info "4. Choose: $download_path"
    log_info "5. Click 'Install' and restart Zotero"
    log_warning "Automatic installation via command line is not supported by Zotero."
    log_warning "Manual installation through the GUI is required for proper extension registration."
}

main "$@"
