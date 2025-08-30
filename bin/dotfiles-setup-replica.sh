#!/usr/bin/env bash
set -Eeuo pipefail

# Installs/updates user-local CLI tools without sudo (RHEL-compatible):
# - eza, zoxide, ripgrep (rg), lazygit, fzf, fd, starship, tree-sitter, git-lfs, btop, neovim, stow, gum
# - Clones/updates omarchy to ~/.local/share/omarchy
#
# Idempotent: safe to re-run; updates if new releases available.
#
# Config via env vars (override as needed):
#   INSTALL_DIR       - where to place binaries (default: ~/.local/bin)
#   OMARCHY_DIR       - omarchy clone dir (default: ~/.local/share/omarchy)
#   OMARCHY_REPO_URL  - git URL for omarchy (default: empty; skip clone if unset)
#   NVIM_OPT_DIR      - install base for Neovim tarball (default: ~/.local/opt/neovim)
#   GITHUB_TOKEN      - optional, to increase API rate limits

INSTALL_DIR="${INSTALL_DIR:-"$HOME/.local/bin"}"
OMARCHY_DIR="${OMARCHY_DIR:-"$HOME/.local/share/omarchy"}"
OMARCHY_REPO_URL="${OMARCHY_REPO_URL:-https://github.com/basecamp/omarchy}"
NVIM_OPT_DIR="${NVIM_OPT_DIR:-"$HOME/.local/opt/neovim"}"

log() { echo "[omarchy-replica] $*"; }
warn() { echo "[omarchy-replica][WARN] $*" >&2; }
err() { echo "[omarchy-replica][ERR] $*" >&2; }

ensure_cmd() {
    command -v "$1" >/dev/null 2>&1 || { err "Missing required command: $1"; exit 1; }
}

arch_is_supported() {
    case "$(uname -m)" in
        x86_64|amd64) return 0 ;;
        *) return 1 ;;
    esac
}

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
            warn "GitHub API rate limit exceeded (403). Solutions:"
            warn "1. Wait an hour for reset, or"
            warn "2. Set GITHUB_TOKEN environment variable for 5000/hour limit"
            warn "3. Get token at: https://github.com/settings/tokens"
            return 1
            ;;
        *)
            warn "GitHub API error: HTTP $http_code for $url"
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
    local name="$1" or="$2" asset_pat="$3" bin_name="$4" version_cmd="$5"

    local latest_tag="" latest_ver="" current_ver="" asset_url="" tmp="" dir="" bin_path=""

    log "Checking $name releases..."
    latest_tag=$(get_latest_tag "$or") || { warn "Failed to get $name latest tag"; latest_tag=""; }
    latest_ver="${latest_tag#v}"

    if command -v "$bin_name" >/dev/null 2>&1; then
        current_ver=$({ eval "$version_cmd" 2>/dev/null || true; } | first_version_from_output || true)
    else
        current_ver=""
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log "$name already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log "$name is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    asset_url=$(find_asset_url "$or" "$asset_pat")
    if [[ -z "$asset_url" ]]; then
        err "Could not find asset for $name matching /$asset_pat/"
        return 1
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log "Downloading $name from $asset_url"
    
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
        err "Binary $bin_name not found in archive for $name"
        return 1
    fi

    mkdir -p "$INSTALL_DIR"
    install -m 0755 "$bin_path" "$INSTALL_DIR/$bin_name"
    log "Installed/updated $name -> $INSTALL_DIR/$bin_name"
}

install_starship() {
    local latest_tag current_ver latest_ver
    latest_tag=$(get_latest_tag "starship/starship" || true)
    latest_ver="${latest_tag#v}"
    if command -v starship >/dev/null 2>&1; then
        current_ver=$(starship --version 2>/dev/null | first_version_from_output || true)
    else
        current_ver=""
    fi
    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log "starship already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log "starship is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi
    log "Installing/updating starship to $latest_tag"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$INSTALL_DIR"
}

install_tree_sitter() {
    local latest_tag="" latest_ver="" current_ver="" asset_url="" tmp=""
    latest_tag=$(get_latest_tag "tree-sitter/tree-sitter" || true)
    latest_ver="${latest_tag#v}"

    if command -v tree-sitter >/dev/null 2>&1; then
        current_ver=$(tree-sitter --version 2>/dev/null | first_version_from_output || true)
        log "tree-sitter detected: current=$current_ver, latest=$latest_ver"
    else
        current_ver=""
        log "tree-sitter not found in PATH"
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log "tree-sitter already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log "tree-sitter is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    mkdir -p "$INSTALL_DIR"

    # tree-sitter releases as tree-sitter-linux-x64.gz
    asset_url=$(find_asset_url "tree-sitter/tree-sitter" 'tree-sitter-linux-x64\.gz$' || true)
    if [[ -z "$asset_url" ]]; then
        err "Could not find tree-sitter linux binary"
        return 1
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log "Downloading tree-sitter from $asset_url"
    curl -fsSL "$asset_url" -o "$tmp/tree-sitter.gz"
    gunzip "$tmp/tree-sitter.gz"
    install -m 0755 "$tmp/tree-sitter" "$INSTALL_DIR/tree-sitter"
    log "Installed tree-sitter -> $INSTALL_DIR/tree-sitter"
}

install_git_lfs() {
    local latest_tag="" latest_ver="" current_ver="" asset_url="" tmp=""
    latest_tag=$(get_latest_tag "git-lfs/git-lfs" || true)
    latest_ver="${latest_tag#v}"

    if command -v git-lfs >/dev/null 2>&1; then
        current_ver=$(git lfs version 2>/dev/null | grep -Eo 'git-lfs/([0-9]+\.)+[0-9]+' | cut -d'/' -f2 || true)
        log "git-lfs detected: current=$current_ver, latest=$latest_ver"
    else
        current_ver=""
        log "git-lfs not found in PATH"
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log "git-lfs already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log "git-lfs is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    mkdir -p "$INSTALL_DIR"

    # git-lfs releases as git-lfs-linux-amd64-v*.tar.gz
    asset_url=$(find_asset_url "git-lfs/git-lfs" 'git-lfs-linux-amd64-v.*\.tar\.gz$' || true)
    if [[ -z "$asset_url" ]]; then
        err "Could not find git-lfs linux binary"
        return 1
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log "Downloading git-lfs from $asset_url"
    curl -fsSL "$asset_url" -o "$tmp/git-lfs.tar.gz"
    tar -xzf "$tmp/git-lfs.tar.gz" -C "$tmp"
    
    # Find the git-lfs binary in the extracted tarball
    local git_lfs_bin
    git_lfs_bin=$(find "$tmp" -name "git-lfs" -type f -executable | head -n1 || true)
    if [[ -z "$git_lfs_bin" ]]; then
        err "Could not find git-lfs binary in downloaded archive"
        return 1
    fi
    
    install -m 0755 "$git_lfs_bin" "$INSTALL_DIR/git-lfs"
    log "Installed git-lfs -> $INSTALL_DIR/git-lfs"
    
    # Install git-lfs hooks (this is safe to run multiple times)
    if command -v git-lfs >/dev/null 2>&1; then
        git lfs install --skip-smudge 2>/dev/null || warn "Failed to install git-lfs hooks"
        log "Configured git-lfs hooks"
    fi
}

install_neovim() {
    local latest_tag="" latest_ver="" current_ver="" glibc_ver="" asset_url="" tmp=""
    latest_tag=$(get_latest_tag "neovim/neovim" || true)
    latest_ver="${latest_tag#v}"

    if command -v nvim >/dev/null 2>&1; then
        current_ver=$(nvim --version 2>/dev/null | head -n1 | first_version_from_output || true)
    else
        current_ver=""
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log "neovim already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log "neovim is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    glibc_ver=$(detect_glibc_version || true)

    mkdir -p "$INSTALL_DIR"

    # Use AppImage in both cases. If glibc >= 2.29, use supported repo; else use unsupported releases repo.
    if [[ -n "$glibc_ver" ]] && ver_ge "$glibc_ver" "2.29"; then
        asset_url=$(find_asset_url "neovim/neovim" 'nvim-linux-x86_64\.appimage$' || true)
    else
        asset_url=$(find_asset_url "neovim/neovim-releases" 'nvim-linux-x86_64\.appimage$' || true)
    fi
    if [[ -z "$asset_url" ]]; then
        err "Could not find neovim AppImage asset"
        return 1
    fi
    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log "Downloading neovim AppImage from $asset_url"
    curl -fsSL "$asset_url" -o "$tmp/nvim.AppImage"
    install -m 0755 "$tmp/nvim.AppImage" "$INSTALL_DIR/nvim.appimage"
    ln -sf "$INSTALL_DIR/nvim.appimage" "$INSTALL_DIR/nvim"
    log "Installed neovim (AppImage) -> $INSTALL_DIR/nvim (symlink)"
}

install_lazyvim() {
    local nvim_config_dir="$HOME/.config/nvim"
    
    # Check if LazyVim is already installed
    if [[ -f "$nvim_config_dir/lua/config/lazy.lua" ]] || [[ -f "$nvim_config_dir/init.lua" ]]; then
        log "LazyVim config already exists; skipping"
        return 0
    fi
    
    # Check if nvim is available
    if ! command -v nvim >/dev/null 2>&1; then
        warn "nvim not found; skipping LazyVim installation"
        return 0
    fi
    
    log "Installing LazyVim starter configuration..."
    
    # Create nvim config directory
    mkdir -p "$nvim_config_dir"
    
    # Clone LazyVim starter template
    local tmp_dir=""
    tmp_dir=$(mktemp -d)
    trap 't="${tmp_dir:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    
    if git clone https://github.com/LazyVim/starter "$tmp_dir/lazyvim-starter" >/dev/null 2>&1; then
        # Remove .git directory from starter template
        rm -rf "$tmp_dir/lazyvim-starter/.git"
        
        # Copy starter files to nvim config (use pushd/popd to avoid path issues)
        pushd "$tmp_dir/lazyvim-starter" >/dev/null
        
        # Copy all files (visible and hidden) from the LazyVim starter
        cp -r . "$nvim_config_dir/"
        
        popd >/dev/null
        
        log "LazyVim starter configuration installed"
        log "Run 'nvim' to complete the setup and install plugins"
    else
        err "Failed to clone LazyVim starter template"
        return 1
    fi
}

install_gum() {
    if command -v gum >/dev/null 2>&1; then
        log "gum already installed; skipping"
        return 0
    fi

    local latest_tag="" latest_ver="" asset_url="" tmp=""
    latest_tag=$(get_latest_tag "charmbracelet/gum" || true)
    latest_ver="${latest_tag#v}"

    if command -v gum >/dev/null 2>&1; then
        current_ver=$(gum --version 2>/dev/null | first_version_from_output || true)
    else
        current_ver=""
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log "gum already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log "gum is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    asset_url=$(find_asset_url "charmbracelet/gum" 'gum_[^/]*_Linux_x86_64\.tar\.gz$' || true)
    if [[ -z "$asset_url" ]]; then
        err "Could not find gum asset"
        return 1
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log "Downloading gum from $asset_url"
    curl -fsSL "$asset_url" -o "$tmp/gum.tar.gz"

    mkdir -p "$tmp/extract"
    tar -xzf "$tmp/gum.tar.gz" -C "$tmp/extract"

    # Find gum binary
    local gum_bin
    gum_bin=$(find "$tmp/extract" -type f -name gum -perm -u+x | head -n1 || true)
    if [[ -z "$gum_bin" ]]; then
        gum_bin=$(find "$tmp/extract" -type f -name gum | head -n1 || true)
    fi

    if [[ -n "$gum_bin" ]]; then
        mkdir -p "$INSTALL_DIR"
        install -m 0755 "$gum_bin" "$INSTALL_DIR/gum"
        log "Installed gum -> $INSTALL_DIR/gum"
    else
        err "Could not find gum binary in archive"
        return 1
    fi
}

install_stow() {
    if command -v stow >/dev/null 2>&1; then
        log "stow already installed; skipping"
        return 0
    fi
    local prefix="" tmp="" src=""
    prefix="${STOW_PREFIX:-$(dirname "$INSTALL_DIR")}" # default to ~/.local
    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log "Downloading and building stow (latest)"
    curl -fsSL https://ftp.gnu.org/gnu/stow/stow-latest.tar.gz -o "$tmp/stow.tar.gz"
    tar -xzf "$tmp/stow.tar.gz" -C "$tmp"
    src=$(find "$tmp" -maxdepth 1 -type d -name 'stow-*' | head -n1 || true)
    if [[ -z "$src" ]]; then
        err "Failed to locate stow source directory"
        return 1
    fi

    # Build and install stow, handling missing test dependencies gracefully
    (
        cd "$src"
        # Configure with minimal output, suppress warnings about missing test modules
        ./configure --prefix="$prefix" --quiet 2>&1 | grep -v "WARNING.*missing modules" || true
        # Build quietly, skip tests if dependencies are missing
        make -s 2>&1 | grep -v "WARNING.*missing modules" || true
        # Install quietly
        make -s install 2>&1 | grep -v "WARNING.*missing modules" || true
    )

    if command -v stow >/dev/null 2>&1; then
        log "Installed stow -> $prefix/bin/stow"
    else
        err "Failed to install stow"
        return 1
    fi
}

clone_or_update_omarchy() {
    if [[ -d "$OMARCHY_DIR/.git" ]]; then
        log "Updating omarchy in $OMARCHY_DIR"
        git -C "$OMARCHY_DIR" pull --ff-only || warn "omarchy update failed; continuing"
        return 0
    fi
    if [[ -z "${OMARCHY_REPO_URL}" ]]; then
        warn "OMARCHY_REPO_URL not set and no existing clone at $OMARCHY_DIR; skipping clone"
        return 0
    fi
    mkdir -p "$(dirname "$OMARCHY_DIR")"
    log "Cloning omarchy from $OMARCHY_REPO_URL -> $OMARCHY_DIR"
    git clone "$OMARCHY_REPO_URL" "$OMARCHY_DIR" || warn "omarchy clone failed; continuing"
}

main() {
    ensure_cmd curl
    ensure_cmd tar
    ensure_cmd git
    ensure_cmd install
    ensure_cmd make
    ensure_cmd perl

    if ! arch_is_supported; then
        err "Unsupported architecture $(uname -m). This script targets x86_64 Linux."
        exit 1
    fi

    mkdir -p "$INSTALL_DIR"

    # Tool installers (use MUSL where available for broad glibc compatibility on RHEL)
    install_from_tarball \
        "eza" "eza-community/eza" \
        'eza_[^/]*x86_64-unknown-linux-gnu\.tar\.gz$' \
        eza "eza --version"

    install_from_tarball \
        "zoxide" "ajeetdsouza/zoxide" \
        'zoxide[^/]*x86_64-unknown-linux-musl\.tar\.gz$' \
        zoxide "zoxide -V"

    install_from_tarball \
        "ripgrep" "BurntSushi/ripgrep" \
        'ripgrep-[^/]*-x86_64-unknown-linux-musl\.tar\.gz$' \
        rg "rg --version"

    install_from_tarball \
        "lazygit" "jesseduffield/lazygit" \
        'lazygit_[^/]*_linux_x86_64\.tar\.gz$' \
        lazygit "lazygit --version"

    install_from_tarball \
        "fzf" "junegunn/fzf" \
        'fzf-[^/]*-linux_amd64\.tar\.gz$' \
        fzf "fzf --version"

    install_from_tarball \
        "fd" "sharkdp/fd" \
        'fd-v[^/]*-x86_64-unknown-linux-musl\.tar\.gz$' \
        fd "fd --version"

    install_tree_sitter

    install_git_lfs

    install_from_tarball \
        "btop" "aristocratos/btop" \
        'btop-x86_64-linux-musl\.tbz$' \
        btop "btop --version"

    install_starship

    # Build/install GNU stow user-locally if missing
    install_stow

    install_neovim

    # Install LazyVim starter configuration
    install_lazyvim

    # Install gum for interactive prompts
    install_gum

    clone_or_update_omarchy

    log "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"


