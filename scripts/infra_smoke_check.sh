#!/usr/bin/env bash

set -euo pipefail

COMPOSE_FILE="infra/docker-compose.yml"

echo "[1/4] Checking container states"
docker compose -f "$COMPOSE_FILE" ps

check_health() {
  local service="$1"
  local container_id
  container_id="$(docker compose -f "$COMPOSE_FILE" ps -q "$service")"
  if [[ -z "$container_id" ]]; then
    echo "[FAIL] service '$service' not found"
    exit 1
  fi

  local status
  status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")"
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
retry_http http://127.0.0.1:3000/api/health
echo "[OK] prometheus/alertmanager/grafana ready"

echo "[4/4] Checking exporter targets"
curl -fsS http://127.0.0.1:9090/api/v1/targets | grep -q 'postgres_exporter'
curl -fsS http://127.0.0.1:9090/api/v1/targets | grep -q 'redis_exporter'
echo "[OK] exporter targets discovered"

echo "[DONE] Infra smoke check passed"
