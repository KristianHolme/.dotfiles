#!/usr/bin/env bash
#
# Migrate the dotfiles repo from ~/.dotfiles to ~/dotfiles using GNU Stow:
# unstow from the old tree, copy the repo, leave ~/.dotfiles in place.
#
# Optional PROFILE matches bin/dotfiles-apply-config.sh (top-level package name).
# Use --dry-run for stow --no --verbose, or -- before extra stow flags.
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib-dotfiles.sh"

usage() {
	cat <<EOF
Usage: $0 [--dry-run] [-h|--help] [PROFILE] [-- STOW_ARGS...]

Unstow packages from \$HOME/.dotfiles, copy that directory to \$HOME/dotfiles
(cp -a), and keep \$HOME/.dotfiles. Then run apply-config from the new path.

  PROFILE     If set, only unstow that profile package. If omitted, unstow all
              profile dirs under the repo root (excluding default, bin, templates).

  --dry-run   Pass --no and --verbose to every stow unstow (no filesystem
              changes; copy step skipped).

Arguments after -- are appended to every unstow invocation. Examples:
  $0 --dry-run
  $0 bengal --dry-run
  $0 -- --simulate -v
  $0 kaspi -- -v

EOF
}

dry_run_flag=0
profile=""
stow_extra=()
positional=()

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	--dry-run)
		dry_run_flag=1
		shift
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
		positional+=("$1")
		shift
		;;
	esac
done

if [[ "${#positional[@]}" -gt 1 ]]; then
	log_error "Too many arguments (expected optional PROFILE only)."
	usage >&2
	exit 1
fi
profile="${positional[0]:-}"

dry_run_stow=()
if [[ "$dry_run_flag" -eq 1 ]]; then
	dry_run_stow=(--no --verbose)
fi

stow_all=("${dry_run_stow[@]}" "${stow_extra[@]}")

is_simulate=0
if [[ "$dry_run_flag" -eq 1 ]]; then
	is_simulate=1
fi
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

if [[ -n "$profile" ]] && [[ ! -d "$OLD/$profile" ]]; then
	log_error "Profile package not found: $OLD/$profile"
	exit 1
fi

if [[ "$is_simulate" -eq 0 ]]; then
	if [[ -e "$NEW" ]]; then
		log_error "Already exists (remove or rename first): $NEW"
		exit 1
	fi
fi

ensure_cmd stow

log_info "Unstowing from $OLD into $HOME (target)..."
if [[ "${#stow_all[@]}" -gt 0 ]]; then
	log_info "Stow args: ${stow_all[*]}"
fi
if [[ -n "$profile" ]]; then
	log_info "Profile: $profile (only this profile package will be unstowed)"
else
	log_info "Profile: (all profile packages under repo root)"
fi

unstow_profiles() {
	if [[ -n "$profile" ]]; then
		log_info "Unstowing profile package: $profile"
		stow -d "$OLD" -t "$HOME" -D "$profile" --dotfiles "${stow_all[@]}" || true
		return 0
	fi
	log_info "Unstowing all profile packages..."
	shopt -s nullglob
	for pkg_dir in "$OLD"/*; do
		[[ -d "$pkg_dir" ]] || continue
		pkg_name=$(basename "$pkg_dir")
		if [[ "$pkg_name" == "default" || "$pkg_name" == "bin" || "$pkg_name" == "templates" ]]; then
			continue
		fi
		log_info "Unstowing profile package: $pkg_name"
		stow -d "$OLD" -t "$HOME" -D "$pkg_name" --dotfiles "${stow_all[@]}" || true
	done
	shopt -u nullglob
}

unstow_profiles

log_info "Unstowing default package..."
stow -d "$OLD" -t "$HOME" -D default --dotfiles "${stow_all[@]}" || true

if [[ "$is_simulate" -eq 1 ]]; then
	log_success "Simulate-only run finished (stow dry-run; copy was not performed)."
	log_info "Re-run without --dry-run and without -n/--simulate in stow args to perform unstow and copy, e.g.: $0${profile:+ $profile}"
	log_info "Then: $NEW/bin/dotfiles-apply-config.sh${profile:+ $profile}"
	exit 0
fi

log_info "Copying $OLD -> $NEW (cp -a)..."
cp -a "$OLD" "$NEW"

log_success "Copy complete."
log_info "Next: run apply-config from the new repo so symlinks point at $NEW:"
if [[ -n "$profile" ]]; then
	log_info "  $NEW/bin/dotfiles-apply-config.sh $profile"
else
	log_info "  $NEW/bin/dotfiles-apply-config.sh [PROFILE]"
fi
log_info "When satisfied, you may remove the old copy: rm -rf $OLD"
