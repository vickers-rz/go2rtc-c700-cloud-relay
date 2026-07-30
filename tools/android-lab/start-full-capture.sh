#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

label="${1:-manual}"
stamp="$(date +%Y%m%d-%H%M%S)"
cap_dir="captures/${label}-${stamp}"
mkdir -p "$cap_dir"
echo "$cap_dir" > /tmp/c700-current-capdir

"$ADB" wait-for-device
"$ADB" root >/dev/null || true
"$ADB" shell settings put global http_proxy "$MITM_HOST:$MITM_PORT"

{
  echo "capture_dir: $cap_dir"
  echo "started_local: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "started_epoch: $(date +%s)"
  echo "adb: $ADB"
  echo "proxy: $MITM_HOST:$MITM_PORT"
  echo "events:"
} > "$cap_dir/markers.yaml"

mitmdump \
  --listen-host 0.0.0.0 \
  --listen-port "$MITM_PORT" \
  --set flow_detail=2 \
  -w "$cap_dir/flows.mitm" \
  > "$cap_dir/mitmdump.log" 2>&1 &
echo $! > "$cap_dir/mitmdump.pid"

"$ADB" logcat -c
"$ADB" logcat -v threadtime > "$cap_dir/logcat.txt" 2>&1 &
echo $! > "$cap_dir/logcat.pid"

"$ADB" shell 'rm -f /sdcard/c700-capture.pcap; nohup tcpdump -i any -s 0 -w /sdcard/c700-capture.pcap >/sdcard/c700-tcpdump.log 2>&1 &' >/dev/null

"$ADB" exec-out screencap -p > "$cap_dir/00-start.png"

sleep 2
echo "CAP_DIR=$cap_dir"
echo "START=$(date '+%H:%M:%S')"
echo "mitmdump_pid=$(cat "$cap_dir/mitmdump.pid")"
echo "logcat_pid=$(cat "$cap_dir/logcat.pid")"

