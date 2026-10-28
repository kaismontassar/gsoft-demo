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
  scan_exit=0
  jf build-scan "$BUILD_NAME" "$BUILD_NUMBER" \
    --server-id="$SERVER_ID" \
    --project="$PROJECT_KEY" \
    --rescan=true \
    --fail=true \
    --extended-table=true \
    || scan_exit=$?
  echo "Build scan exit code: $scan_exit"
)
