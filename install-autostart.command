#!/bin/zsh
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.vickers.go2rtc-c700"
PLIST_SRC="$BASE_DIR/$LABEL.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_VALUE="$(id -u)"

mkdir -p "$HOME/Library/LaunchAgents" "$BASE_DIR/logs"

launchctl bootout "gui/$UID_VALUE" "$PLIST_DST" 2>/dev/null || true
cp "$PLIST_SRC" "$PLIST_DST"
launchctl bootstrap "gui/$UID_VALUE" "$PLIST_DST"
launchctl enable "gui/$UID_VALUE/$LABEL"
launchctl kickstart -k "gui/$UID_VALUE/$LABEL"

echo "Installed and started: $LABEL"
echo "Web UI: http://127.0.0.1:1984"
echo "RTSP:   rtsp://127.0.0.1:8554/c700_remote_sim"
