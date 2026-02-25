#!/usr/bin/env bash
#
# Interactive TUI menu for dotfiles scripts.
# Requires: gum (https://github.com/charmbracelet/gum)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

ensure_cmd "gum"

is_arch() {
	[[ -f /etc/os-release ]] && grep -qi 'arch' /etc/os-release
}

# Script registry: "display_label|filename|category"
# Categories: local (Arch-only), replica (server-only), universal (any)
ENTRIES=(
	# Configuration
	"Apply Config (GNU Stow)|dotfiles-apply-config.sh|local"
	"Setup Packages|dotfiles-setup-packages.sh|local"
	"Setup Replica Tools|dotfiles-setup-replica.sh|replica"
	"Apply Replica Config|dotfiles-apply-replica.sh|replica"
	# Development
	"Julia Package Setup|julia-setup.jl|universal"
	"LaTeX Project Init|dotfiles-latex-init.sh|universal"
	"Setup Zotero Extension|dotfiles-setup-zotero.sh|universal"
	# Remote & SSH
	"Setup SSH Keys|dotfiles-setup-ssh.sh|universal"
	"SSH + tmux Connect|dotfiles-ssh-tmux.sh|universal"
	"Rsync Remote Dirs|dotfiles-rsync-ssh.sh|universal"
	# Media
	"Compress Video|dotfiles-compress-video.sh|universal"
	"YouTube Audio Download|dotfiles-youtube-audio.sh|universal"
	# Backup
	"Firefly III Backup|dotfiles-firefly-backup.sh|universal"
	"Firefly III Restore|dotfiles-firefly-restore.sh|universal"
	# System
	"Fix Browser Audio|dotfiles-fix-browser-audio.sh|local"
	"Power Suspend Config|dotfiles-power-suspend.sh|local"
	# Help
	"Help (README)|dotfiles-help.sh|universal"
)

# Globals populated by resolve_entry
SELECTED_SCRIPT=""
SELECTED_CATEGORY=""

category_tag() {
	case "$1" in
		local)   echo "[Arch]  " ;;
		replica) echo "[Server]" ;;
		*)       echo "        " ;;
	esac
}

build_labels() {
	for entry in "${ENTRIES[@]}"; do
		IFS='|' read -r name _ category <<< "$entry"
		printf '%s %s\n' "$(category_tag "$category")" "$name"
	done
}

resolve_entry() {
	local chosen="$1"
	for entry in "${ENTRIES[@]}"; do
		IFS='|' read -r name script category <<< "$entry"
		local label
		label="$(printf '%s %s' "$(category_tag "$category")" "$name")"
		if [[ "$label" == "$chosen" ]]; then
			SELECTED_SCRIPT="$script"
			SELECTED_CATEGORY="$category"
			return 0
		fi
	done
	log_error "Could not resolve selection: $chosen"
	return 1
}

select_profile() {
	local repo_root
	repo_root="$(realpath "$SCRIPT_DIR/..")"
	local profiles=("(default only)")

	for dir in "$repo_root"/*/; do
		local name
		name=$(basename "$dir")
		[[ "$name" == "default" || "$name" == "bin" || "$name" == "templates" ]] && continue
		[[ -d "$dir" ]] && profiles+=("$name")
	done

	if [[ ${#profiles[@]} -le 1 ]]; then
		return 0
	fi

	local choice
	choice=$(printf '%s\n' "${profiles[@]}" | gum choose --header "Select profile:") || return 0

	if [[ "$choice" != "(default only)" ]]; then
		echo "$choice"
	fi
}

main() {
	gum style \
		--border rounded \
		--border-foreground 63 \
		--padding "0 2" \
		--margin "1 0" \
		"Dotfiles Menu"

	local choice
	choice=$(build_labels | gum filter \
		--placeholder "Type to filter..." \
		--height 20 \
		--indicator ">") || exit 0

	resolve_entry "$choice"

	# OS-based warnings
	if is_arch; then
		if [[ "$SELECTED_CATEGORY" == "replica" ]]; then
			gum confirm \
				"$(gum style --foreground 208 'You are on Arch Linux. This is a replica/server script.')" \
				--affirmative "Run anyway" --negative "Cancel" || exit 0
		fi
	else
		if [[ "$SELECTED_CATEGORY" == "local" ]]; then
			gum confirm \
				"$(gum style --foreground 208 'You are not on Arch Linux. This script is designed for Arch systems.')" \
				--affirmative "Run anyway" --negative "Cancel" || exit 0
		fi
	fi

	# Profile selection for apply-config
	local args=()
	if [[ "$SELECTED_SCRIPT" == "dotfiles-apply-config.sh" ]]; then
		local profile
		profile=$(select_profile) || true
		if [[ -n "${profile:-}" ]]; then
			args+=("$profile")
		fi
	fi

	log_info "Running: $SELECTED_SCRIPT ${args[*]:-}"
	exec "$SCRIPT_DIR/$SELECTED_SCRIPT" "${args[@]+"${args[@]}"}"
}

main "$@"
