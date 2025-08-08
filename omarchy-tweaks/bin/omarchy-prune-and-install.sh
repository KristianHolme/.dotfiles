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
  remove_pkg 1password || true
  remove_pkg 1password-cli || true
  #remove_pkg chromium || true
  #remove_pkg typora || true

  # 3) Install packages
  install_pkg zotero-bin
  install_pkg cursor-bin
  install_pkg rsync
  install_pkg discord
  install_pkg starship

  #Install julia and add basic packages to base env
  curl -fsSL https://install.julialang.org | sh
  ~/.dotfiles/omarchy-tweaks/bin/julia-setup.jl

  # 4) Refresh desktop database (user apps)
  update-desktop-database ~/.local/share/applications/ || true

  log "Done."
}

main "$@"
