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

# -------
# helpers
# -------
git-cleaner() {
    git checkout . 
    git switch main
    git pull
    for branch in demo/will-fail-left demo/will-fail-right ; do
        git push origin --delete $branch
        git branch -D $branch
    done
}


# ----
# main
# ----

## cleanup working copies and remotes
git-cleaner /Volumes/studio-work/volker/Development/dev/gsoft-demo 
git-cleaner /Volumes/studio-work/volker/Development/dev/gsoft-demo-consumer

# disable download
sbin/set-policy-block.sh false
