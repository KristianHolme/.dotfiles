#!/bin/bash
set -Eeuo pipefail

# SSH setup script
# - Adds ed25519 key to ssh-agent if not present
# - Copies public key to multiple servers

log() { echo -e "[ssh-setup] $*"; }
err() { echo -e "[ssh-setup][ERROR] $*" >&2; }

KEY_FILE="$HOME/.ssh/id_ed25519"
PUB_KEY_FILE="$HOME/.ssh/id_ed25519.pub"

# Check if key exists
if [[ ! -f "$KEY_FILE" ]]; then
    err "SSH key not found: $KEY_FILE"
    err "Generate it with: ssh-keygen -t ed25519"
    exit 1
fi

if [[ ! -f "$PUB_KEY_FILE" ]]; then
    err "Public key not found: $PUB_KEY_FILE"
    exit 1
fi

# Add key to ssh-agent if not already present
if ! ssh-add -l | grep -q "$(ssh-keygen -lf "$KEY_FILE" | awk '{print $2}')"; then
    log "Adding SSH key to agent..."
    ssh-add "$KEY_FILE"
else
    log "SSH key already in agent"
fi

# List of servers to copy key to
SERVERS=(
    "abacus-as"
    "abacus-min" 
    "nam-shub-01"
    "nam-shub-02"
    "bioint01"
    "bioint02"
    "bioint03"
    "bioint04"
    "uio"  # login node
)

log "Copying SSH key to ${#SERVERS[@]} servers..."

for server in "${SERVERS[@]}"; do
    log "Copying to $server..."
    if ssh-copy-id -i "$PUB_KEY_FILE" "$server" 2>/dev/null; then
        log "✓ Successfully copied to $server"
    else
        err "✗ Failed to copy to $server"
    fi
done

log "SSH setup complete!"
log "Test with: ssh abacus-as"
