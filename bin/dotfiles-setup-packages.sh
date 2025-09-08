#!/bin/bash
set -Eeuo pipefail

# Omarchy prune/install script
# - Removes selected default webapps and packages
# - Installs requested packages
# - Refreshes application launchers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

OMARCHY_BIN="$HOME/.local/share/omarchy/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

remove_webapp() {
	local name="$1"
	if [[ -f "$DESKTOP_DIR/$name.desktop" ]]; then
		log_info "Removing web app: $name"
		"$OMARCHY_BIN/omarchy-webapp-remove" "$name" || true
	else
		log_info "Skip web app (not found): $name"
	fi
}

pkg_installed() { yay -Qi "$1" >/dev/null 2>&1; }

remove_pkg() {
	local pkg="$1"
	if pkg_installed "$pkg"; then
		log_info "Removing package: $pkg"
		yay -Rns --noconfirm "$pkg" || true
	else
		log_info "Skip package (not installed): $pkg"
	fi
}

install_pkg() {
	local pkg="$1"
	if pkg_installed "$pkg"; then
		log_info "Already installed: $pkg"
	else
		log_info "Installing package: $pkg"
		yay -Sy --noconfirm "$pkg"
	fi
}

install_latex_template() {
	local name="$1"
	local url="$2"
	local target_dir="$3"
	local check_file="$4"

	if [[ -f "$check_file" ]]; then
		log_info "LaTeX template $name already installed; skipping"
		return 0
	fi

	log_info "Installing LaTeX template: $name"

	# Create temporary directory
	local temp_dir=$(mktemp -d)
	cd "$temp_dir"

	# Download and extract
	curl -fsSL -o template.zip "$url"
	unzip -q template.zip

	# Create target directory if it doesn't exist
	mkdir -p "$target_dir"

	# Copy files to target directory
	cp -r * "$target_dir/"

	# Clean up
	cd - >/dev/null
	rm -rf "$temp_dir"

	log_info "LaTeX template $name installed successfully"
}

refresh_latex_database() {
	# Refresh LaTeX file database so it can find newly installed templates
	if command -v mktexlsr >/dev/null 2>&1; then
		log_info "Refreshing LaTeX file database..."
		mktexlsr "$HOME/texmf" || log_warning "Warning: Could not refresh LaTeX file database"
	else
		log_info "mktexlsr not found; skipping LaTeX database refresh"
	fi
}

setup_tmux_tpm() {
	# Setup tmux plugin manager (tpm)
	if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
		log_info "Installing tmux plugin manager..."
		mkdir -p "$HOME/.tmux/plugins"
		git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
	else
		log_info "tpm already installed at $HOME/.tmux/plugins/tpm; skipping clone"
	fi
}

setup_tailscale() {
	# Install and configure Tailscale
	log_info "Setting up Tailscale..."

	# Check if Tailscale is already installed
	if command -v tailscale >/dev/null 2>&1; then
		log_info "Tailscale already installed; skipping download"
	else
		log_info "Installing Tailscale..."
		curl -fsSL https://tailscale.com/install.sh | sh
	fi

	# Check if Tailscale is connected
	if tailscale status >/dev/null 2>&1; then
		log_info "Tailscale already connected and running"
	else
		log_info "Starting Tailscale connection..."
		sudo tailscale up
	fi

	# Ask if user wants to enable SSH using gum
	if command -v gum >/dev/null 2>&1; then
		if gum confirm "Enable Tailscale SSH access to this machine?"; then
			log_info "Enabling Tailscale SSH..."
			tailscale set --ssh
			log_success "Tailscale SSH enabled successfully"
		else
			log_info "Skipping Tailscale SSH setup"
		fi
	else
		log_warning "gum not available; skipping SSH setup choice"
		log_info "To enable SSH later, run: tailscale set --ssh"
	fi

	log_success "Tailscale setup completed"
}

main() {
	ensure_cmd yay

	# 1) Remove webapps
	remove_webapp "HEY"
	remove_webapp "Basecamp"
	remove_webapp "WhatsApp"
	remove_webapp "Google Photos"
	remove_webapp "ChatGPT"
	remove_webapp "Figma"

	# 2) Remove packages
	remove_pkg 1password-beta || true
	remove_pkg 1password-cli || true
	#remove_pkg chromium || true
	#remove_pkg typora || true

	# 3) Install packages
	install_pkg zotero-bin

	# Setup Zotero extensions if Zotero was installed successfully
	if pkg_installed zotero-bin; then
		log_info "Setting up Zotero extensions..."
		"$HOME/.dotfiles/bin/dotfiles-setup-zotero.sh" || log_info "Zotero setup failed (non-critical)"
	fi

	install_pkg cursor-bin
	install_pkg rsync
	install_pkg discord
	install_pkg starship
	install_pkg stow
	install_pkg git-lfs
	install_pkg bitwarden
	install_pkg google-chrome
	install_pkg tmux
	install_pkg shfmt
	# Install LaTeX packages
	install_pkg texlive-meta
	# TODO: remove if not necessary
	# install_pkg tex-fmt
	install_pkg zathura
	install_pkg zathura-pdf-mupdf
	#node required for something vimtex related?
	omarchy-install-dev-env node

	# 4) Install LaTeX templates
	install_latex_template \
		"UiO Beamer Theme" \
		"https://www.mn.uio.no/ifi/tjenester/it/hjelp/latex/uiobeamer.zip" \
		"$HOME/texmf/tex/latex/beamer/uiobeamer" \
		"$HOME/texmf/tex/latex/beamer/uiobeamer/beamerthemeUiO.sty"

	# Setup development environment tools
	refresh_latex_database
	setup_tmux_tpm

	# Network and connectivity setup
	setup_tailscale

	# Install tools via curl installers
	install_via_curl "Julia (juliaup)" "juliaup" "https://install.julialang.org" "source ~/.bashrc && ~/.dotfiles/bin/julia-setup.jl"
	install_via_curl "cursor-cli" "cursor-agent" "https://cursor.com/install"

	# Install/Update Runic script used by custom local formatter
	"$SCRIPT_DIR/dotfiles-install-runic.sh" || log_warning "Runic installation failed"

	# 5) Refresh desktop database (user apps)
	update-desktop-database ~/.local/share/applications/ || true

	log_info "Done."
}

main "$@"
