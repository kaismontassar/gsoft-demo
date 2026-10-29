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
cd "$BASE_DIR"
hostname
git status --short --branch
node --version
npm --version
jf --version
