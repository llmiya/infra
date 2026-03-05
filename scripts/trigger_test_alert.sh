#!/usr/bin/env bash

set -euo pipefail

ALERTMANAGER_API="${ALERTMANAGER_API:-http://127.0.0.1:9093/api/v2/alerts}"
ALERT_NAME="${ALERT_NAME:-InfraSyntheticTestAlert}"
DURATION_MINUTES="${DURATION_MINUTES:-2}"

starts_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ends_at="$(date -u -v+${DURATION_MINUTES}M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "+${DURATION_MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ)"

payload=$(cat <<JSON
[
  {
    "labels": {
      "alertname": "${ALERT_NAME}",
      "severity": "warning",
      "job": "manual"
    },
    "annotations": {
      "summary": "manual synthetic alert",
      "description": "triggered by infra/scripts/trigger_test_alert.sh"
    },
    "startsAt": "${starts_at}",
    "endsAt": "${ends_at}",
    "generatorURL": "manual://infra"
  }
]
JSON
)

curl -fsS -XPOST -H 'Content-Type: application/json' "$ALERTMANAGER_API" -d "$payload"
echo "[DONE] synthetic alert submitted to ${ALERTMANAGER_API}"
