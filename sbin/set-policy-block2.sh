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

Switch Xray download blocking on every rule of a policy, re-check the
watches that use it ("Apply on existing content") and wait until a test
download of lodash $VULNERABLE_LODASH_VERSION returns the expected status
(true: 403, false: 200).

Arguments:
  true|false            true = block downloads, false = allow (default: true)
  policy                Xray policy name (default: gsoft-critical-cve-fix)

Options:
  -p, --project KEY     Project of the policy (default: none = global policy)
  -w, --watch-project KEY
                        Project whose watches are searched for the policy
                        (default: PROJECT_KEY from sbin/.env = ${PROJECT_KEY:-unset})
  -d, --days N          Re-check content of the last N days (default: 90)
  -t, --timeout SEC     Max. wait for the test download (default: 900)
  -n, --no-wait         Re-check the watches, but do not wait
  -h, --help            Show this help

Server IDs from sbin/.env: policy and watches via POLICY_SERVER_ID
(${POLICY_SERVER_ID:-unset}), test download via SERVER_ID (${SERVER_ID:-unset}).
EOF
}

need_value() {
  [ $# -ge 2 ] || { echo "STOP: $1 needs a value." >&2; usage >&2; exit 1; }
}

PROJECT=""
WATCH_PROJECT="${PROJECT_KEY:-}"
DAYS=90
TIMEOUT=900
WAIT=true
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -p|--project) need_value "$@"; PROJECT="$2"; shift 2 ;;
    --project=*) PROJECT="${1#*=}"; shift ;;
    -w|--watch-project) need_value "$@"; WATCH_PROJECT="$2"; shift 2 ;;
    --watch-project=*) WATCH_PROJECT="${1#*=}"; shift ;;
    -d|--days) need_value "$@"; DAYS="$2"; shift 2 ;;
    --days=*) DAYS="${1#*=}"; shift ;;
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
case "$DAYS$TIMEOUT" in *[!0-9]*|"") echo "STOP: --days and --timeout must be numbers." >&2; exit 1 ;; esac
[ -n "$WATCH_PROJECT" ] || { echo "STOP: no watch project (-w or PROJECT_KEY in sbin/.env)." >&2; exit 1; }

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

# Re-check the watches that use the policy, so existing violations get the new action
watch_url="/xray/api/v2/watches?projectKey=$WATCH_PROJECT"
jf api "$watch_url" --server-id="$POLICY_SERVER_ID" > "$tmp/watches.json"
WATCHES=()
while IFS= read -r w; do
  [ -n "$w" ] && WATCHES+=("$w")
done < <(jq -r --arg p "$POLICY" \
  '.[] | select(.general_data.active == true) | select(any(.assigned_policies[]; .name == $p)) | .general_data.name' \
  "$tmp/watches.json")
[ ${#WATCHES[@]} -gt 0 ] || { echo "STOP: no active watch in project $WATCH_PROJECT uses $POLICY." >&2; exit 1; }

if date -u -v-1d +%s >/dev/null 2>&1; then
  start="$(date -u -v-"${DAYS}"d +%Y-%m-%dT%H:%M:%SZ)"            # macOS
else
  start="$(date -u -d "$DAYS days ago" +%Y-%m-%dT%H:%M:%SZ)"       # Linux
fi
end="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n --arg s "$start" --arg e "$end" '$ARGS.positional as $w |
  {watch_names: $w, date_range: {start_date: $s, end_date: $e}}' \
  --args "${WATCHES[@]}" > "$tmp/apply.json"

echo "Apply on existing content ($start .. $end): ${WATCHES[*]}"
jf api "/xray/api/v1/applyWatch?projectKey=$WATCH_PROJECT" --server-id="$POLICY_SERVER_ID" \
  -X POST -H "Content-Type: application/json" --input "$tmp/apply.json"
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
