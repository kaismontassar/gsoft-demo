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
endpoint="/api/v1/ignore_rules?projectKey=${PROJECT_KEY}"
endpoint+="&vulnerability=${XRAY_VULNERABILITY}"
endpoint+="&watch=${XRAY_WATCH}"
jf xr curl \
  --server-id="$SERVER_ID" -f -sS -XGET \
  "$endpoint" \
  | python3 -m json.tool
