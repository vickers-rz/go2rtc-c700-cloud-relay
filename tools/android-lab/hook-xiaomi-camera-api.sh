#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

SCRIPT="tools/android-lab/frida/hook-xiaomi-camera-api.js"
PKG="com.xiaomi.smarthome"
TARGET_PROCESS="${2:-$PKG:camera}"
LOG_DIR="${1:-captures/frida-camera-api-$(date +%Y%m%d-%H%M%S)}"
LOG_FILE="$LOG_DIR/frida-camera-api.log"

mkdir -p "$LOG_DIR"

"$ADB" wait-for-device

FRIDA_VERSION="$("$FRIDA_VENV/bin/python" - <<'PY'
import frida
print(frida.__version__)
PY
)"
SERVER="$HOME/.local/share/frida-server/frida-server-${FRIDA_VERSION}-android-arm64"

"$ADB" root >/dev/null || true
"$ADB" push "$SERVER" /data/local/tmp/frida-server >/dev/null
"$ADB" shell chmod 755 /data/local/tmp/frida-server
"$ADB" shell 'pkill frida-server 2>/dev/null || true; nohup /data/local/tmp/frida-server >/data/local/tmp/frida-server.log 2>&1 &' >/dev/null
sleep 1

echo "FRIDA_LOG=$LOG_FILE"

PID="$("$ADB" shell pidof "$TARGET_PROCESS" 2>/dev/null | tr -d '\r' | awk '{print $1}')"
if [[ -n "$PID" ]]; then
  echo "FRIDA_TARGET=$TARGET_PROCESS PID=$PID"
  "$FRIDA_VENV/bin/frida" -U -p "$PID" -l "$SCRIPT" | tee "$LOG_FILE"
  exit "${PIPESTATUS[0]}"
fi

PID="$("$ADB" shell pidof "$PKG" 2>/dev/null | tr -d '\r' | awk '{print $1}')"
if [[ -n "$PID" ]]; then
  echo "FRIDA_TARGET=$PKG PID=$PID"
  "$FRIDA_VENV/bin/frida" -U -p "$PID" -l "$SCRIPT" | tee "$LOG_FILE"
  exit "${PIPESTATUS[0]}"
fi

echo "FRIDA_TARGET=$PKG spawn"
"$FRIDA_VENV/bin/frida" -U -f "$PKG" -l "$SCRIPT" --no-pause | tee "$LOG_FILE"
exit "${PIPESTATUS[0]}"
