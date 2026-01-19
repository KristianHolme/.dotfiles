#!/usr/bin/env bash
set -Eeuo pipefail

# Installs/updates user-local CLI tools without sudo (RHEL-compatible):
# - eza, zoxide, ripgrep (rg), lazygit, fzf, fd, starship, tree-sitter, git-lfs, btop, neovim, stow, gum, yazi
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
#   DEBUG             - set to 1 for verbose debug output
#   CURL_TIMEOUT      - timeout for curl operations in seconds (default: 30 for API, 120 for downloads)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

INSTALL_DIR="${INSTALL_DIR:-"$HOME/.local/bin"}"
OMARCHY_DIR="${OMARCHY_DIR:-"$HOME/.local/share/omarchy"}"
OMARCHY_REPO_URL="${OMARCHY_REPO_URL:-https://github.com/basecamp/omarchy}"
NVIM_OPT_DIR="${NVIM_OPT_DIR:-"$HOME/.local/opt/neovim"}"

arch_is_supported() {
    case "$(uname -m)" in
    x86_64 | amd64) return 0 ;;
    *) return 1 ;;
    esac
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
            log_info "starship already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log_info "starship is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi
    log_info "Installing/updating starship to $latest_tag"
    local timeout="${CURL_TIMEOUT:-120}"
    curl --max-time "$timeout" -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$INSTALL_DIR" || {
        log_error "Failed to install starship"
        return 1
    }
}

install_tree_sitter() {
    local latest_tag="" latest_ver="" current_ver="" asset_url="" tmp=""
    latest_tag=$(get_latest_tag "tree-sitter/tree-sitter" || true)
    latest_ver="${latest_tag#v}"

    if command -v tree-sitter >/dev/null 2>&1; then
        current_ver=$(tree-sitter --version 2>/dev/null | first_version_from_output || true)
        log_info "tree-sitter detected: current=$current_ver, latest=$latest_ver"
    else
        current_ver=""
        log_info "tree-sitter not found in PATH"
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log_info "tree-sitter already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log_info "tree-sitter is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    mkdir -p "$INSTALL_DIR"

    # tree-sitter releases as tree-sitter-linux-x64.gz
    asset_url=$(find_asset_url "tree-sitter/tree-sitter" 'tree-sitter-linux-x64\.gz$' || true)
    if [[ -z "$asset_url" ]]; then
        log_error "Could not find tree-sitter linux binary"
        return 1
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading tree-sitter from $asset_url"
    local timeout="${CURL_TIMEOUT:-120}"
    curl --max-time "$timeout" -fsSL "$asset_url" -o "$tmp/tree-sitter.gz" || {
        log_error "Failed to download tree-sitter"
        return 1
    }
    gunzip "$tmp/tree-sitter.gz"
    install -m 0755 "$tmp/tree-sitter" "$INSTALL_DIR/tree-sitter"
    log_success "Installed tree-sitter -> $INSTALL_DIR/tree-sitter"
}

install_git_lfs() {
    local latest_tag="" latest_ver="" current_ver="" asset_url="" tmp=""
    latest_tag=$(get_latest_tag "git-lfs/git-lfs" || true)
    latest_ver="${latest_tag#v}"

    if command -v git-lfs >/dev/null 2>&1; then
        current_ver=$(git lfs version 2>/dev/null | grep -Eo 'git-lfs/([0-9]+\.)+[0-9]+' | cut -d'/' -f2 || true)
        log_info "git-lfs detected: current=$current_ver, latest=$latest_ver"
    else
        current_ver=""
        log_info "git-lfs not found in PATH"
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log_info "git-lfs already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log_info "git-lfs is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    mkdir -p "$INSTALL_DIR"

    # git-lfs releases as git-lfs-linux-amd64-v*.tar.gz
    asset_url=$(find_asset_url "git-lfs/git-lfs" 'git-lfs-linux-amd64-v.*\.tar\.gz$' || true)
    if [[ -z "$asset_url" ]]; then
        log_error "Could not find git-lfs linux binary"
        return 1
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading git-lfs from $asset_url"
    local timeout="${CURL_TIMEOUT:-120}"
    curl --max-time "$timeout" -fsSL "$asset_url" -o "$tmp/git-lfs.tar.gz" || {
        log_error "Failed to download git-lfs"
        return 1
    }
    tar -xzf "$tmp/git-lfs.tar.gz" -C "$tmp"

    # Find the git-lfs binary in the extracted tarball
    local git_lfs_bin
    git_lfs_bin=$(find "$tmp" -name "git-lfs" -type f -executable | head -n1 || true)
    if [[ -z "$git_lfs_bin" ]]; then
        log_error "Could not find git-lfs binary in downloaded archive"
        return 1
    fi

    install -m 0755 "$git_lfs_bin" "$INSTALL_DIR/git-lfs"
    log_success "Installed git-lfs -> $INSTALL_DIR/git-lfs"

    # Install git-lfs hooks (this is safe to run multiple times)
    if command -v git-lfs >/dev/null 2>&1; then
        git lfs install --skip-smudge 2>/dev/null || log_warning "Failed to install git-lfs hooks"
        log_info "Configured git-lfs hooks"
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
            log_info "neovim already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log_info "neovim is newer or equal ($current_ver >= $latest_ver); skipping"
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
        log_error "Could not find neovim AppImage asset"
        return 1
    fi
    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading neovim AppImage from $asset_url"
    local timeout="${CURL_TIMEOUT:-300}"
    curl --max-time "$timeout" -fsSL "$asset_url" -o "$tmp/nvim.AppImage" || {
        log_error "Failed to download neovim"
        return 1
    }
    install -m 0755 "$tmp/nvim.AppImage" "$INSTALL_DIR/nvim.appimage"
    ln -sf "$INSTALL_DIR/nvim.appimage" "$INSTALL_DIR/nvim"
    log_success "Installed neovim (AppImage) -> $INSTALL_DIR/nvim (symlink)"
}

install_lazyvim() {
    local nvim_config_dir="$HOME/.config/nvim"

    # Check if LazyVim is already installed
    if [[ -f "$nvim_config_dir/lua/config/lazy.lua" ]] || [[ -f "$nvim_config_dir/init.lua" ]]; then
        log_info "LazyVim config already exists; skipping"
        return 0
    fi

    # Check if nvim is available
    if ! command -v nvim >/dev/null 2>&1; then
        log_warning "nvim not found; skipping LazyVim installation"
        return 0
    fi

    log_info "Installing LazyVim starter configuration..."

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

        log_success "LazyVim starter configuration installed"
        log_info "Run 'nvim' to complete the setup and install plugins"
    else
        log_error "Failed to clone LazyVim starter template"
        return 1
    fi
}

install_gum() {
    if command -v gum >/dev/null 2>&1; then
        log_info "gum already installed; skipping"
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
            log_info "gum already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log_info "gum is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    asset_url=$(find_asset_url "charmbracelet/gum" 'gum_[^/]*_Linux_x86_64\.tar\.gz$' || true)
    if [[ -z "$asset_url" ]]; then
        log_error "Could not find gum asset"
        return 1
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading gum from $asset_url"
    local timeout="${CURL_TIMEOUT:-120}"
    curl --max-time "$timeout" -fsSL "$asset_url" -o "$tmp/gum.tar.gz" || {
        log_error "Failed to download gum"
        return 1
    }

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
        log_success "Installed gum -> $INSTALL_DIR/gum"
    else
        log_error "Could not find gum binary in archive"
        return 1
    fi
}

install_tpm() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"

    # Check if TPM is already installed
    if [[ -d "$tpm_dir" ]]; then
        log_info "tmux plugin manager (tpm) already installed; skipping"
        return 0
    fi

    log_info "Installing tmux plugin manager (tpm)..."

    # Create parent directory if needed
    mkdir -p "$(dirname "$tpm_dir")"

    # Clone TPM
    if git clone https://github.com/tmux-plugins/tpm "$tpm_dir" >/dev/null 2>&1; then
        log_success "Installed tmux plugin manager -> $tpm_dir"
    else
        log_error "Failed to clone tmux plugin manager"
        return 1
    fi
}

install_stow() {
    if command -v stow >/dev/null 2>&1; then
        log_info "stow already installed; skipping"
        return 0
    fi
    local prefix="" tmp="" src=""
    prefix="${STOW_PREFIX:-$(dirname "$INSTALL_DIR")}" # default to ~/.local
    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading and building stow (latest)"
    local timeout="${CURL_TIMEOUT:-120}"
    curl --max-time "$timeout" -fsSL https://ftp.gnu.org/gnu/stow/stow-latest.tar.gz -o "$tmp/stow.tar.gz" || {
        log_error "Failed to download stow"
        return 1
    }
    tar -xzf "$tmp/stow.tar.gz" -C "$tmp"
    src=$(find "$tmp" -maxdepth 1 -type d -name 'stow-*' | head -n1 || true)
    if [[ -z "$src" ]]; then
        log_error "Failed to locate stow source directory"
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
        log_success "Installed stow -> $prefix/bin/stow"
    else
        log_error "Failed to install stow"
        return 1
    fi
}

main() {
    ensure_cmd curl tar git install make perl

    if ! arch_is_supported; then
        log_error "Unsupported architecture $(uname -m). This script targets x86_64 Linux."
        exit 1
    fi

    if [[ "${DEBUG:-}" == "1" ]]; then
        log_info "DEBUG mode enabled"
        log_info "DEBUG: INSTALL_DIR=$INSTALL_DIR"
        log_info "DEBUG: GITHUB_TOKEN=${GITHUB_TOKEN:+set}"
        log_info "DEBUG: CURL_TIMEOUT=${CURL_TIMEOUT:-default}"
    fi

    mkdir -p "$INSTALL_DIR"

    # Tool installers (use MUSL where available for broad glibc compatibility on RHEL)
    # Each installation is wrapped to continue on failure
    install_from_tarball \
        "eza" "eza-community/eza" \
        'eza_[^/]*x86_64-unknown-linux-gnu\.tar\.gz$' \
        eza "eza --version" "$INSTALL_DIR" || log_warning "eza installation failed; continuing"

    install_from_tarball \
        "zoxide" "ajeetdsouza/zoxide" \
        'zoxide[^/]*x86_64-unknown-linux-musl\.tar\.gz$' \
        zoxide "zoxide -V" "$INSTALL_DIR" || log_warning "zoxide installation failed; continuing"

    install_from_tarball \
        "ripgrep" "BurntSushi/ripgrep" \
        'ripgrep-[^/]*-x86_64-unknown-linux-musl\.tar\.gz$' \
        rg "rg --version" "$INSTALL_DIR" || log_warning "ripgrep installation failed; continuing"

    install_from_tarball \
        "lazygit" "jesseduffield/lazygit" \
        'lazygit_[^/]*_linux_x86_64\.tar\.gz$' \
        lazygit "lazygit --version" "$INSTALL_DIR" || log_warning "lazygit installation failed; continuing"

    install_from_tarball \
        "fzf" "junegunn/fzf" \
        'fzf-[^/]*-linux_amd64\.tar\.gz$' \
        fzf "fzf --version" "$INSTALL_DIR" || log_warning "fzf installation failed; continuing"

    install_from_tarball \
        "fd" "sharkdp/fd" \
        'fd-v[^/]*-x86_64-unknown-linux-musl\.tar\.gz$' \
        fd "fd --version" "$INSTALL_DIR" || log_warning "fd installation failed; continuing"

    install_tree_sitter || log_warning "tree-sitter installation failed; continuing"

    install_git_lfs || log_warning "git-lfs installation failed; continuing"

    install_from_tarball \
        "btop" "aristocratos/btop" \
        'btop-x86_64-unknown-linux-musl\.tbz$' \
        btop "btop --version" "$INSTALL_DIR" || log_warning "btop installation failed; continuing"

    install_from_tarball \
        "yazi" "sxyazi/yazi" \
        'yazi[^/]*-x86_64-unknown-linux-(gnu|musl)\.tar\.gz$' \
        yazi "yazi --version" "$INSTALL_DIR" || log_warning "yazi installation failed; continuing"

    install_starship || log_warning "starship installation failed; continuing"

    # Build/install GNU stow user-locally if missing
    install_stow || log_warning "stow installation failed; continuing"

    install_neovim || log_warning "neovim installation failed; continuing"

    # Install LazyVim starter configuration
    install_lazyvim || log_warning "LazyVim installation failed; continuing"

    # Install gum for interactive prompts
    install_gum || log_warning "gum installation failed; continuing"

    # Install tmux plugin manager
    install_tpm || log_warning "tpm installation failed; continuing"

    # Install Julia (juliaup) and Run Julia setup on first install
    install_via_curl "Julia (juliaup)" "juliaup" "https://install.julialang.org" "source ~/.bashrc && $SCRIPT_DIR/julia-setup.jl" --yes

    # Install/Update Runic script used by custom local formatter
    "$SCRIPT_DIR/dotfiles-install-runic.sh" || log_warning "Runic installation failed"

    clone_or_update_omarchy "$OMARCHY_DIR" "$OMARCHY_REPO_URL"

    log_success "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"
