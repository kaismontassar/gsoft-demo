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
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [-p|--project KEY] [-h|--help] [true|false] [policy]

Switch Xray download blocking on every rule of a policy.

Arguments:
  true|false          true = block downloads, false = allow (default: true)
  policy              Xray policy name (default: gsoft-critical-cve-fix)

Options:
  -p, --project KEY   Project of the policy (default: none = global policy)
  -h, --help          Show this help

Server ID: POLICY_SERVER_ID from sbin/.env (currently: ${POLICY_SERVER_ID:-unset}).
EOF
}

PROJECT=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -p|--project)
      [ $# -ge 2 ] || { echo "STOP: $1 needs a project key." >&2; usage >&2; exit 1; }
      PROJECT="$2"; shift 2 ;;
    --project=*) PROJECT="${1#*=}"; shift ;;
    -*) echo "STOP: unknown option $1" >&2; usage >&2; exit 1 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
[ ${#ARGS[@]} -le 2 ] || { echo "STOP: too many arguments." >&2; usage >&2; exit 1; }

ACTIVE="${ARGS[0]:-true}"
POLICY="${ARGS[1]:-gsoft-critical-cve-fix}"
case "$ACTIVE" in true|false) ;; *) echo "STOP: first argument must be true or false." >&2; usage >&2; exit 1 ;; esac
[ -n "${POLICY_SERVER_ID:-}" ] || { echo "STOP: POLICY_SERVER_ID is not set in sbin/.env." >&2; exit 1; }

# Global policies are addressed without projectKey
URL="/xray/api/v2/policies/$POLICY"
[ -z "$PROJECT" ] || URL="$URL?projectKey=$PROJECT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Policy $POLICY (${PROJECT:-global}) on $POLICY_SERVER_ID: block_download.active=$ACTIVE"

# Read the current policy
jf api "$URL" --server-id="$POLICY_SERVER_ID" > "$tmp/policy.json"

# Switch block_download on every rule, keep everything else unchanged
jq --argjson active "$ACTIVE" \
  '.rules |= map(.actions.block_download.active = $active)' \
  "$tmp/policy.json" > "$tmp/policy-new.json"

# Write it back
jf api "$URL" --server-id="$POLICY_SERVER_ID" \
  -X PUT -H "Content-Type: application/json" --input "$tmp/policy-new.json"

# Verify: report what Xray saved
jf api "$URL" --server-id="$POLICY_SERVER_ID" > "$tmp/policy-saved.json"
jq -r '
  "Policy:         \(.name)",
  "Scope:          \(if (.project_key // "") == "" then "global" else "project \(.project_key)" end)",
  (.rules[] | "Download block: \(if .actions.block_download.active then "on" else "off" end) (rule \(.name))")
' "$tmp/policy-saved.json"
