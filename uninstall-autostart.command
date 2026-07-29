#!/bin/zsh
set -euo pipefail

LABEL="com.vickers.go2rtc-c700"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_VALUE="$(id -u)"

launchctl bootout "gui/$UID_VALUE" "$PLIST_DST" 2>/dev/null || true
rm -f "$PLIST_DST"

echo "Uninstalled: $LABEL"
