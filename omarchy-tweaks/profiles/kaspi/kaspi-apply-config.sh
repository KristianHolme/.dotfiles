#!/bin/bash
set -euo pipefail

# Kaspi profile setup script
# Run after stow to handle system-level configs

echo "[kaspi] Setting up power button (suspend on press)"

# Create systemd logind drop-in config
sudo mkdir -p /etc/systemd/logind.conf.d
echo '[Login]
HandlePowerKey=suspend' | sudo tee /etc/systemd/logind.conf.d/power-button.conf >/dev/null

# Restart logind to apply changes
sudo systemctl restart systemd-logind

echo "[kaspi] Power button configured for suspend"
