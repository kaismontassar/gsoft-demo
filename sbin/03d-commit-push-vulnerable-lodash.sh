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
  cd "$BASE_DIR"
  case "$(git branch --show-current)" in
    demo/rehearsal-*|demo/live-*) ;;
    *) echo "STOP: expected the session demo branch"; exit 1 ;;
  esac
  git diff --check
  git add package.json package-lock.json
  git commit -m "Demonstrate vulnerable lodash in certification PR"
  git push --set-upstream origin HEAD
)
