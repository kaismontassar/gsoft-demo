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
  if [ -n "$(git status --porcelain)" ]; then
    echo "STOP: uncommitted changes. Review the status below."
    git status --short
    exit 1
  fi
  git switch main
  git pull --ff-only origin main
  jf npm ci --ignore-scripts --no-audit --no-fund
  npm ls lodash
  git status --short --branch
)
