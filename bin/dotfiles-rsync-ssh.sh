#!/bin/bash

# General script to sync directories from remote machines to local machine
# Usage: ./dotfiles-rsync-ssh.sh [--from HOST] [--source-dir DIR] [--target-dir DIR]
# Allows interactive selection of multiple directories using gum
# Supported hosts: atalanta (default), bioint01, bioint02, bioint03, bioint04

set -e # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

# Default values
SOURCE_HOST="atalanta"
SOURCE_DIR="~/Code/DRL_RDE/data/studies"
TARGET_DIR="" # Will default to SOURCE_DIR if not specified
USE_JUMP_HOST=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	-f | --from)
		SOURCE_HOST="$2"
		shift 2
		;;
	-s | --source-dir)
		SOURCE_DIR="$2"
		shift 2
		;;
	-t | --target-dir)
		TARGET_DIR="$2"
		shift 2
		;;
	-h | --help)
		echo "Usage: $0 [--from HOST] [--source-dir DIR] [--target-dir DIR]"
		echo
		echo "General script to sync directories from remote machines to local machine"
		echo
		echo "Options:"
		echo "  --from HOST        Source host (default: atalanta)"
		echo "                     Supported: atalanta, bioint01, bioint02, bioint03, bioint04"
		echo "  -s, --source-dir DIR   Remote source directory (default: ~/Code/DRL_RDE/data/studies)"
		echo "  -t, --target-dir DIR   Local target directory (default: same as source directory)"
		echo "                     Path is relative to home directory"
		echo "  -h, --help         Show this help message"
		echo
		echo "Examples:"
		echo "  $0                                                    # Sync studies from atalanta"
		echo "  $0 --from bioint01                                   # Sync studies from bioint01 via atalanta"
		echo "  $0 --source-dir ~/Documents --target-dir ~/Backup   # Sync Documents to ~/Backup"
		echo "  $0 --from atalanta --source-dir ~/projects --target-dir ~/local-projects"
		exit 0
		;;
	*)
		echo "Unknown option: $1"
		echo "Use --help for usage information"
		exit 1
		;;
	esac
done

# Set default target directory to source directory if not specified
if [ -z "$TARGET_DIR" ]; then
	TARGET_DIR="$SOURCE_DIR"
fi

# Validate source host and set jump host logic
case "$SOURCE_HOST" in
atalanta)
	USE_JUMP_HOST=false
	;;
bioint01 | bioint02 | bioint03 | bioint04)
	USE_JUMP_HOST=true
	;;
*)
	echo "❌ Error: Unsupported host '$SOURCE_HOST'"
	echo "Supported hosts: atalanta, bioint01, bioint02, bioint03, bioint04"
	exit 1
	;;
esac

# Check if gum is installed
ensure_cmd gum

# Expand tilde in paths
SOURCE_DIR_EXPANDED="${SOURCE_DIR/#\~/$HOME}"
TARGET_DIR_EXPANDED="${TARGET_DIR/#\~/$HOME}"

REMOTE_DIR="${SOURCE_HOST}:${SOURCE_DIR}"

# Set up SSH command based on whether we need jump host
if [ "$USE_JUMP_HOST" = true ]; then
	SSH_CMD="ssh -J atalanta"
	RSYNC_SSH_OPTS="-e ssh -J atalanta"
	echo "🔍 Fetching available directories from $SOURCE_HOST:$SOURCE_DIR (via atalanta)..."
else
	SSH_CMD="ssh"
	RSYNC_SSH_OPTS=""
	echo "🔍 Fetching available directories from $SOURCE_HOST:$SOURCE_DIR..."
fi

# Get list of directories from remote
if [ "$USE_JUMP_HOST" = true ]; then
	DIRECTORIES=$(ssh -J atalanta "$SOURCE_HOST" "ls -1 $SOURCE_DIR 2>/dev/null || echo ''")
else
	DIRECTORIES=$(ssh "$SOURCE_HOST" "ls -1 $SOURCE_DIR 2>/dev/null || echo ''")
fi

if [ -z "$DIRECTORIES" ]; then
	echo "❌ No directories found or unable to connect to $SOURCE_HOST:$SOURCE_DIR"
	exit 1
fi

# Use gum to let user select multiple directories
SELECTED=$(echo "$DIRECTORIES" | gum choose --no-limit --height=15 \
	--header="Select directories to sync (Space to select, Enter to confirm):")

if [ -z "$SELECTED" ]; then
	echo "❌ No directories selected. Exiting."
	exit 0
fi

echo
echo "📦 Selected directories:"
echo "$SELECTED"
echo
echo "📍 Source: $SOURCE_HOST:$SOURCE_DIR"
echo "📍 Target: $TARGET_DIR_EXPANDED"
if [ "$USE_JUMP_HOST" = true ]; then
	echo "🌉 Via jump host: atalanta"
fi
echo

# Confirm before proceeding
if ! gum confirm "Proceed with syncing these directories?"; then
	echo "❌ Sync cancelled."
	exit 0
fi

echo
echo "🚀 Starting sync process..."

# Convert to array for reliable counting and iteration
readarray -t DIRECTORY_ARRAY <<<"$SELECTED"
# Filter out empty entries
FILTERED_DIRECTORIES=()
for dir in "${DIRECTORY_ARRAY[@]}"; do
	if [ -n "$dir" ]; then
		FILTERED_DIRECTORIES+=("$dir")
	fi
done

DIRECTORY_COUNT=${#FILTERED_DIRECTORIES[@]}
CURRENT_DIR=0

# Sync each selected directory
for directory in "${FILTERED_DIRECTORIES[@]}"; do
	CURRENT_DIR=$((CURRENT_DIR + 1))
	SOURCE="${REMOTE_DIR}/${directory}"
	DEST="${TARGET_DIR_EXPANDED}/${directory}"

	echo
	echo "📂 [$CURRENT_DIR/$DIRECTORY_COUNT] Syncing: $directory"
	echo "   From: $SOURCE"
	if [ "$USE_JUMP_HOST" = true ]; then
		echo "   Via: atalanta (jump host)"
	fi
	echo "   To: $DEST"
	echo

	# Create local directory if it doesn't exist
	mkdir -p "$DEST"

	# Run rsync with minimal output (overall progress only)
	if [ "$USE_JUMP_HOST" = true ]; then
		rsync -az --delete --info=progress2 --no-inc-recursive -e "ssh -J atalanta" "${SOURCE}/" "${DEST}/"
	else
		rsync -az --delete --info=progress2 --no-inc-recursive "${SOURCE}/" "${DEST}/"
	fi

	echo "✅ [$CURRENT_DIR/$DIRECTORY_COUNT] Completed: $directory"
done

echo
if [ "$USE_JUMP_HOST" = true ]; then
	echo "🎉 All syncs from $SOURCE_HOST:$SOURCE_DIR (via atalanta) completed successfully!"
else
	echo "🎉 All syncs from $SOURCE_HOST:$SOURCE_DIR completed successfully!"
fi
echo "📁 Files synced to: $TARGET_DIR_EXPANDED"
