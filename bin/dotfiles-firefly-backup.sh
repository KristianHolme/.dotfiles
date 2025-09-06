#!/bin/bash
set -Eeuo pipefail

# Firefly III backup script
# - Backs up configs from ~/Firefly3 (as a tarball)
# - Dumps the MariaDB database from container firefly_iii_db
# Usage: dotfiles-firefly-backup.sh [DEST_DIR]
# - If DEST_DIR not provided, defaults to ~/Firefly3/backup/<timestamp>

log() { echo -e "[firefly-backup] $*"; }
err() { echo -e "[firefly-backup][ERROR] $*" >&2; }

timestamp() { date +"%Y%m%d-%H%M%S"; }

FIRE3_HOME="${FIRE3_HOME:-$HOME/Firefly3}"
COMPOSE_FILE="$FIRE3_HOME/docker-compose.yml"
DB_ENV_FILE="$FIRE3_HOME/.db.env"
CONTAINER_DB="${FIREFLY_DB_CONTAINER:-firefly_iii_db}"

DEST_INPUT="${1:-}"
if [[ -z "$DEST_INPUT" ]]; then
	DEST_ROOT="$FIRE3_HOME/backup"
	mkdir -p "$DEST_ROOT"
	DEST_DIR="$DEST_ROOT/$(timestamp)"
else
	# Use provided path; if it's a directory, create timestamped subdir
	if [[ -d "$DEST_INPUT" ]]; then
		DEST_DIR="$DEST_INPUT/$(timestamp)"
	else
		DEST_DIR="$DEST_INPUT"
	fi
fi
mkdir -p "$DEST_DIR"

require() { command -v "$1" >/dev/null 2>&1 || {
	err "Missing command: $1"
	exit 1
}; }

require docker
require tar

if [[ ! -f "$COMPOSE_FILE" ]]; then
	err "Compose file not found: $COMPOSE_FILE"
	exit 1
fi

# Load DB credentials from .db.env (compose uses this file)
if [[ ! -f "$DB_ENV_FILE" ]]; then
	err "DB env file not found: $DB_ENV_FILE"
	exit 1
fi
# shellcheck disable=SC1090
set -a
source "$DB_ENV_FILE"
set +a || true
DB_USER="${MYSQL_USER:-firefly}"
DB_NAME="${MYSQL_DATABASE:-firefly}"
DB_PASS="${MYSQL_PASSWORD:-}"
if [[ -z "$DB_PASS" ]]; then
	err "MYSQL_PASSWORD not set in $DB_ENV_FILE"
	exit 1
fi

log "Backing up Firefly3 files from $FIRE3_HOME → $DEST_DIR"

# Create configs tarball (exclude backup dir itself)
tar --exclude "backup" -C "$FIRE3_HOME" -czf "$DEST_DIR/firefly3_files.tgz" .

# Dump database
DB_DUMP="$DEST_DIR/firefly_db.sql"
log "Dumping database $DB_NAME from container $CONTAINER_DB"
docker exec "$CONTAINER_DB" mariadb-dump -u"$DB_USER" --password="$DB_PASS" "$DB_NAME" >"$DB_DUMP"

log "Backup completed at $DEST_DIR"
echo "$DEST_DIR"
