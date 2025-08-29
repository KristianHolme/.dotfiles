# Omarchy Tweaks

Simple Stow-based configuration overlay for Omarchy setups (Hyprland, Neovim, shell, etc.).

## Structure

```
omarchy-tweaks/
├── bin/                          # Utility scripts
│   ├── dotfiles-apply-config.sh  # Link configurations via GNU Stow
│   ├── dotfiles-setup-packages.sh # Package management (remove defaults, install tools)
│   ├── julia-setup.jl           # Julia package installer
│   ├── dotfiles-ssh-tmux.sh     # Interactive SSH connection with tmux
│   ├── dotfiles-rsync-ssh.sh    # Remote directory sync tool
│   ├── dotfiles-setup-ssh.sh    # SSH key setup and distribution
│   ├── dotfiles-setup-zotero.sh # Zotero Better BibTeX extension installer
│   ├── dotfiles-power-suspend.sh # Configure power button for suspend
│   ├── dotfiles-powerprofiles-menu.sh # Interactive power profile switcher
│   ├── dotfiles-firefly-backup.sh # Firefly III backup utility
│   └── dotfiles-firefly-restore.sh # Firefly III restore utility
├── default/                      # Default configuration package
├── <profile>/                    # Profile-specific packages (bengal, kaspi, sibir, etc.)
└── README.md
```

## Core Scripts

### Configuration Management

#### Apply your tweaks (symlink with Stow)
```bash
~/.dotfiles/bin/dotfiles-apply-config.sh
```

Links the Stow packages using GNU Stow with intelligent conflict detection:
- `default/` → `~/` (includes dotfiles for `.config/`, home files, etc.)
- Profile-specific overlays when specified

**With profile support:**
```bash
~/.dotfiles/bin/dotfiles-apply-config.sh bengal
```

**Preview mode (dry run):**
```bash
stow -n -d ~/.dotfiles/omarchy-tweaks -t ~ -v default
```

Features:
- Interactive conflict resolution using `gum`
- Automatic Hyprland configuration reload
- Profile switching with overlay support

#### Package Management
```bash
~/.dotfiles/bin/dotfiles-setup-packages.sh
```

Comprehensive package management for Omarchy systems:
- **Removes:** Selected Omarchy webapps (HEY, Basecamp, WhatsApp, etc.)
- **Installs:** Essential tools (zotero-bin, cursor-bin, discord, tmux, etc.)
- **Sets up:** Julia environment, tmux plugin manager, Zotero extensions
- **Configures:** LaTeX distribution (texlive-meta)

#### Edit your configuration
Edit files under profile directories and re-run the apply script. Hyprland changes are reloaded automatically.

#### Restore Omarchy defaults
```bash
~/.local/share/omarchy/bin/omarchy-refresh-config hypr/bindings.conf
```

### Development Environment

#### Julia Environment Setup
```bash
~/.dotfiles/bin/julia-setup.jl
```

Installs essential Julia packages to your global environment:
- **Development:** Revise, Debugger, Cthulhu, PkgTemplates
- **Performance:** BenchmarkTools, BasicAutoloads
- **Utilities:** DrWatson, ProgressMeter, OhMyREPL, Reexport

## Remote Access & Sync

### SSH Connection with tmux
```bash
~/.dotfiles/bin/dotfiles-ssh-tmux.sh
```

Interactive SSH connection manager with automatic tmux session handling:
- **Server selection:** Choose from predefined servers using fuzzy finder
- **Session management:** Automatically attaches to existing tmux sessions or creates new ones
- **Servers supported:** atalanta, abacus-as, abacus-min, nam-shub-01/02, bioint01-04

### Directory Synchronization
```bash
# Basic usage - sync studies from atalanta
~/.dotfiles/bin/dotfiles-rsync-ssh.sh

# Sync from different host
~/.dotfiles/bin/dotfiles-rsync-ssh.sh --from bioint01

# Custom directories
~/.dotfiles/bin/dotfiles-rsync-ssh.sh \
  --source-dir ~/projects \
  --target-dir ~/local-backup

# Full example
~/.dotfiles/bin/dotfiles-rsync-ssh.sh \
  --from atalanta \
  --source-dir ~/Code/DRL_RDE/data/studies \
  --target-dir ~/synced-studies
```

Features:
- **Interactive selection:** Choose multiple directories to sync
- **Jump host support:** Automatic routing through atalanta for bioint servers
- **Progress tracking:** Real-time sync progress with numbered operations
- **Safe syncing:** Uses `rsync` with delete protection and incremental transfers

### SSH Key Management
```bash
~/.dotfiles/bin/dotfiles-setup-ssh.sh
```

Automated SSH key distribution:
- **Key validation:** Checks for existing ed25519 key
- **Agent management:** Adds key to ssh-agent if not present
- **Multi-server setup:** Copies public key to all configured servers
- **Servers:** abacus-as/min, nam-shub-01/02, bioint01-04, uio

## Application Setup

### Zotero Better BibTeX Extension
```bash
~/.dotfiles/bin/dotfiles-setup-zotero.sh
```

Automated Zotero extension installer:
- **Latest version:** Downloads current Better BibTeX release from GitHub
- **Safe download:** Validates file integrity before installation
- **User guidance:** Provides step-by-step manual installation instructions

Note: Manual installation through Zotero GUI is required for proper extension registration.

## System Configuration

### Power Management
```bash
# Configure power button for suspend
~/.dotfiles/bin/dotfiles-power-suspend.sh

# Interactive power profile switcher
~/.dotfiles/bin/dotfiles-powerprofiles-menu.sh
```

**Power button configuration:**
- Creates systemd logind drop-in configuration
- Options: reboot system, restart services, or apply on next reboot

**Power profile menu:**
- Interactive selection using `walker` with dmenu theme
- Integrates with `powerprofilesctl` for profile switching

## Backup & Restore

### Firefly III Database Management
```bash
# Create backup
~/.dotfiles/bin/dotfiles-firefly-backup.sh

# Create backup to specific directory
~/.dotfiles/bin/dotfiles-firefly-backup.sh ~/my-backup-location

# Restore from backup
~/.dotfiles/bin/dotfiles-firefly-restore.sh ~/Firefly3/backup/20240120-143022
```

**Backup features:**
- **Complete backup:** Files (tarball) + MariaDB database dump
- **Timestamped:** Automatic backup directory naming
- **Configurable:** Custom backup destinations supported

**Restore features:**
- **Full restoration:** Database + configuration files
- **Docker integration:** Automatic container management
- **Validation:** Checks backup integrity before restoration

## Requirements
- GNU Stow (for linking configs)
- `gum` (for interactive conflict resolution - install with `pacman -S gum`)
   - `gum` is installed by default in [Omarchy](https://omarchy.org)
- Arch with `yay` (for the package setup script)
- `curl` (for optional installers)
- Hyprland (only if you want the Hypr configs; the apply script tries to `hyprctl reload` if present)
- `rsync` (for directory synchronization)
- `docker` and `docker-compose` (for Firefly III backup/restore)
- `walker` (for power profile menu)
- `powerprofilesctl` (for power management)

## Features

### Custom Hyprland Configuration
- **Window management:** Enhanced resizing with `SUPER + minus/plus` (horizontal) and `SUPER + SHIFT + minus/plus` (vertical)
- **Floating windows:** `SUPER + SHIFT + arrows` for precise positioning
- **Quick launchers:** Fast app access (browser, terminal, Obsidian, Spotify, etc.) via UWSM
- **Workspace rules:** Automatic app placement (e.g., `cursor` → workspace 2, `obsidian` → workspace 9)
- **Environment extension:** Includes Omarchy tools in `PATH` via `envs.conf`

### Profile System
- **Multiple profiles:** Support for different configurations (bengal, kaspi, sibir, etc.)
- **Overlay architecture:** Profile-specific files override defaults while preserving base configuration
- **Easy switching:** Change profiles with a single command argument

### Interactive Tools
- **Conflict resolution:** Smart handling of existing dotfiles with user choice prompts
- **Server selection:** Fuzzy-finding interface for SSH connections
- **Multi-selection:** Choose multiple directories for synchronization
- **Progress tracking:** Real-time feedback for long-running operations

## How It Works

The configuration system uses a layered approach:

1. **Base layer:** `default/` package provides core configurations
2. **Profile layer:** Optional profile packages (e.g., `bengal/`) overlay the base
3. **Conflict detection:** Dry-run analysis before applying changes
4. **Interactive resolution:** User choice for handling conflicts:
   - **Adopt:** Move existing files to dotfiles repo (via `stow --adopt`)
   - **Abort:** Keep existing files, skip linking
5. **Automatic reload:** Hyprland configuration refreshes after changes

## Notes

- **Environment variables:** Changes to Hyprland's `envs.conf` require a full Hyprland restart to take effect
- **Profile isolation:** Each profile can completely override base configurations using `--override` flag
- **Backup safety:** All backup operations include integrity validation before restoration
- **Jump host routing:** Bioint servers are automatically accessed through atalanta gateway
