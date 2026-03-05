#!/usr/bin/env bash

set -euo pipefail

DIFF_CONTENT="$(git diff --cached --unified=0 --no-color --diff-filter=ACM)"

if [[ -z "$DIFF_CONTENT" ]]; then
  exit 0
fi

ADDED_LINES="$(printf '%s\n' "$DIFF_CONTENT" | grep -E '^\+[^\+]' || true)"

if [[ -z "$ADDED_LINES" ]]; then
  exit 0
fi

SECRET_ASSIGN_PATTERN='(RUNNER_TOKEN|POSTGRES_PASSWORD|GF_SECURITY_ADMIN_PASSWORD|DINGTALK_APP_SECRET|DINGTALK_WEBHOOK_URL|ALERTMANAGER_WEBHOOK_URL|API_KEY|ACCESS_TOKEN|SECRET_KEY)[[:space:]]*[:=][[:space:]]*[^$]'
TOKEN_PATTERN='(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16})'

HITS="$(printf '%s\n' "$ADDED_LINES" | grep -En "$SECRET_ASSIGN_PATTERN|$TOKEN_PATTERN" || true)"

if [[ -n "$HITS" ]]; then
  echo "[BLOCKED] Potential plaintext secret detected in staged changes:"
  echo "$HITS"
  echo ""
  echo "Use Keychain/Secrets manager or environment references (e.g. \${VAR}) instead of plaintext."
  exit 1
fi

exit 0
