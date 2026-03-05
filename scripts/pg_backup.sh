#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="${INFRA_DIR}/docker-compose.yml"
BACKUP_DIR="${INFRA_DIR}/backups"
DOCKER_BIN="${DOCKER_BIN:-/opt/homebrew/bin/docker}"

POSTGRES_DB="${POSTGRES_DB:-ddg}"
POSTGRES_USER="${POSTGRES_USER:-ddg}"
TS="$(date +%Y%m%d_%H%M%S)"
OUTPUT_FILE="${BACKUP_DIR}/${POSTGRES_DB}_${TS}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[INFO] creating backup: ${OUTPUT_FILE}"
"$DOCKER_BIN" compose -f "$COMPOSE_FILE" exec -T postgres \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" | gzip > "$OUTPUT_FILE"

echo "[DONE] backup created: ${OUTPUT_FILE}"
