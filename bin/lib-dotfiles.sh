#!/usr/bin/env bash
#
# Common library for dotfiles scripts
# Should be sourced by other scripts:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib-dotfiles.sh"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Centralized logging functions
# Usage: log_info "This is an info message"
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Standardized dependency check
# Usage: ensure_cmd "git" "curl"
ensure_cmd() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || {
            log_error "Missing required command: $cmd"
            exit 1
        }
    done
}

# Creates a symlink to a target file or directory, backing up the target if it exists and is not already a symlink.
# This function is idempotent.
# Usage: create_symlink_with_backup "/path/to/source" "/path/to/target" "Description for logging"
create_symlink_with_backup() {
    local source_path="$1"
    local target_path="$2"
    local description="$3"

    # Check if source exists
    if [[ ! -e "$source_path" ]]; then
        log_warning "Source for $description not found: $source_path; skipping"
        return 0
    fi

    # Check if already correctly symlinked
    if [[ -L "$target_path" ]]; then
        local current_target
        current_target="$(readlink "$target_path")"
        if [[ "$current_target" == "$source_path" ]] || [[ "$(realpath "$target_path" 2>/dev/null)" == "$(realpath "$source_path" 2>/dev/null)" ]]; then
            log_info "$description already symlinked correctly; skipping"
            return 0
        fi
        
        # Different symlink exists, remove it
        log_warning "Removing existing incorrect symlink: $target_path -> $current_target"
        rm "$target_path"
    elif [[ -e "$target_path" ]]; then
        # File/directory exists but isn't a symlink, backup it
        local backup_path="$target_path.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backing up existing $description: $target_path -> $backup_path"
        mv "$target_path" "$backup_path"
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$target_path")"

    # Create the symlink
    log_info "Creating symlink for $description: $target_path -> $source_path"
    ln -sf "$source_path" "$target_path"
}

clone_or_update_omarchy() {
    local omarchy_dir="${1:-$HOME/.local/share/omarchy}"
    local omarchy_repo_url="${2:-https://github.com/basecamp/omarchy}"

    if [[ -d "$omarchy_dir/.git" ]]; then
        log_info "Updating omarchy in $omarchy_dir"
        git -C "$omarchy_dir" pull --ff-only || log_warning "omarchy update failed; continuing"
        return 0
    fi
    if [[ -z "${omarchy_repo_url}" ]]; then
        log_warning "OMARCHY_REPO_URL not set and no existing clone at $omarchy_dir; skipping clone"
        return 0
    fi
    mkdir -p "$(dirname "$omarchy_dir")"
    log_info "Cloning omarchy from $omarchy_repo_url -> $omarchy_dir"
    git clone "$omarchy_repo_url" "$omarchy_dir" || log_warning "omarchy clone failed; continuing"
}


#######################################
# GitHub Release Installation Helpers
# From dotfiles-setup-replica.sh
#######################################

github_api() {
    # $1: path like repos/owner/repo/releases/latest
    # Uses optional GITHUB_TOKEN if set to avoid strict rate limits
    local url="https://api.github.com/$1"
    local response http_code
    
    # Add small delay to be nice to GitHub API
    sleep 0.2
    
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        response=$(curl -fsSL -w "%{http_code}" -H "Authorization: Bearer $GITHUB_TOKEN" "$url" 2>/dev/null)
    else
        response=$(curl -fsSL -w "%{http_code}" "$url" 2>/dev/null)
    fi
    
    http_code="${response: -3}"
    response="${response%???}"
    
    case "$http_code" in
        200) echo "$response" ;;
        403) 
            log_warning "GitHub API rate limit exceeded (403). Solutions:"
            log_warning "1. Wait an hour for reset, or"
            log_warning "2. Set GITHUB_TOKEN environment variable for 5000/hour limit"
            log_warning "3. Get token at: https://github.com/settings/tokens"
            return 1
            ;;
        *)
            log_warning "GitHub API error: HTTP $http_code for $url"
            return 1
            ;;
    esac
}

get_latest_tag() {
    # $1: owner/repo
    # outputs tag (e.g. v0.23.0)
    github_api "repos/$1/releases/latest" | sed -n 's/\s*"tag_name"\s*:\s*"\([^"]*\)".*/\1/p' | head -n1
}

find_asset_url() {
    # $1: owner/repo
    # $2: regex to match asset name (extended regex)
    # outputs browser_download_url
    local or="$1" re="$2"
    github_api "repos/$or/releases/latest" \
      | awk -v RS=',' '1' \
      | sed -n 's/\s*"browser_download_url"\s*:\s*"\([^"]*\)".*/\1/p' \
      | grep -E "$re" | head -n1
}

first_version_from_output() {
    # Reads stdin, extracts first x.y or x.y.z... sequence (robust)
    # Requires grep with -E and -o support
    grep -Eo '([0-9]+)(\.[0-9]+)+' | head -n1
}

ver_ge() {
    # $1 >= $2 ?  return 0 if true
    # relies on sort -V
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

detect_glibc_version() {
    # echo x.y or empty if unknown/non-glibc
    if getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
        getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}' | head -n1
        return 0
    fi
    if ldd --version >/dev/null 2>&1; then
        ldd --version 2>/dev/null | head -n1 | sed -n 's/.* \([0-9]\+\.[0-9]\+\).*/\1/p'
        return 0
    fi
    echo ""
}

install_from_tarball() {
    # $1 name
    # $2 owner/repo
    # $3 asset_name_regex (extended regex against full asset filename)
    # $4 binary_name (as it should be named in INSTALL_DIR)
    # $5 version_cmd (command to print version, quoted string)
    # $6 INSTALL_DIR (optional, defaults to ~/.local/bin)
    local name="$1" or="$2" asset_pat="$3" bin_name="$4" version_cmd="$5"
    local INSTALL_DIR="${6:-$HOME/.local/bin}"

    local latest_tag="" latest_ver="" current_ver="" asset_url="" tmp="" dir="" bin_path=""

    log_info "Checking $name releases..."
    latest_tag=$(get_latest_tag "$or") || { log_warning "Failed to get $name latest tag"; latest_tag=""; }
    latest_ver="${latest_tag#v}"

    if command -v "$bin_name" >/dev/null 2>&1; then
        current_ver=$({ eval "$version_cmd" 2>/dev/null || true; } | first_version_from_output || true)
    else
        current_ver=""
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log_info "$name already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log_info "$name is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    asset_url=$(find_asset_url "$or" "$asset_pat")
    if [[ -z "$asset_url" ]]; then
        log_error "Could not find asset for $name matching /$asset_pat/"
        return 1
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading $name from $asset_url"
    
    # Detect compression format from URL
    local archive_name extract_opts
    if [[ "$asset_url" =~ \.tbz$ ]] || [[ "$asset_url" =~ \.tar\.bz2$ ]]; then
        archive_name="archive.tar.bz2"
        extract_opts="-xjf"
    elif [[ "$asset_url" =~ \.tar\.xz$ ]] || [[ "$asset_url" =~ \.txz$ ]]; then
        archive_name="archive.tar.xz"
        extract_opts="-xJf"
    else
        # Default to gzip (covers .tar.gz, .tgz, etc.)
        archive_name="archive.tar.gz"
        extract_opts="-xzf"
    fi
    
    curl -fsSL "$asset_url" -o "$tmp/$archive_name"

    mkdir -p "$tmp/extract"
    tar $extract_opts "$tmp/$archive_name" -C "$tmp/extract"

    # locate binary in extracted contents
    bin_path=$(find "$tmp/extract" -type f -name "$bin_name" -perm -u+x | head -n1 || true)
    if [[ -z "$bin_path" ]]; then
        # some archives name binary with different path; try just by name regardless of exec bit
        bin_path=$(find "$tmp/extract" -type f -name "$bin_name" | head -n1 || true)
    fi
    if [[ -z "$bin_path" ]]; then
        log_error "Binary $bin_name not found in archive for $name"
        return 1
    fi

    mkdir -p "$INSTALL_DIR"
    install -m 0755 "$bin_path" "$INSTALL_DIR/$bin_name"
    log_success "Installed/updated $name -> $INSTALL_DIR/$bin_name"
}
