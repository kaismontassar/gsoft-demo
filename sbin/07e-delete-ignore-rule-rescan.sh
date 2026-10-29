#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
if [ ! -f "$SCRIPT_DIR/.env" ]; then
  echo "STOP: missing $SCRIPT_DIR/.env (copy .env.example)."
  exit 1
fi
set -a
. "$SCRIPT_DIR/.env"
set +a
(
  set -euo pipefail
  read -r -p "Paste the new rule ID verified in step 7d: " rule_id </dev/tty
  if [[ ! "$rule_id" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    echo "STOP: expected the UUID shown in step 7d. No rule was deleted."
    exit 1
  fi
  jf xr curl \
    --server-id="$SERVER_ID" -f -sS -XDELETE \
    "/api/v1/ignore_rules/${rule_id}?projectKey=${PROJECT_KEY}"
  echo "Demonstration ignore rule removed."
  scan_exit=0
  jf build-scan "$BUILD_NAME" "$BUILD_NUMBER" \
    --server-id="$SERVER_ID" --project="$PROJECT_KEY" \
    --rescan=true --fail=true --extended-table=true \
    || scan_exit=$?
  echo "Build scan exit code: $scan_exit"
)
