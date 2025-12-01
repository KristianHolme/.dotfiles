#!/bin/bash

# General script to sync directories from remote machines to local machine
# Usage: ./dotfiles-rsync-ssh.sh [--source-dir DIR] [--target-dir DIR]
# Allows interactive selection of machine and multiple directories using gum

set -e # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

# Default values
SOURCE_HOST=""
SOURCE_DIR="~/Code/DRL_RDE/data/studies"
TARGET_DIR="" # Will default to SOURCE_DIR if not specified
USE_JUMP_HOST=false
DELETE_FILES=true # Use --delete by default to mirror source exactly

# Machine groups
declare -A MACHINE_GROUPS
MACHINE_GROUPS[math]="abacus-as abacus-min atalanta nam-shub-01 nam-shub-02"
MACHINE_GROUPS[lightweight]="bioint01 bioint02 bioint03 bioint04"
MACHINE_GROUPS[ml]="ml1 ml2 ml3 ml4 ml6 ml7"

# Standalone machines
STANDALONE_MACHINES=("saga" "bengal" "kaspi" "sibir")

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
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
		echo "Usage: $0 [--source-dir DIR] [--target-dir DIR]"
		echo
		echo "General script to sync directories from remote machines to local machine"
		echo
		echo "Options:"
		echo "  -s, --source-dir DIR   Remote source directory (default: ~/Code/DRL_RDE/data/studies)"
		echo "  -t, --target-dir DIR   Local target directory (default: same as source directory)"
		echo "                     Path is relative to home directory"
		echo "  --no-delete          Do not delete files in destination that don't exist in source"
		echo "                     Use this when merging files from multiple machines"
		echo "  -h, --help         Show this help message"
		echo
		echo "Examples:"
		echo "  $0                                                    # Interactive machine selection, sync studies"
		echo "  $0 --source-dir ~/Documents --target-dir ~/Backup   # Sync Documents to ~/Backup"
		echo "  $0 --no-delete                                      # Merge files without deleting"
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

# Check if gum is installed
ensure_cmd gum

# Build menu options for first level (groups + standalone machines)
FIRST_LEVEL_OPTIONS=()
for group in "${!MACHINE_GROUPS[@]}"; do
	FIRST_LEVEL_OPTIONS+=("$group (group)")
done
for machine in "${STANDALONE_MACHINES[@]}"; do
	FIRST_LEVEL_OPTIONS+=("$machine")
done

# Sort options for consistent display
IFS=$'\n' FIRST_LEVEL_OPTIONS=($(printf '%s\n' "${FIRST_LEVEL_OPTIONS[@]}" | sort))

# First level menu: select group or standalone machine with fuzzy finding
SELECTED_FIRST=$(printf '%s\n' "${FIRST_LEVEL_OPTIONS[@]}" | gum filter \
	--header "🔍 Choose a group or machine:" \
	--placeholder "Type to search..." \
	--prompt "❯ ")

if [ -z "$SELECTED_FIRST" ]; then
	echo "❌ No selection made. Exiting."
	exit 0
fi

# Determine if it's a group or standalone machine
if [[ "$SELECTED_FIRST" == *" (group)" ]]; then
	# It's a group - extract group name
	GROUP_NAME="${SELECTED_FIRST% (group)}"

	# Second level menu: select machine from group with fuzzy finding
	# Properly split the space-separated string into an array
	MACHINES_STR="${MACHINE_GROUPS[$GROUP_NAME]}"
	# Use readarray to properly split into array
	readarray -t MACHINES < <(echo "$MACHINES_STR" | tr ' ' '\n')

	SELECTED_HOST=$(printf '%s\n' "${MACHINES[@]}" | gum filter \
		--header "🔍 Choose a machine from $GROUP_NAME:" \
		--placeholder "Type to search machines..." \
		--prompt "❯ ")

	if [ -z "$SELECTED_HOST" ]; then
		echo "❌ No machine selected. Exiting."
		exit 0
	fi
	SOURCE_HOST="$SELECTED_HOST"
else
	# It's a standalone machine
	SOURCE_HOST="$SELECTED_FIRST"
fi

# Validate source host and set jump host logic
case "$SOURCE_HOST" in
atalanta | abacus-as | abacus-min | nam-shub-01 | nam-shub-02)
	USE_JUMP_HOST=false
	;;
bioint01 | bioint02 | bioint03 | bioint04)
	USE_JUMP_HOST=true
	;;
ml1 | ml2 | ml3 | ml4 | ml6 | ml7)
	USE_JUMP_HOST=false
	;;
saga)
	USE_JUMP_HOST=false
	;;
bengal | kaspi | sibir)
	USE_JUMP_HOST=false
	;;
*)
	echo "❌ Error: Unsupported host '$SOURCE_HOST'"
	exit 1
	;;
esac

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

# Get list of directories from remote (fast - no size calculation)
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
	printf '%s\n' "${dir%/}"
done
EOF
)

echo "📂 Fetching directory list..."
if [ "$USE_JUMP_HOST" = true ]; then
	DIR_LIST=$(ssh -J atalanta "$SOURCE_HOST" bash -s -- "$SOURCE_DIR" <<<"$REMOTE_DIR_LIST_SCRIPT")
else
	DIR_LIST=$(ssh "$SOURCE_HOST" bash -s -- "$SOURCE_DIR" <<<"$REMOTE_DIR_LIST_SCRIPT")
fi

if [ -z "$DIR_LIST" ]; then
	echo "❌ No directories found or unable to connect to $SOURCE_HOST:$SOURCE_DIR"
	exit 1
fi

# Parse directory list into array
DIR_ENTRY_ARRAY=()
while IFS= read -r dir_name; do
	if [ -n "$dir_name" ]; then
		DIR_ENTRY_ARRAY+=("$dir_name")
	fi
done <<<"$DIR_LIST"

if [ ${#DIR_ENTRY_ARRAY[@]} -eq 0 ]; then
	echo "❌ No directories found or unable to connect to $SOURCE_HOST:$SOURCE_DIR"
	exit 1
fi

# Use gum to let user select multiple directories
SELECTED=$(printf "%s\n" "${DIR_ENTRY_ARRAY[@]}" | gum choose --no-limit --height=15 \
	--header="Select directories to sync (Space to select, Enter to confirm):")

if [ -z "$SELECTED" ]; then
	echo "❌ No directories selected. Exiting."
	exit 0
fi

# Parse selected directories into array
FILTERED_DIRECTORIES=()
while IFS= read -r selected_line; do
	if [ -n "$selected_line" ]; then
		FILTERED_DIRECTORIES+=("$selected_line")
	fi
done <<<"$SELECTED"

# Now fetch sizes for only the selected directories (single SSH call)
echo "📊 Fetching sizes for ${#FILTERED_DIRECTORIES[@]} selected directories..."

# Build the remote script to get sizes for specific directories
REMOTE_SIZE_SCRIPT=$(
	cat <<'EOF'
set -e
SOURCE_DIR="$1"
shift
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
for dir in "$@"; do
	if [ -d "$dir" ]; then
		size=$(du -sh -- "$dir" 2>/dev/null | cut -f1)
		if [ -z "$size" ]; then
			size="?"
		fi
		printf '%s|%s\n' "$dir" "$size"
	fi
done
EOF
)

# Pass selected directories as arguments to the remote script
declare -A DIR_SIZES
if [ "$USE_JUMP_HOST" = true ]; then
	SIZE_OUTPUT=$(ssh -J atalanta "$SOURCE_HOST" bash -s -- "$SOURCE_DIR" "${FILTERED_DIRECTORIES[@]}" <<<"$REMOTE_SIZE_SCRIPT")
else
	SIZE_OUTPUT=$(ssh "$SOURCE_HOST" bash -s -- "$SOURCE_DIR" "${FILTERED_DIRECTORIES[@]}" <<<"$REMOTE_SIZE_SCRIPT")
fi

# Parse size output
while IFS='|' read -r dir_name dir_size; do
	if [ -n "$dir_name" ]; then
		dir_size=$(echo "$dir_size" | tr -d '\n')
		if [ -z "$dir_size" ]; then
			dir_size="?"
		fi
		DIR_SIZES["$dir_name"]="$dir_size"
	fi
done <<<"$SIZE_OUTPUT"

echo
echo "📦 Selected directories:"
for directory in "${FILTERED_DIRECTORIES[@]}"; do
	dir_size="${DIR_SIZES["$directory"]}"
	echo "   $directory ($dir_size)"
done
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
