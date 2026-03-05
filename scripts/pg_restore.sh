#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="${INFRA_DIR}/docker-compose.yml"
DOCKER_BIN="${DOCKER_BIN:-/opt/homebrew/bin/docker}"

BACKUP_FILE="${1:-}"
TARGET_DB="${TARGET_DB:-ddg_restore}"
POSTGRES_USER="${POSTGRES_USER:-ddg}"

if [[ -z "$BACKUP_FILE" ]]; then
  echo "Usage: bash scripts/pg_restore.sh <backup_file.sql.gz>"
  exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "[FAIL] backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "[INFO] restore from $BACKUP_FILE to database $TARGET_DB"

"$DOCKER_BIN" compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 <<SQL
DROP DATABASE IF EXISTS ${TARGET_DB};
CREATE DATABASE ${TARGET_DB};
SQL

gunzip -c "$BACKUP_FILE" | "$DOCKER_BIN" compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$POSTGRES_USER" -d "$TARGET_DB" -v ON_ERROR_STOP=1

echo "[DONE] restore completed: $TARGET_DB"
