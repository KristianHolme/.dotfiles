# Omarchy Tweaks

Simple Stow-based configuration overlay for Omarchy setups (Hyprland, Neovim, shell, etc.).

## Structure

```
omarchy-tweaks/
├── bin/
│   ├── dotfiles-apply-config.sh   # Link `config/` → ~/.config and `home/` → ~ (via GNU Stow)
│   ├── dotfiles-setup-packages.sh # Remove Omarchy defaults, install preferred packages/tools (Arch/yay)
│   └── julia-setup.jl             # Install common Julia packages + copy startup.jl
├── config/                        # links into ~/.config/
├── home/                          # Optional home-level files (links into ~)
└── README.md
```

## Usage

### Apply your tweaks (symlink with Stow)
```bash
~/.dotfiles/omarchy-tweaks/bin/dotfiles-apply-config.sh
```

This links the Stow packages:
- `config/` → `~/.config`
- `home/` → `~/` (for dotfiles like `.zshrc`, if present)

Preview (no changes):
```bash
stow -n -d ~/.dotfiles/omarchy-tweaks -t ~/.config -v config
stow -n -d ~/.dotfiles/omarchy-tweaks -t ~ -v home
```

### Prune defaults and install your apps (Arch/Omarchy)
```bash
~/.dotfiles/omarchy-tweaks/bin/dotfiles-setup-packages.sh
```
- Removes selected Omarchy webapps and packages
- Installs preferred packages via `yay`
- Optional installers via `curl` (e.g., Julia `juliaup`, Cursor CLI)

### Edit your configuration
Edit files under `config/` and re-run the apply script. Hyprland changes will be reloaded automatically if `hyprctl` is available.

### Restore Omarchy defaults
Example (Hypr bindings):
```bash
~/.local/share/omarchy/bin/omarchy-refresh-config hypr/bindings.conf
```

## Requirements
- GNU Stow (for linking configs)
- Arch with `yay` (for the package setup script)
- `curl` (for optional installers)
- Hyprland (only if you want the Hypr configs; the apply script tries to `hyprctl reload` if present)

## Features

### Custom Keybindings (Hyprland)
- Window resizing: `SUPER + minus/plus` (left-right), `SUPER + SHIFT + minus/plus` (up-down)
- Floating window movement: `SUPER + SHIFT + arrows`
- Quick app launchers (browser, terminal, Obsidian, Spotify, etc.) via UWSM
- Workspace rules (e.g., `cursor` → workspace 2, `obsidian` → workspace 9)

## How it works
1. `dotfiles-apply-config.sh` backs up conflicting files into a timestamped `_bak/` folder, then symlinks Stow packages:
   - `config/` → `~/.config/`
   - `home/` → `~/`
2. If Hyprland is running, it reloads the configuration.
3. `dotfiles-setup-packages.sh` prunes selected defaults and installs preferred packages/tools via `yay`.

## Notes
- Hyprland env vars (`envs.conf`) extend your `PATH` to include Omarchy tools; env changes require a Hyprland relaunch to take effect.
