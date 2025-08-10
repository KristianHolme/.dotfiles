#!/bin/bash
set -Eeuo pipefail

OMARCHY_BIN_PATH="$HOME/.local/share/omarchy/bin"

# Build options once
options=$("$OMARCHY_BIN_PATH/omarchy-powerprofiles-list")
current=$(powerprofilesctl get 2>/dev/null || true)

# Compute preselect index (1-based) within options
pre_index=""
if [[ -n "$current" ]]; then
  pre_index=$(printf '%s\n' "$options" | nl -ba | awk -v c="$current" '$2==c{print $1; exit}') || true
fi

# Show menu with optional preselection
if [[ -n "$pre_index" ]]; then
  selection=$(printf '%s\n' "$options" | walker --dmenu --theme dmenu_250 -p "Power Profile…" -a "$pre_index" || true)
else
  selection=$(printf '%s\n' "$options" | walker --dmenu --theme dmenu_250 -p "Power Profile…" || true)
fi

if [[ -n "$selection" && "$selection" != "CNCLD" ]]; then
  powerprofilesctl set "$selection" || true
fi