#!/usr/bin/env bash
set -euo pipefail
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="$(cd "$(dirname "$0")" && pwd)"
for f in "$DIR"/*.html; do
  name="$(basename "${f%.html}")"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=3 --window-size=402,874 \
    --virtual-time-budget=4000 \
    --screenshot="$DIR/$name.png" "file://$f" >/dev/null 2>&1
  echo "rendered $name"
done
