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
  dingtalk_chat_id -> DINGTALK_CHAT_ID
  dingtalk_target_mode -> DINGTALK_TARGET_MODE
  dingtalk_user_ids -> DINGTALK_USER_IDS
  dingtalk_user_id_field -> DINGTALK_USER_ID_FIELD
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
  local dt_chat_id="${DINGTALK_CHAT_ID:-}"
  local dt_target_mode="${DINGTALK_TARGET_MODE:-group}"
  local dt_user_ids="${DINGTALK_USER_IDS:-}"
  local dt_user_id_field="${DINGTALK_USER_ID_FIELD:-userIds}"

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
      read -rp "Input DINGTALK_OPEN_CONVERSATION_ID (optional if DINGTALK_CHAT_ID provided): " dt_open_conv
    fi
    if [[ -z "$dt_chat_id" ]]; then
      read -rp "Input DINGTALK_CHAT_ID (optional, used to resolve openConversationId): " dt_chat_id
    fi
    read -rp "Input DINGTALK_TARGET_MODE [group|user] (default: ${dt_target_mode}): " input_target_mode
    dt_target_mode="${input_target_mode:-$dt_target_mode}"
    if [[ "$dt_target_mode" == "user" && -z "$dt_user_ids" ]]; then
      read -rp "Input DINGTALK_USER_IDS (comma-separated, e.g. u1,u2): " dt_user_ids
    fi
    if [[ "$dt_target_mode" == "user" ]]; then
      read -rp "Input DINGTALK_USER_ID_FIELD [userIds|unionIds|openIds] (default: ${dt_user_id_field}): " input_user_id_field
      dt_user_id_field="${input_user_id_field:-$dt_user_id_field}"
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
  set_secret "dingtalk_chat_id" "$dt_chat_id"
  set_secret "dingtalk_target_mode" "$dt_target_mode"
  set_secret "dingtalk_user_ids" "$dt_user_ids"
  set_secret "dingtalk_user_id_field" "$dt_user_id_field"
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
  local dt_chat_id
  local dt_target_mode
  local dt_user_ids
  local dt_user_id_field
  pg="$(get_secret postgres_password)"
  gf="$(get_secret grafana_admin_password)"
  am="$(get_secret alertmanager_webhook_url 2>/dev/null || true)"
  mode="$(get_secret dingtalk_mode 2>/dev/null || true)"
  dt_webhook="$(get_secret dingtalk_webhook_url 2>/dev/null || true)"
  dt_app_key="$(get_secret dingtalk_app_key 2>/dev/null || true)"
  dt_app_secret="$(get_secret dingtalk_app_secret 2>/dev/null || true)"
  dt_robot_code="$(get_secret dingtalk_robot_code 2>/dev/null || true)"
  dt_open_conv="$(get_secret dingtalk_open_conversation_id 2>/dev/null || true)"
  dt_chat_id="$(get_secret dingtalk_chat_id 2>/dev/null || true)"
  dt_target_mode="$(get_secret dingtalk_target_mode 2>/dev/null || true)"
  dt_user_ids="$(get_secret dingtalk_user_ids 2>/dev/null || true)"
  dt_user_id_field="$(get_secret dingtalk_user_id_field 2>/dev/null || true)"
  am="${am:-http://host.docker.internal:18080/alerts}"
  mode="${mode:-noop}"
  dt_target_mode="${dt_target_mode:-group}"
  dt_user_id_field="${dt_user_id_field:-userIds}"

  printf "export POSTGRES_PASSWORD=%q\n" "$pg"
  printf "export GF_SECURITY_ADMIN_PASSWORD=%q\n" "$gf"
  printf "export ALERTMANAGER_WEBHOOK_URL=%q\n" "$am"
  printf "export DINGTALK_MODE=%q\n" "$mode"
  printf "export DINGTALK_WEBHOOK_URL=%q\n" "$dt_webhook"
  printf "export DINGTALK_APP_KEY=%q\n" "$dt_app_key"
  printf "export DINGTALK_APP_SECRET=%q\n" "$dt_app_secret"
  printf "export DINGTALK_ROBOT_CODE=%q\n" "$dt_robot_code"
  printf "export DINGTALK_OPEN_CONVERSATION_ID=%q\n" "$dt_open_conv"
  printf "export DINGTALK_CHAT_ID=%q\n" "$dt_chat_id"
  printf "export DINGTALK_TARGET_MODE=%q\n" "$dt_target_mode"
  printf "export DINGTALK_USER_IDS=%q\n" "$dt_user_ids"
  printf "export DINGTALK_USER_ID_FIELD=%q\n" "$dt_user_id_field"
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
