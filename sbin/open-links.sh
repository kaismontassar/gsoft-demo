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

# Open links as tabs in a new Brave window.
# Usage: open-links.sh [URL...]   (no arguments: DEMO_LINKS array from sbin/.env)
if [ $# -gt 0 ]; then
  links=("$@")
elif [ -n "${DEMO_LINKS+x}" ] && [ ${#DEMO_LINKS[@]} -gt 0 ]; then
  links=("${DEMO_LINKS[@]}")
else
  echo "STOP: no links given and DEMO_LINKS is not set in sbin/.env."
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    open -na "Brave Browser" --args --new-window "${links[@]}"
    ;;
  Linux)
    # Other browsers on Linux (same arguments: --new-window URL...):
    #   google-chrome --new-window "${links[@]}"      # Google Chrome
    #   chromium --new-window "${links[@]}"           # Chromium (Debian/Ubuntu: chromium-browser)
    #   microsoft-edge --new-window "${links[@]}"     # Microsoft Edge
    #   vivaldi --new-window "${links[@]}"            # Vivaldi
    #   firefox --new-window "${links[0]}" && for u in "${links[@]:1}"; do firefox --new-tab "$u"; done
    #                                                 # Firefox: one URL per --new-window/--new-tab
    #   xdg-open "${links[0]}"                        # default browser, one URL per call
    brave=""
    for cmd in brave-browser brave; do
      if command -v "$cmd" >/dev/null 2>&1; then brave="$cmd"; break; fi
    done
    if [ -n "$brave" ]; then
      setsid "$brave" --new-window "${links[@]}" >/dev/null 2>&1 &
    elif command -v flatpak >/dev/null 2>&1 && flatpak info com.brave.Browser >/dev/null 2>&1; then
      setsid flatpak run com.brave.Browser --new-window "${links[@]}" >/dev/null 2>&1 &
    else
      echo "STOP: Brave not found (brave-browser, brave or flatpak com.brave.Browser)."
      exit 1
    fi
    ;;
  *)
    echo "STOP: unsupported OS $(uname -s)."
    exit 1
    ;;
esac

echo "Opened ${#links[@]} tabs in Brave."
