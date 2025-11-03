#!/bin/bash

# General script to sync directories from remote machines to local machine
# Usage: ./dotfiles-rsync-ssh.sh [--from HOST] [--source-dir DIR] [--target-dir DIR]
# Allows interactive selection of multiple directories using gum
# Supported hosts: atalanta (default), bioint01, bioint02, bioint03, bioint04, bengal, kaspi, sibir

set -e # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

# Default values
SOURCE_HOST="atalanta"
SOURCE_DIR="~/Code/DRL_RDE/data/studies"
TARGET_DIR="" # Will default to SOURCE_DIR if not specified
USE_JUMP_HOST=false
DELETE_FILES=true # Use --delete by default to mirror source exactly

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
    --no-delete)
        DELETE_FILES=false
        shift
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
        echo "  --no-delete          Do not delete files in destination that don't exist in source"
        echo "                     Use this when merging files from multiple machines"
        echo "  -h, --help         Show this help message"
        echo
        echo "Examples:"
        echo "  $0                                                    # Sync studies from atalanta"
        echo "  $0 --from bioint01                                   # Sync studies from bioint01 via atalanta"
        echo "  $0 --source-dir ~/Documents --target-dir ~/Backup   # Sync Documents to ~/Backup"
        echo "  $0 --from atalanta --source-dir ~/projects --target-dir ~/local-projects"
        echo "  $0 --no-delete --from machine1                      # Merge files from machine1 without deleting"
        echo "  $0 --no-delete --from machine2                      # Then merge files from machine2, keeping both"
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
bengal | kaspi | sibir)
    USE_JUMP_HOST=false
    ;;
*)
    echo "❌ Error: Unsupported host '$SOURCE_HOST'"
    echo "Supported hosts: atalanta, bioint01, bioint02, bioint03, bioint04, bengal, kaspi, sibir"
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

# Get list of directories and their sizes from remote
REMOTE_DIR_LIST_SCRIPT=$(
    cat <<'EOF'
set -e
SOURCE_DIR="$1"
if [ -z "$SOURCE_DIR" ]; then
	exit 0
fi
case "$SOURCE_DIR" in
	~*)
		if [ -n "$HOME" ]; then
			SOURCE_DIR="${HOME}${SOURCE_DIR:1}"
		fi
		;;
esac
if ! cd "$SOURCE_DIR" 2>/dev/null; then
	exit 0
fi
shopt -s nullglob dotglob
for dir in */; do
	[ -d "$dir" ] || continue
	size=$(du -sh -- "$dir" 2>/dev/null | cut -f1)
	if [ -z "$size" ]; then
		size="?"
	fi
	dir="${dir%/}"
	printf '%s\t%s\n' "$dir" "$size"
done
EOF
)

if [ "$USE_JUMP_HOST" = true ]; then
    DIR_ENTRIES=$(ssh -J atalanta "$SOURCE_HOST" bash -s -- "$SOURCE_DIR" <<<"$REMOTE_DIR_LIST_SCRIPT")
else
    DIR_ENTRIES=$(ssh "$SOURCE_HOST" bash -s -- "$SOURCE_DIR" <<<"$REMOTE_DIR_LIST_SCRIPT")
fi

if [ -z "$DIR_ENTRIES" ]; then
    echo "❌ No directories found or unable to connect to $SOURCE_HOST:$SOURCE_DIR"
    exit 1
fi

declare -A DISPLAY_TO_DIR
declare -A DIR_SIZES

mapfile -t DIR_ENTRY_ARRAY <<<"$DIR_ENTRIES"

DISPLAY_LINES=()
for entry in "${DIR_ENTRY_ARRAY[@]}"; do
    if [ -z "$entry" ]; then
        continue
    fi
    dir_name="${entry%%$'\t'*}"
    dir_size="${entry#*$'\t'}"
    if [ -z "$dir_name" ]; then
        continue
    fi
    if [ "$dir_size" = "$entry" ] || [ -z "$dir_size" ]; then
        dir_size="?"
    fi
    display_line="$dir_name ($dir_size)"
    DISPLAY_LINES+=("$display_line")
    DISPLAY_TO_DIR["$display_line"]="$dir_name"
    DIR_SIZES["$dir_name"]="$dir_size"
done

if [ ${#DISPLAY_LINES[@]} -eq 0 ]; then
    echo "❌ No directories found or unable to connect to $SOURCE_HOST:$SOURCE_DIR"
    exit 1
fi

# Use gum to let user select multiple directories with sizes displayed
SELECTED=$(printf "%s\n" "${DISPLAY_LINES[@]}" | gum choose --no-limit --height=15 \
    --header="Select directories to sync (Space to select, Enter to confirm):")

if [ -z "$SELECTED" ]; then
    echo "❌ No directories selected. Exiting."
    exit 0
fi

echo
echo "📦 Selected directories:"
while IFS= read -r line; do
    dir_name="${DISPLAY_TO_DIR["$line"]}"
    if [ -n "$dir_name" ]; then
        dir_size="${DIR_SIZES["$dir_name"]}"
        echo "$dir_name ($dir_size)"
    fi
done <<<"$SELECTED"
echo
echo "📍 Source: $SOURCE_HOST:$SOURCE_DIR"
echo "📍 Target: $TARGET_DIR_EXPANDED"
if [ "$USE_JUMP_HOST" = true ]; then
    echo "🌉 Via jump host: atalanta"
fi
if [ "$DELETE_FILES" = false ]; then
    echo "⚠️  Merge mode: files will not be deleted (merging from multiple machines)"
fi
echo

# Confirm before proceeding
if ! gum confirm "Proceed with syncing these directories?"; then
    echo "❌ Sync cancelled."
    exit 0
fi

# Prompt user about deleting files if not explicitly set with --no-delete
if [ "$DELETE_FILES" = true ]; then
    echo
    if gum confirm --default=false \
        --affirmative="Yes, delete files not on server" \
        --negative="No, keep all existing files (merge mode)" \
        "Delete files in destination that don't exist on $SOURCE_HOST?"; then
        DELETE_FILES=true
        echo "ℹ️  Delete mode: files will be deleted to match server exactly"
    else
        DELETE_FILES=false
        echo "ℹ️  Merge mode: files will not be deleted (safe for multiple machines)"
    fi
fi

echo
echo "🚀 Starting sync process..."

FILTERED_DIRECTORIES=()
while IFS= read -r line; do
    dir_name="${DISPLAY_TO_DIR["$line"]}"
    if [ -n "$dir_name" ]; then
        FILTERED_DIRECTORIES+=("$dir_name")
    fi
done <<<"$SELECTED"

DIRECTORY_COUNT=${#FILTERED_DIRECTORIES[@]}
CURRENT_DIR=0

# Sync each selected directory
for directory in "${FILTERED_DIRECTORIES[@]}"; do
    CURRENT_DIR=$((CURRENT_DIR + 1))
    SOURCE="${REMOTE_DIR}/${directory}"
    DEST="${TARGET_DIR_EXPANDED}/${directory}"

    echo
    dir_size="${DIR_SIZES["$directory"]}"
    echo "📂 [$CURRENT_DIR/$DIRECTORY_COUNT] Syncing: $directory ($dir_size)"
    echo "   From: $SOURCE"
    if [ "$USE_JUMP_HOST" = true ]; then
        echo "   Via: atalanta (jump host)"
    fi
    echo "   To: $DEST"
    echo

    # Create local directory if it doesn't exist
    mkdir -p "$DEST"

    # Build rsync command with optional --delete flag
    RSYNC_DELETE_FLAG=""
    if [ "$DELETE_FILES" = true ]; then
        RSYNC_DELETE_FLAG="--delete"
    fi

    # Run rsync with minimal output (overall progress only)
    if [ "$USE_JUMP_HOST" = true ]; then
        rsync -az $RSYNC_DELETE_FLAG --info=progress2 --no-inc-recursive -e "ssh -J atalanta" "${SOURCE}/" "${DEST}/"
    else
        rsync -az $RSYNC_DELETE_FLAG --info=progress2 --no-inc-recursive "${SOURCE}/" "${DEST}/"
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
