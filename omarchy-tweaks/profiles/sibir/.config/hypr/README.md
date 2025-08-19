# Sibir Profile Monitor Configurations

This profile provides two monitor configuration options for your specific desk setup:

## Your Monitor Setup

Based on your `hyprctl monitors all` output:
- **eDP-1**: 2560x1440@60 (BOE 0x0AFE) - Laptop display
- **DP-1**: 1920x1080@120 (Dell U2424HE) - Main monitor 
- **HDMI-A-1**: 1920x1080@60 (Dell U2419H) - Side monitor

## Configuration Files

### 1. `monitors-1.conf` + `tiling-1.conf` - Basic Setup
- **Description**: Basic Monitor Setup for Sibir Profile
- Simple configuration for single monitor or basic multi-monitor use
- Uses 1x scaling for all displays
- Standard workspace behavior (1-10 on any monitor)

### 2. `monitors-2.conf` + `tiling-2.conf` - Office Desk Setup  
- **Description**: Office Desk Setup for Sibir Profile
- Precise configuration for your specific desk monitors:
  - **DP-1** (Dell U2424HE): Main monitor at 120Hz, positioned at 0x0
  - **HDMI-A-1** (Dell U2419H): Side monitor, rotated 90° clockwise, positioned to right
  - **eDP-1** (BOE): Laptop display positioned to the left of main monitor
- Multi-monitor workspace management with specific keybindings

## Workspace Layout (Office Setup)

- **Workspaces 1-6**: Main monitor (DP-1) - SUPER+[1-6]
- **Workspaces 7-9**: Side monitor (HDMI-A-1) - SUPER+[7-9]
- **Workspace 10**: Laptop display (eDP-1) - SUPER+0 (for btop)

All workspaces use standard keybindings - no special modifier keys needed.

## Monitor Positioning (Office Setup)

```
┌─────────────────┐ ┌─────────────────────────┐ ┌──────┐ 
│                 │ │                         │ │      │ ← HDMI-A-1 (1920x1080@60, rotated 90°)
│ Laptop Display  │ │     Main Monitor        │ │ Side │   Position: 1920x-420
│  eDP-1 (btop)   │ │    DP-1 (120Hz)         │ │ Mon. │   Transform: 1 (90° clockwise)
│                 │ │                         │ │      │   
└─────────────────┘ └─────────────────────────┘ └──────┘
Position: -1600x0   Position: 0x0              Position: 1920x-420
Workspace: 10       Workspaces: 1-6            Workspaces: 7-9
```

## Switching Between Configurations

Use the switching script:

```bash
# Show available configurations and select interactively
/home/kristian/.dotfiles/omarchy-tweaks/bin/dotfiles-switch-monitors.sh sibir
```

This will:
1. Show available monitor configurations (1: Basic, 2: Office Desk)
2. Present them as choices using gum (if installed)
3. Symlink the selected configs to `~/.config/hypr/monitors.conf` and `tiling.conf` 
4. Reload Hyprland configuration

## Manual Switching (Alternative)

If you prefer manual control:

```bash
# Switch to basic setup
ln -sf /home/kristian/.dotfiles/omarchy-tweaks/profiles/sibir/.config/hypr/monitors-1.conf ~/.config/hypr/monitors.conf
ln -sf /home/kristian/.dotfiles/omarchy-tweaks/profiles/sibir/.config/hypr/tiling-1.conf ~/.config/hypr/tiling.conf

# Switch to office desk setup  
ln -sf /home/kristian/.dotfiles/omarchy-tweaks/profiles/sibir/.config/hypr/monitors-2.conf ~/.config/hypr/monitors.conf
ln -sf /home/kristian/.dotfiles/omarchy-tweaks/profiles/sibir/.config/hypr/tiling-2.conf ~/.config/hypr/tiling.conf

# Reload Hyprland
hyprctl reload
```

## Notes

- The office setup uses display descriptions for precise detection of your specific monitors
- If gum is not installed, the script will auto-select a configuration
- Install gum for interactive selection: `pacman -S gum`
- Restart Hyprland (Super+Esc → Relaunch) if monitors aren't detected properly
