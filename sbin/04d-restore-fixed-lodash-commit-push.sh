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
  if [ -n "$(git status --porcelain)" ]; then
    echo "STOP: uncommitted changes. Review the status below."
    git status --short
    exit 1
  fi
  git fetch origin main
  git restore --source=origin/main -- package.json package-lock.json
  python3 - <<'PY'
import json
import os
from pathlib import Path
expected = os.environ["FIXED_LODASH_VERSION"]
p = json.loads(Path("package.json").read_text())
l = json.loads(Path("package-lock.json").read_text())
assert p["dependencies"]["lodash"] == expected
assert l["packages"][""]["dependencies"]["lodash"] == expected
assert l["packages"]["node_modules/lodash"]["version"] == expected
print(f"Verified fixed dependency: lodash {expected}")
PY
  jf npm-config \
    --server-id-resolve="$SERVER_ID" \
    --repo-resolve="$NPM_RESOLVE_REPO" \
    --server-id-deploy="$SERVER_ID" \
    --repo-deploy="$NPM_DEPLOY_REPO"
  jf npm ci --ignore-scripts --no-audit --no-fund
  npm ls lodash
  npm test
  npm run build
  git diff --check
  git add package.json package-lock.json
  git commit -m "Restore approved lodash and resolve PR findings"
  git push
)
