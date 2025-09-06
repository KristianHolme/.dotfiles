#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

INSTALL_DIR="${1:-"$HOME/.local/bin"}"

install_runic() {
	ensure_cmd curl

	local target_url="https://raw.githubusercontent.com/fredrikekre/Runic.jl/refs/heads/master/bin/runic"
	local target_path="$INSTALL_DIR/runic"

	mkdir -p "$INSTALL_DIR"

	local tmp
	tmp="$(mktemp)"
	trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -f "$t"' RETURN

	log_info "Downloading runic from $target_url"
	curl -fsSL -o "$tmp" "$target_url"

	if [[ -f "$target_path" ]] && cmp -s "$tmp" "$target_path"; then
		log_info "runic already up to date at $target_path"
		return 0
	fi

	install -m 0755 "$tmp" "$target_path"
	log_success "Installed/updated runic -> $target_path"

	if command -v runic >/dev/null 2>&1; then
		local ver
		ver=$(runic --version 2>/dev/null || true)
		if [[ -n "$ver" ]]; then
			log_info "runic version: $ver"
		fi
	fi
}

install_runic
