#!/bin/bash
set -Eeuo pipefail

# Firefly III restore script
# Restores from a backup directory produced by dotfiles-firefly-backup.sh
# Usage: dotfiles-firefly-restore.sh <BACKUP_DIR>

log() { echo -e "[firefly-restore] $*"; }
err() { echo -e "[firefly-restore][ERROR] $*" >&2; }

FIRE3_HOME="${FIRE3_HOME:-$HOME/Firefly3}"
COMPOSE_FILE="$FIRE3_HOME/docker-compose.yml"
DB_ENV_FILE="$FIRE3_HOME/.db.env"
CONTAINER_DB="${FIREFLY_DB_CONTAINER:-firefly_iii_db}"

SRC_DIR="${1:-}"
if [[ -z "$SRC_DIR" ]]; then
  err "Provide the backup directory path (e.g., ~/Firefly3/backup/<timestamp>)"
  exit 1
fi
if [[ ! -d "$SRC_DIR" ]]; then
  err "Backup directory not found: $SRC_DIR"
  exit 1
fi

require() { command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }; }
require docker
require tar

FILES_ARCHIVE="$SRC_DIR/firefly3_files.tgz"
DB_DUMP="$SRC_DIR/firefly_db.sql"

if [[ ! -f "$DB_DUMP" ]]; then
  err "Database dump not found at $DB_DUMP"
  exit 1
fi

###########
# Restore files (if compose/env missing, extract first)
###########
if [[ ! -f "$COMPOSE_FILE" || ! -f "$DB_ENV_FILE" ]]; then
  if [[ -f "$FILES_ARCHIVE" ]]; then
    log "Extracting files archive to $FIRE3_HOME"
    mkdir -p "$FIRE3_HOME"
    tar -xzf "$FILES_ARCHIVE" -C "$FIRE3_HOME"
  else
    err "Compose/env missing and files archive not found: $FILES_ARCHIVE"
    exit 1
  fi
fi

# Re-evaluate paths after potential extraction
COMPOSE_FILE="$FIRE3_HOME/docker-compose.yml"
DB_ENV_FILE="$FIRE3_HOME/.db.env"
if [[ ! -f "$COMPOSE_FILE" ]]; then
  err "Compose file still not found after extraction: $COMPOSE_FILE"
  exit 1
fi
if [[ ! -f "$DB_ENV_FILE" ]]; then
  err "DB env file still not found after extraction: $DB_ENV_FILE"
  exit 1
fi

# Load DB credentials from .db.env
# shellcheck disable=SC1090
set -a; source "$DB_ENV_FILE"; set +a || true
DB_USER="${MYSQL_USER:-firefly}"
DB_NAME="${MYSQL_DATABASE:-firefly}"
DB_PASS="${MYSQL_PASSWORD:-}"
if [[ -z "$DB_PASS" ]]; then
  err "MYSQL_PASSWORD not set in $DB_ENV_FILE"
  exit 1
fi

###########
# Bring up DB and restore dump
###########
log "Starting DB container via docker compose"
(cd "$FIRE3_HOME" && docker compose -f "$COMPOSE_FILE" up -d db)

# Wait for DB to be ready
log "Waiting for database readiness..."
for i in {1..60}; do
  if docker exec "$CONTAINER_DB" mariadb -u"$DB_USER" --password="${DB_PASS}" -e "SELECT 1" "$DB_NAME" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! docker exec "$CONTAINER_DB" mariadb -u"$DB_USER" --password="${DB_PASS}" -e "SELECT 1" "$DB_NAME" >/dev/null 2>&1; then
  err "Database not ready after waiting; cannot restore."
  exit 1
fi

log "Restoring database $DB_NAME into $CONTAINER_DB"
cat "$DB_DUMP" | docker exec -i "$CONTAINER_DB" mariadb -u"$DB_USER" --password="$DB_PASS" "$DB_NAME"

###########
# Start full stack
###########
log "Starting full stack"
(cd "$FIRE3_HOME" && docker compose -f "$COMPOSE_FILE" up -d)

log "Restore completed from $SRC_DIR"


