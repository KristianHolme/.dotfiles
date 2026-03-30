#!/usr/bin/env bash
#
# Migrate the dotfiles repo from ~/.dotfiles to ~/dotfiles using GNU Stow:
# unstow from the old tree, copy the repo, leave ~/.dotfiles in place.
#
# Pass-through: everything after -- is appended to every stow (unstow) call,
# e.g.  dotfiles-migrate-to-dotfiles.sh -- --simulate -v
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib-dotfiles.sh"

usage() {
	cat <<EOF
Usage: $0 [-h|--help] [-- STOW_ARGS...]

Unstow packages from \$HOME/.dotfiles, copy that directory to \$HOME/dotfiles
(cp -a), and keep \$HOME/.dotfiles. Then run apply-config from the new path.

Arguments after -- are passed to every unstow invocation (GNU Stow). Examples:
  $0 -- --simulate -v     # dry-run unstow only (no cp, no filesystem changes)
  $0 -- -n

Simulate uses -n / --no / --simulate (see stow --help). When simulating, the
copy step is skipped and \$HOME/dotfiles may already exist.

EOF
}

stow_extra=()
while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	--)
		shift
		stow_extra=("$@")
		break
		;;
	--*)
		log_error "Unknown option: $1"
		usage >&2
		exit 1
		;;
	*)
		log_error "Unexpected argument: $1 (use -- before stow flags)"
		usage >&2
		exit 1
		;;
	esac
done

is_simulate=0
for __a in "${stow_extra[@]}"; do
	case "$__a" in
	-n | --no | --simulate)
		is_simulate=1
		;;
	esac
done

OLD="${HOME}/.dotfiles"
NEW="${HOME}/dotfiles"

[[ -d "$OLD" ]] || {
	log_error "Not a directory: $OLD"
	exit 1
}

if [[ "$is_simulate" -eq 0 ]]; then
	if [[ -e "$NEW" ]]; then
		log_error "Already exists (remove or rename first): $NEW"
		exit 1
	fi
fi

ensure_cmd stow

log_info "Unstowing from $OLD into $HOME (target)..."
if [[ "${#stow_extra[@]}" -gt 0 ]]; then
	log_info "Extra stow args: ${stow_extra[*]}"
fi

stow -d "$OLD" -t "$HOME" -D default --dotfiles "${stow_extra[@]}" 2>/dev/null || true

log_info "Unstowing profile packages (if any)..."
shopt -s nullglob
for pkg_dir in "$OLD"/*; do
	[[ -d "$pkg_dir" ]] || continue
	pkg_name=$(basename "$pkg_dir")
	if [[ "$pkg_name" == "default" || "$pkg_name" == "bin" || "$pkg_name" == "templates" ]]; then
		continue
	fi
	stow -d "$OLD" -t "$HOME" -D "$pkg_name" "${stow_extra[@]}" 2>/dev/null || true
done
shopt -u nullglob

if [[ "$is_simulate" -eq 1 ]]; then
	log_success "Simulate-only run finished (stow dry-run; copy was not performed)."
	log_info "Re-run without -n/--simulate/--no in the stow args to perform unstow and copy, e.g.: $0"
	log_info "Then: $NEW/bin/dotfiles-apply-config.sh"
	exit 0
fi

log_info "Copying $OLD -> $NEW (cp -a)..."
cp -a "$OLD" "$NEW"

log_success "Copy complete."
log_info "Next: run apply-config from the new repo so symlinks point at $NEW:"
log_info "  $NEW/bin/dotfiles-apply-config.sh [PROFILE]"
log_info "When satisfied, you may remove the old copy: rm -rf $OLD"
