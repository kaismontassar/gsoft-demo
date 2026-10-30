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

Switch Xray download blocking on every rule of a policy, rescan the cached
test artifact lodash $VULNERABLE_LODASH_VERSION (a policy change only applies
after the artifact is scanned again) and wait until its download returns the
expected status (true: 403, false: 200).

Arguments:
  true|false            true = block downloads, false = allow (default: true)
  policy                Xray policy name (default: gsoft-critical-cve-fix)

Options:
  -p, --project KEY     Project of the policy (default: none = global policy)
  -t, --timeout SEC     Max. wait for the test download (default: 900)
  -n, --no-wait         Rescan the artifact, but do not wait
  -h, --help            Show this help

Test artifact: \$NPM_REMOTE_CACHE/lodash/-/lodash-\$VULNERABLE_LODASH_VERSION.tgz
(${NPM_REMOTE_CACHE:-unset}/lodash/-/lodash-${VULNERABLE_LODASH_VERSION:-unset}.tgz).
Server IDs from sbin/.env: policy and rescan via POLICY_SERVER_ID
(${POLICY_SERVER_ID:-unset}), test download via SERVER_ID (${SERVER_ID:-unset}).
EOF
}

need_value() {
  [ $# -ge 2 ] || { echo "STOP: $1 needs a value." >&2; usage >&2; exit 1; }
}

PROJECT=""
TIMEOUT=900
WAIT=true
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -p|--project) need_value "$@"; PROJECT="$2"; shift 2 ;;
    --project=*) PROJECT="${1#*=}"; shift ;;
    -t|--timeout) need_value "$@"; TIMEOUT="$2"; shift 2 ;;
    --timeout=*) TIMEOUT="${1#*=}"; shift ;;
    -n|--no-wait) WAIT=false; shift ;;
    -*) echo "STOP: unknown option $1" >&2; usage >&2; exit 1 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
[ ${#ARGS[@]} -le 2 ] || { echo "STOP: too many arguments." >&2; usage >&2; exit 1; }

ACTIVE="${ARGS[0]:-true}"
POLICY="${ARGS[1]:-gsoft-critical-cve-fix}"
case "$ACTIVE" in true|false) ;; *) echo "STOP: first argument must be true or false." >&2; usage >&2; exit 1 ;; esac
[ -n "${POLICY_SERVER_ID:-}" ] || { echo "STOP: POLICY_SERVER_ID is not set in sbin/.env." >&2; exit 1; }
case "$TIMEOUT" in *[!0-9]*|"") echo "STOP: --timeout must be a number." >&2; exit 1 ;; esac
[ -n "${NPM_REMOTE_CACHE:-}" ] || { echo "STOP: NPM_REMOTE_CACHE is not set in sbin/.env." >&2; exit 1; }

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

# Rescan the cached test artifact: its existing scan result keeps the old
# policy actions until the artifact itself is scanned again
artifact="lodash/-/lodash-$VULNERABLE_LODASH_VERSION.tgz"
jq -n -c --arg r "$NPM_REMOTE_CACHE" --arg p "$artifact" \
  '{artifacts: [{repository: $r, path: $p}]}' > "$tmp/reindex.json"

echo "Rescan $NPM_REMOTE_CACHE/$artifact"
jf api /xray/api/v1/forceReindex --server-id="$POLICY_SERVER_ID" \
  -X POST -H "Content-Type: application/json" --input "$tmp/reindex.json"
echo

[ "$WAIT" = true ] || exit 0

# Wait until the test download shows the new state
probe="/artifactory/api/npm/$NPM_RESOLVE_REPO/lodash/-/lodash-$VULNERABLE_LODASH_VERSION.tgz"
expect=200
[ "$ACTIVE" = false ] || expect=403
echo "Waiting for HTTP $expect on $probe (server $SERVER_ID, timeout ${TIMEOUT}s)"

started=$SECONDS
while :; do
  status="$(jf api "$probe" --server-id="$SERVER_ID" 2>&1 >/dev/null \
    | sed -n 's/.*Http Status: \([0-9]*\).*/\1/p' | head -1 || true)"
  elapsed=$((SECONDS - started))
  printf '  %4ss  HTTP %s\n' "$elapsed" "${status:-?}"
  [ "$status" = "$expect" ] && { echo "Done: HTTP $expect after ${elapsed}s."; exit 0; }
  [ "$elapsed" -lt "$TIMEOUT" ] || { echo "STOP: still HTTP ${status:-?} after ${TIMEOUT}s." >&2; exit 1; }
  sleep 15
done
