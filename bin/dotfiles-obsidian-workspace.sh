#!/bin/bash

# Script to launch Obsidian or switch to its workspace if already running
# This handles the fact that Obsidian shows up as "electron" in process lists

# Check if Obsidian is running by looking for:
# 1. Process with obsidian app.asar in the command line
# 2. Hyprland window with obsidian class
is_obsidian_running() {
	# Check for obsidian process (electron running obsidian app.asar)
	if pgrep -f "/usr/lib/obsidian/app.asar" >/dev/null 2>&1; then
		return 0
	fi

	# Check for obsidian window class in Hyprland (more reliable)
	if hyprctl clients | grep -q "class: obsidian"; then
		return 0
	fi

	return 1
}

if is_obsidian_running; then
	# Obsidian is running, switch to workspace O
	hyprctl dispatch workspace name:O
else
	# Obsidian is not running, launch it
	uwsm app -- obsidian --disable-gpu
fi
