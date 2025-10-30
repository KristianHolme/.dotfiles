#!/bin/bash

# Simple SSH + tmux connection script
# Usage: ./dotfiles-ssh-tmux.sh
# Select a server and connect with automatic tmux session management

set -e # Exit on any error

# Server list based on SSH config
SERVERS=(
	"atalanta"
	"abacus-as"
	"abacus-min"
	"nam-shub-01"
	"nam-shub-02"
	"bioint01"
	"bioint02"
	"bioint03"
	"bioint04"
	"saga"
	# personal machines via Tailscale
	"bengal"
	"kaspi"
	"sibir"
)

# Check if gum is installed
if ! command -v gum &>/dev/null; then
	echo "Error: gum is not installed. Please install it first:"
	echo "  Arch: sudo pacman -S gum"
	echo "  Other: https://github.com/charmbracelet/gum#installation"
	exit 1
fi

# Hide current host from selection
CURRENT_HOST="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "")"
FILTERED=$(printf '%s\n' "${SERVERS[@]}" | awk -v h="$CURRENT_HOST" 'tolower($0)!=tolower(h)')

# Let user choose server with fuzzy finding
SELECTED=$(printf '%s\n' "$FILTERED" | gum filter \
	--header "🔍 Choose server to connect to:" \
	--placeholder "Type to search servers..." \
	--prompt "❯ ")

if [ -z "$SELECTED" ]; then
	echo "❌ No server selected. Exiting."
	exit 0
fi

echo "🚀 Connecting to $SELECTED..."
echo "   - Will attach to existing tmux session or create new one"
echo "   - Use Ctrl+D or 'exit' to disconnect"
echo

# For saga, check if ControlMaster socket exists and start background master if needed
if [ "$SELECTED" = "saga" ]; then
	CONTROL_SOCKET="$HOME/.ssh/kholme@saga.sigma2.no:22"
	
	# Check if socket exists and is valid (not stale)
	if [ ! -S "$CONTROL_SOCKET" ] || ! ssh -O check saga >/dev/null 2>&1; then
		echo "🔐 Starting background master connection for saga..."
		echo "   (This will prompt for 2FA + password once)"
		# Start background master connection
		# -fN: go to background after authentication, don't execute remote command
		# -CX: compression and X11 forwarding
		# -o ServerAliveInterval=30: keep connection alive
		if ssh -CX -o ServerAliveInterval=30 -fN saga; then
			echo "✅ Master connection established"
		else
			echo "⚠️  Failed to start master connection, continuing anyway..."
		fi
		echo
	fi
fi

# Connect with SSH and handle tmux sessions
# -t forces pseudo-terminal allocation (needed for tmux)
# Attach or create named session with UTF-8 env and UTF-8 client
ssh "$SELECTED" -t 'printf "\033]0;%s\007" "$(hostname -s)"; tmux -u new-session -A -s main'

echo
echo "✅ Disconnected from $SELECTED"
