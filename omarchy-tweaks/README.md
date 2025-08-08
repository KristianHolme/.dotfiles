# Omarchy Tweaks

Simple configuration management for your Omarchy customizations.

## Structure

```
omarchy-tweaks/
├── bin/
│   ├── apply-tweaks.sh            # Apply config tweaks (rsync only-existing)
│   └── omarchy-prune-and-install.sh  # Remove defaults + install your packages/webapps
├── config/
│   └── hypr/
│       └── bindings.conf          # Your custom bindings
└── README.md
```

## Usage

### Apply your tweaks
```bash
~/.dotfiles/omarchy-tweaks/bin/apply-tweaks.sh
```

### Prune defaults and install your apps
```bash
~/.dotfiles/omarchy-tweaks/bin/omarchy-prune-and-install.sh
```

### Edit your configuration
Simply edit the files in `config/` and re-run the apply script.

### Restore defaults
To restore omarchy defaults:
```bash
~/.local/share/omarchy/bin/omarchy-refresh-config hypr/bindings.conf
```

## Features

### Custom Keybindings
- Window resizing with `SUPER + minus/plus`
- Floating window movement with `SUPER + SHIFT + arrows`

## How it works

1. `apply-tweaks.sh` syncs from `config/` → `~/.config/` using rsync with `--existing` (only updates files that already exist)
2. Reloads Hyprland configuration

Simple and clean! Works with standard Omarchy features.

## Manual edits
- Change cursor desktop file to include "--ozone-platform=wayland"
    - probably in /usr/local/share/applications



## Workspace habits
1. Terminal(s)
2. Cursor
3. Browser

9. Obsidian