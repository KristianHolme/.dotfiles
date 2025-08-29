#!/usr/bin/env bash
set -Eeuo pipefail

# Installs/updates user-local CLI tools without sudo (RHEL-compatible):
# - eza, zoxide, ripgrep (rg), lazygit, fzf, starship, neovim
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

log() { echo "[omarchy-unipriv] $*"; }
warn() { echo "[omarchy-unipriv][WARN] $*" >&2; }
err() { echo "[omarchy-unipriv][ERR] $*" >&2; }

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
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$url"
    else
        curl -fsSL "$url"
    fi
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
    # Reads stdin, extracts first x.y or x.y.z... sequence
    sed -n 's/.*\b\([0-9]\+\(\.[0-9]\+\)\+\)\b.*/\1/p' | head -n1
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

    local latest_tag latest_ver current_ver asset_url tmp dir bin_path

    log "Checking $name releases..."
    latest_tag=$(get_latest_tag "$or") || { warn "Failed to get $name latest tag"; latest_tag=""; }
    latest_ver="${latest_tag#v}"

    if command -v "$bin_name" >/dev/null 2>&1; then
        current_ver=$({ eval "$version_cmd" 2>/dev/null || true; } | first_version_from_output || true)
    else
        current_ver=""
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" && "$current_ver" == "$latest_ver" ]]; then
        log "$name already up to date ($current_ver)"
        return 0
    fi

    asset_url=$(find_asset_url "$or" "$asset_pat")
    if [[ -z "$asset_url" ]]; then
        err "Could not find asset for $name matching /$asset_pat/"
        return 1
    fi

    tmp=$(mktemp -d)
    trap 'rm -rf "'$tmp'"' RETURN
    log "Downloading $name from $asset_url"
    curl -fsSL "$asset_url" -o "$tmp/archive.tar.gz"

    mkdir -p "$tmp/extract"
    tar -xzf "$tmp/archive.tar.gz" -C "$tmp/extract"

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
    log "Installed $name -> $INSTALL_DIR/$bin_name"
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
    if [[ -n "$current_ver" && -n "$latest_ver" && "$current_ver" == "$latest_ver" ]]; then
        log "starship already up to date ($current_ver)"
        return 0
    fi
    log "Installing/updating starship to $latest_tag"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$INSTALL_DIR"
}

install_neovim() {
    local latest_tag latest_ver current_ver glibc_ver asset_url tmp nvim_target_dir
    latest_tag=$(get_latest_tag "neovim/neovim" || true)
    latest_ver="${latest_tag#v}"

    if command -v nvim >/dev/null 2>&1; then
        current_ver=$(nvim --version 2>/dev/null | head -n1 | first_version_from_output || true)
    else
        current_ver=""
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" && "$current_ver" == "$latest_ver" ]]; then
        log "neovim already up to date ($current_ver)"
        return 0
    fi

    glibc_ver=$(detect_glibc_version || true)

    mkdir -p "$INSTALL_DIR"

    # prefer official tarball when glibc >= 2.29, else AppImage fallback
    if [[ -n "$glibc_ver" ]] && ver_ge "$glibc_ver" "2.29"; then
        asset_url=$(find_asset_url "neovim/neovim" 'nvim-linux64\.tar\.gz$' || true)
        if [[ -n "$asset_url" ]]; then
            tmp=$(mktemp -d)
            trap 'rm -rf "'$tmp'"' RETURN
            log "Downloading neovim tarball from $asset_url"
            curl -fsSL "$asset_url" -o "$tmp/nvim.tar.gz"
            mkdir -p "$tmp/extract"
            tar -xzf "$tmp/nvim.tar.gz" -C "$tmp/extract"
            nvim_target_dir="$NVIM_OPT_DIR/$latest_tag"
            mkdir -p "$NVIM_OPT_DIR"
            rm -rf "$nvim_target_dir"
            # tarball extracts to nvim-linux64
            mv "$tmp/extract"/nvim-linux64 "$nvim_target_dir"
            ln -sf "$nvim_target_dir/bin/nvim" "$INSTALL_DIR/nvim"
            log "Installed neovim (tarball) -> $INSTALL_DIR/nvim"
            return 0
        else
            warn "Could not find neovim tarball asset; will try AppImage fallback"
        fi
    else
        log "glibc ($glibc_ver) < 2.28; using AppImage build"
    fi

    # AppImage fallback for older glibc
    asset_url=$(find_asset_url "neovim/neovim-releases" 'nvim.*x86_64.*AppImage$' || true)
    if [[ -z "$asset_url" ]]; then
        err "Could not find neovim AppImage asset"
        return 1
    fi
    tmp=$(mktemp -d)
    trap 'rm -rf "'$tmp'"' RETURN
    log "Downloading neovim AppImage from $asset_url"
    curl -fsSL "$asset_url" -o "$tmp/nvim.AppImage"
    install -m 0755 "$tmp/nvim.AppImage" "$INSTALL_DIR/nvim.appimage"
    ln -sf "$INSTALL_DIR/nvim.appimage" "$INSTALL_DIR/nvim"
    log "Installed neovim (AppImage) -> $INSTALL_DIR/nvim (symlink)"
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
        'lazygit_[^/]*_Linux_x86_64\.tar\.gz$' \
        lazygit "lazygit --version"

    install_from_tarball \
        "fzf" "junegunn/fzf" \
        'fzf-[^/]*-linux_amd64\.tar\.gz$' \
        fzf "fzf --version"

    install_starship

    install_neovim

    clone_or_update_omarchy

    log "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"


