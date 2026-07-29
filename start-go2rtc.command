#!/bin/zsh
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$BASE_DIR/go2rtc.pid"
LOG_FILE="$BASE_DIR/logs/go2rtc.log"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "go2rtc is already running. PID: $(cat "$PID_FILE")"
  exit 0
fi

mkdir -p "$BASE_DIR/logs"
nohup "$BASE_DIR/bin/go2rtc" -config "$BASE_DIR/config/go2rtc.yaml" > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

sleep 2
if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "go2rtc started. PID: $(cat "$PID_FILE")"
  echo "Web UI: http://127.0.0.1:1984"
  echo "RTSP:   rtsp://127.0.0.1:8554/c700_remote_sim"
else
  echo "go2rtc failed to start. Check log: $LOG_FILE"
  rm -f "$PID_FILE"
  exit 1
fi
