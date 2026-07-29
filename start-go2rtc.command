#!/bin/zsh
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$BASE_DIR/go2rtc.pid"
LOG_FILE="$BASE_DIR/logs/go2rtc.log"
MODE="${1:-}"

if [[ "$MODE" == "cloud" || "$MODE" == "lan" ]]; then
  "$BASE_DIR/switch-mode.command" "$MODE"
elif [[ -n "$MODE" ]]; then
  echo "Usage: $0 [cloud|lan]"
  exit 1
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
	echo "go2rtc is already running. PID: $(cat "$PID_FILE")"
	"$BASE_DIR/switch-mode.command" status
	exit 0
fi

mkdir -p "$BASE_DIR/logs"
nohup "$BASE_DIR/bin/go2rtc" -config "$BASE_DIR/config/go2rtc.yaml" > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

sleep 2
if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
	echo "go2rtc started. PID: $(cat "$PID_FILE")"
	echo "Web UI: http://127.0.0.1:1984"
	"$BASE_DIR/switch-mode.command" status
else
  echo "go2rtc failed to start. Check log: $LOG_FILE"
  rm -f "$PID_FILE"
  exit 1
fi
