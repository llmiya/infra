#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="${INFRA_DIR}/docker-compose.yml"
DOCKER_BIN="${DOCKER_BIN:-/opt/homebrew/bin/docker}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"

echo "[1/4] Checking container states"
"$DOCKER_BIN" compose -f "$COMPOSE_FILE" ps

check_health() {
  local service="$1"
  local container_id
  container_id="$("$DOCKER_BIN" compose -f "$COMPOSE_FILE" ps -q "$service")"
  if [[ -z "$container_id" ]]; then
    echo "[FAIL] service '$service' not found"
    exit 1
  fi

  local status
  status="$("$DOCKER_BIN" inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")"
  if [[ "$status" != "healthy" && "$status" != "running" ]]; then
    echo "[FAIL] service '$service' status=$status"
    exit 1
  fi
  echo "[OK] service '$service' status=$status"
}

echo "[2/4] Checking service health"
check_health postgres
check_health redis
check_health prometheus
check_health alertmanager
check_health grafana

retry_http() {
  local url="$1"
  local attempts="${2:-12}"
  local sleep_seconds="${3:-2}"

  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_seconds"
  done

  echo "[FAIL] endpoint not ready after retries: $url"
  return 1
}

echo "[3/4] Checking HTTP endpoints"
retry_http http://127.0.0.1:9090/-/ready
retry_http http://127.0.0.1:9093/-/ready
retry_http "http://127.0.0.1:${GRAFANA_PORT}/api/health"
echo "[OK] prometheus/alertmanager/grafana ready"

echo "[4/4] Checking exporter targets"
curl -fsS http://127.0.0.1:9090/api/v1/targets | grep -q 'postgres_exporter'
curl -fsS http://127.0.0.1:9090/api/v1/targets | grep -q 'redis_exporter'
echo "[OK] exporter targets discovered"

echo "[DONE] Infra smoke check passed"
