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
  if [ "$(git branch --show-current)" != main ]; then
    echo "STOP: start on main. Current branch: $(git branch --show-current)"
    exit 1
  fi
  if [ -n "$(git status --porcelain)" ]; then
    echo "STOP: uncommitted changes. Review the status below."
    git status --short
    exit 1
  fi
  git pull --ff-only origin main
  read -r -p "Enter this session's new branch name: " demo_branch </dev/tty
  case "$demo_branch" in
    demo/rehearsal-*|demo/live-*) ;;
    *) echo "STOP: use demo/rehearsal-... or demo/live-..."; exit 1 ;;
  esac
  if ! git check-ref-format --branch "$demo_branch" >/dev/null 2>&1; then
    echo "STOP: invalid branch name."
    exit 1
  fi
  if git show-ref --verify --quiet "refs/heads/$demo_branch" ||
     git show-ref --verify --quiet "refs/remotes/origin/$demo_branch"; then
    echo "STOP: branch already exists. Choose an unused session name."
    exit 1
  fi
  git switch -c "$demo_branch"
  git restore --source="$VULNERABLE_COMMIT" -- package.json package-lock.json
  python3 - <<'PY'
import json
import os
from pathlib import Path
expected = os.environ["VULNERABLE_LODASH_VERSION"]
p = json.loads(Path("package.json").read_text())
l = json.loads(Path("package-lock.json").read_text())
assert p["dependencies"]["lodash"] == expected
assert l["packages"][""]["dependencies"]["lodash"] == expected
assert l["packages"]["node_modules/lodash"]["version"] == expected
print(f"Verified vulnerable fixture: lodash {expected}")
PY
  npm ci --offline --ignore-scripts --no-audit --no-fund
  npm ls lodash
  git --no-pager diff --stat
)
