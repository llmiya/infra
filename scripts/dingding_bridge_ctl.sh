#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="${INFRA_DIR}/.runtime"
PID_FILE="${RUNTIME_DIR}/dingding_bridge.pid"
LOG_FILE="${RUNTIME_DIR}/dingding_bridge.log"

mkdir -p "$RUNTIME_DIR"

is_running() {
  if [[ ! -f "$PID_FILE" ]]; then
    return 1
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  if [[ -z "$pid" ]]; then
    return 1
  fi
  kill -0 "$pid" >/dev/null 2>&1
}

start_bridge() {
  if is_running; then
    echo "[OK] dingding bridge already running pid=$(cat "$PID_FILE")"
    return 0
  fi

  if [[ "${DINGTALK_MODE:-}" == "" ]]; then
    export DINGTALK_MODE="noop"
  fi

  nohup python3 -u "${SCRIPT_DIR}/dingding_alert_bridge.py" >"$LOG_FILE" 2>&1 &
  local pid=$!
  echo "$pid" > "$PID_FILE"
  sleep 1

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "[OK] dingding bridge started pid=$pid log=$LOG_FILE"
  else
    echo "[FAIL] dingding bridge failed to start, check $LOG_FILE"
    exit 1
  fi
}

stop_bridge() {
  if ! is_running; then
    echo "[OK] dingding bridge not running"
    rm -f "$PID_FILE"
    return 0
  fi

  local pid
  pid="$(cat "$PID_FILE")"
  kill "$pid" >/dev/null 2>&1 || true
  rm -f "$PID_FILE"
  echo "[OK] dingding bridge stopped pid=$pid"
}

status_bridge() {
  if is_running; then
    echo "[OK] dingding bridge running pid=$(cat "$PID_FILE")"
    tail -n 20 "$LOG_FILE" || true
  else
    echo "[INFO] dingding bridge not running"
  fi
}

case "${1:-}" in
  start)
    start_bridge
    ;;
  stop)
    stop_bridge
    ;;
  restart)
    stop_bridge
    start_bridge
    ;;
  status)
    status_bridge
    ;;
  *)
    echo "Usage: bash scripts/dingding_bridge_ctl.sh {start|stop|restart|status}"
    exit 1
    ;;
esac
