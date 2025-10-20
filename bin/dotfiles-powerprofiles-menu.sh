#!/bin/bash
set -Eeuo pipefail

OMARCHY_BIN_PATH="$HOME/.local/share/omarchy/bin"

# Build options once
options=$("$OMARCHY_BIN_PATH/omarchy-powerprofiles-list")
current=$(powerprofilesctl get 2>/dev/null || true)

# Compute preselect index (1-based) within options
pre_index=""
if [[ -n "$current" ]]; then
	pre_index=$(echo -e "$options" | grep -nxF "$current" | cut -d: -f1) || true
fi

# Show menu with optional preselection
if [[ -n "$pre_index" ]]; then
	selection=$(echo -e "$options" | omarchy-launch-walker --dmenu --width 295 --minheight 1 --maxheight 600 -p "Power Profile…" -c "$pre_index" 2>/dev/null || true)
else
	selection=$(echo -e "$options" | omarchy-launch-walker --dmenu --width 295 --minheight 1 --maxheight 600 -p "Power Profile…" 2>/dev/null || true)
fi

if [[ -n "$selection" && "$selection" != "CNCLD" ]]; then
	powerprofilesctl set "$selection" || true
fi
