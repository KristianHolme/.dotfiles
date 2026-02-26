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

# Require non-empty gum input, return 1 on cancel/empty
require_input() {
	local result
	result=$(gum input "$@") || return 1
	if [[ -z "$result" ]]; then
		return 1
	fi
	echo "$result"
}

########################################
# Per-script argument collection
########################################

collect_args_apply_config() {
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
		ARGS+=("$choice")
	fi
}

collect_args_compress_video() {
	local input quality
	input=$(require_input --header "Input video path (required):" --placeholder "/path/to/video.mp4") || {
		log_error "Input video path is required"
		return 1
	}

	quality=$(gum choose --header "Quality preset:" "medium" "high" "low") || quality="medium"
	ARGS+=("--quality" "$quality" "$input")
}

collect_args_youtube_audio() {
	local url format
	url=$(require_input --header "YouTube URL (required):" --placeholder "https://youtube.com/watch?v=...") || {
		log_error "YouTube URL is required"
		return 1
	}

	format=$(gum choose --header "Audio format:" "mp3" "opus" "m4a") || format="mp3"
	ARGS+=("--format" "$format" "$url")
}

collect_args_firefly_restore() {
	local dir
	dir=$(require_input --header "Backup directory (required):" --placeholder "~/Firefly3/backup/20240120-143022") || {
		log_error "Backup directory is required"
		return 1
	}
	ARGS+=("$dir")
}

collect_args_firefly_backup() {
	local dir
	dir=$(gum input --header "Backup destination (leave empty for default):" --placeholder "~/Firefly3/backup/") || true
	if [[ -n "${dir:-}" ]]; then
		ARGS+=("$dir")
	fi
}

collect_args_setup_zotero() {
	local choice
	choice=$(gum choose --header "Plugin to install:" "All plugins" "better-bibtex" "reading-list") || return 0
	if [[ "$choice" != "All plugins" ]]; then
		ARGS+=("$choice")
	fi
}

# Dispatch argument collection based on script name
collect_args() {
	case "$SELECTED_SCRIPT" in
		dotfiles-apply-config.sh)  collect_args_apply_config ;;
		dotfiles-compress-video.sh) collect_args_compress_video ;;
		dotfiles-youtube-audio.sh) collect_args_youtube_audio ;;
		dotfiles-firefly-restore.sh) collect_args_firefly_restore ;;
		dotfiles-firefly-backup.sh) collect_args_firefly_backup ;;
		dotfiles-setup-zotero.sh)  collect_args_setup_zotero ;;
	esac
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

	# Collect arguments for scripts that need them
	ARGS=()
	collect_args || exit 1

	log_info "Running: $SELECTED_SCRIPT ${ARGS[*]:-}"
	exec "$SCRIPT_DIR/$SELECTED_SCRIPT" "${ARGS[@]+"${ARGS[@]}"}"
}

main "$@"
