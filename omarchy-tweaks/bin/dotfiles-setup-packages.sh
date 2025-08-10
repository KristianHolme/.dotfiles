#!/bin/bash
set -Eeuo pipefail

# Omarchy prune/install script
# - Removes selected default webapps and packages
# - Installs requested packages
# - Refreshes application launchers

OMARCHY_BIN="$HOME/.local/share/omarchy/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

log() { echo -e "[omarchy-tweaks] $*"; }

ensure_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1"
        exit 1
    }
}

remove_webapp() {
    local name="$1"
    if [[ -f "$DESKTOP_DIR/$name.desktop" ]]; then
        log "Removing web app: $name"
        "$OMARCHY_BIN/omarchy-webapp-remove" "$name" || true
    else
        log "Skip web app (not found): $name"
    fi
}

pkg_installed() { yay -Qi "$1" >/dev/null 2>&1; }

remove_pkg() {
    local pkg="$1"
    if pkg_installed "$pkg"; then
        log "Removing package: $pkg"
        yay -Rns --noconfirm "$pkg" || true
    else
        log "Skip package (not installed): $pkg"
    fi
}

install_pkg() {
    local pkg="$1"
    if pkg_installed "$pkg"; then
        log "Already installed: $pkg"
    else
        log "Installing package: $pkg"
        yay -Sy --noconfirm "$pkg"
    fi
}

install_via_curl() {
    local name="$1"
    local check_cmd="$2"
    local url="$3"
    local post_install_cmd="${4:-}"

    if command -v "$check_cmd" >/dev/null 2>&1; then
        log "$name already installed; skipping installer"
    else
        log "Installing $name"
        curl -fsSL "$url" | bash
        if [[ -n "$post_install_cmd" ]]; then
            eval "$post_install_cmd"
        fi
    fi
}

main() {
    ensure_cmd yay

    # 1) Remove webapps
    remove_webapp "HEY"
    remove_webapp "Basecamp"
    remove_webapp "WhatsApp"
    remove_webapp "Google Photos"
    remove_webapp "ChatGPT"
    remove_webapp "Figma"

    # 2) Remove packages
    remove_pkg 1password-beta || true
    remove_pkg 1password-cli || true
    #remove_pkg chromium || true
    #remove_pkg typora || true

    # 3) Install packages
    install_pkg zotero-bin
    install_pkg cursor-bin
    install_pkg rsync
    install_pkg discord
    install_pkg starship
    install_pkg stow
    install_pkg bitwarden

    # Install tools via curl installers
    install_via_curl "Julia (juliaup)" "juliaup" "https://install.julialang.org" "source ~/.bashrc && ~/.dotfiles/omarchy-tweaks/bin/julia-setup.jl"
    install_via_curl "cursor-cli" "cursor-agent" "https://cursor.com/install"

    # 4) Refresh desktop database (user apps)
    update-desktop-database ~/.local/share/applications/ || true

    log "Done."
}

main "$@"
