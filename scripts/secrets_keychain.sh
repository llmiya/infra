#!/usr/bin/env bash

set -euo pipefail

SERVICE_PREFIX="vibe-coding.infra"
ACCOUNT="${USER:-infra}"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/secrets_keychain.sh init
  bash scripts/secrets_keychain.sh set <key> <value>
  bash scripts/secrets_keychain.sh get <key>
  bash scripts/secrets_keychain.sh export-env

Managed keys:
  postgres_password -> POSTGRES_PASSWORD
  grafana_admin_password -> GF_SECURITY_ADMIN_PASSWORD
  alertmanager_webhook_url -> ALERTMANAGER_WEBHOOK_URL (compat)
  dingtalk_mode -> DINGTALK_MODE
  dingtalk_webhook_url -> DINGTALK_WEBHOOK_URL
  dingtalk_app_key -> DINGTALK_APP_KEY
  dingtalk_app_secret -> DINGTALK_APP_SECRET
  dingtalk_robot_code -> DINGTALK_ROBOT_CODE
  dingtalk_open_conversation_id -> DINGTALK_OPEN_CONVERSATION_ID
EOF
}

secret_name() {
  local key="$1"
  echo "${SERVICE_PREFIX}.${key}"
}

set_secret() {
  local key="$1"
  local value="$2"
  security add-generic-password -a "$ACCOUNT" -s "$(secret_name "$key")" -w "$value" -U >/dev/null
}

get_secret() {
  local key="$1"
  security find-generic-password -a "$ACCOUNT" -s "$(secret_name "$key")" -w
}

init_secrets() {
  local pg="${POSTGRES_PASSWORD:-}"
  local gf="${GF_SECURITY_ADMIN_PASSWORD:-}"
  local am="${ALERTMANAGER_WEBHOOK_URL:-}"
  local mode="${DINGTALK_MODE:-noop}"
  local dt_webhook="${DINGTALK_WEBHOOK_URL:-}"
  local dt_app_key="${DINGTALK_APP_KEY:-}"
  local dt_app_secret="${DINGTALK_APP_SECRET:-}"
  local dt_robot_code="${DINGTALK_ROBOT_CODE:-}"
  local dt_open_conv="${DINGTALK_OPEN_CONVERSATION_ID:-}"

  if [[ -z "$pg" ]]; then
    read -rsp "Input POSTGRES_PASSWORD: " pg
    echo
  fi
  if [[ -z "$gf" ]]; then
    read -rsp "Input GF_SECURITY_ADMIN_PASSWORD: " gf
    echo
  fi
  if [[ -z "$am" ]]; then
    read -rp "Input ALERTMANAGER_WEBHOOK_URL (default: http://host.docker.internal:18080/alerts): " am
  fi
  am="${am:-http://host.docker.internal:18080/alerts}"

  read -rp "Input DINGTALK_MODE [noop|webhook|stream] (default: ${mode}): " input_mode
  mode="${input_mode:-$mode}"

  if [[ "$mode" == "webhook" ]]; then
    if [[ -z "$dt_webhook" ]]; then
      read -rp "Input DINGTALK_WEBHOOK_URL: " dt_webhook
    fi
  elif [[ "$mode" == "stream" ]]; then
    if [[ -z "$dt_app_key" ]]; then
      read -rp "Input DINGTALK_APP_KEY: " dt_app_key
    fi
    if [[ -z "$dt_app_secret" ]]; then
      read -rsp "Input DINGTALK_APP_SECRET: " dt_app_secret
      echo
    fi
    if [[ -z "$dt_robot_code" ]]; then
      read -rp "Input DINGTALK_ROBOT_CODE: " dt_robot_code
    fi
    if [[ -z "$dt_open_conv" ]]; then
      read -rp "Input DINGTALK_OPEN_CONVERSATION_ID: " dt_open_conv
    fi
  fi

  set_secret "postgres_password" "$pg"
  set_secret "grafana_admin_password" "$gf"
  set_secret "alertmanager_webhook_url" "$am"
  set_secret "dingtalk_mode" "$mode"
  set_secret "dingtalk_webhook_url" "$dt_webhook"
  set_secret "dingtalk_app_key" "$dt_app_key"
  set_secret "dingtalk_app_secret" "$dt_app_secret"
  set_secret "dingtalk_robot_code" "$dt_robot_code"
  set_secret "dingtalk_open_conversation_id" "$dt_open_conv"
  echo "[OK] Keychain secrets initialized"
}

export_env() {
  local pg
  local gf
  local am
  local mode
  local dt_webhook
  local dt_app_key
  local dt_app_secret
  local dt_robot_code
  local dt_open_conv
  pg="$(get_secret postgres_password)"
  gf="$(get_secret grafana_admin_password)"
  am="$(get_secret alertmanager_webhook_url 2>/dev/null || true)"
  mode="$(get_secret dingtalk_mode 2>/dev/null || true)"
  dt_webhook="$(get_secret dingtalk_webhook_url 2>/dev/null || true)"
  dt_app_key="$(get_secret dingtalk_app_key 2>/dev/null || true)"
  dt_app_secret="$(get_secret dingtalk_app_secret 2>/dev/null || true)"
  dt_robot_code="$(get_secret dingtalk_robot_code 2>/dev/null || true)"
  dt_open_conv="$(get_secret dingtalk_open_conversation_id 2>/dev/null || true)"
  am="${am:-http://host.docker.internal:18080/alerts}"
  mode="${mode:-noop}"

  printf "export POSTGRES_PASSWORD=%q\n" "$pg"
  printf "export GF_SECURITY_ADMIN_PASSWORD=%q\n" "$gf"
  printf "export ALERTMANAGER_WEBHOOK_URL=%q\n" "$am"
  printf "export DINGTALK_MODE=%q\n" "$mode"
  printf "export DINGTALK_WEBHOOK_URL=%q\n" "$dt_webhook"
  printf "export DINGTALK_APP_KEY=%q\n" "$dt_app_key"
  printf "export DINGTALK_APP_SECRET=%q\n" "$dt_app_secret"
  printf "export DINGTALK_ROBOT_CODE=%q\n" "$dt_robot_code"
  printf "export DINGTALK_OPEN_CONVERSATION_ID=%q\n" "$dt_open_conv"
}

cmd="${1:-}"
case "$cmd" in
  init)
    init_secrets
    ;;
  set)
    [[ $# -eq 3 ]] || { usage; exit 1; }
    set_secret "$2" "$3"
    echo "[OK] secret '$2' updated"
    ;;
  get)
    [[ $# -eq 2 ]] || { usage; exit 1; }
    get_secret "$2"
    ;;
  export-env)
    export_env
    ;;
  *)
    usage
    exit 1
    ;;
esac
