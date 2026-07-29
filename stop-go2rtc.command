#!/bin/zsh
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$BASE_DIR/go2rtc.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "go2rtc is not running."
  exit 0
fi

PID="$(cat "$PID_FILE")"
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  sleep 1
fi

if kill -0 "$PID" 2>/dev/null; then
  kill -9 "$PID"
fi

rm -f "$PID_FILE"
echo "go2rtc stopped."
