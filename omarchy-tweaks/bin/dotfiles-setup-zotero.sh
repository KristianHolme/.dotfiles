#!/bin/bash
set -Eeuo pipefail

# Robust Zotero Better BibTeX setup script
# Downloads and installs Better BibTeX extension for Zotero

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

# Define paths
PROFILE_DIR="$HOME/Zotero"
EXTENSIONS_DIR="$PROFILE_DIR/extensions"
PREFS_FILE="$PROFILE_DIR/prefs.js"
GITHUB_API_URL="https://api.github.com/repos/retorquere/zotero-better-bibtex/releases/latest"
XPI_FILE="zotero-better-bibtex.xpi"
RENAMED_XPI="better-bibtex@iris-advies.com.xpi"

main() {
    log_info "Setting up Zotero Better BibTeX extension..."

    # Check if Zotero is installed
    if ! command -v zotero >/dev/null 2>&1; then
        log_error "Zotero not found in PATH. Please install Zotero first."
        return 1
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
    log_info "2. Go to Tools → Add-ons"
    log_info "3. Click the gear icon and select 'Install Add-on From File...'"
    log_info "4. Choose: $download_path"
    log_info "5. Click 'Install' and restart Zotero"
    log_warning "Automatic installation via command line is not supported by Zotero."
    log_warning "Manual installation through the GUI is required for proper extension registration."
}

main "$@"
