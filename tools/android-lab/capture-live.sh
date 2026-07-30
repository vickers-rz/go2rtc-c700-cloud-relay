#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

label="${1:-manual-live}"
stamp="$(date +%Y%m%d-%H%M%S)"
cap_dir="captures/${label}-${stamp}"
mkdir -p "$cap_dir"
echo "$cap_dir" > /tmp/c700-current-capdir

"$ADB" wait-for-device
"$ADB" root >/dev/null || true
"$ADB" shell settings put global http_proxy "$MITM_HOST:$MITM_PORT"
"$ADB" logcat -c
"$ADB" shell 'rm -f /sdcard/c700-capture.pcap /sdcard/c700-tcpdump.log'

{
  echo "capture_dir: $cap_dir"
  echo "started_local: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "started_epoch: $(date +%s)"
  echo "proxy: $MITM_HOST:$MITM_PORT"
  echo "events:"
} > "$cap_dir/markers.yaml"

cleanup() {
  set +e
  kill "$mitm_pid" "$logcat_pid" >/dev/null 2>&1
  "$ADB" shell 'pkill tcpdump 2>/dev/null || true'
  sleep 1
  "$ADB" pull /sdcard/c700-capture.pcap "$cap_dir/c700-capture.pcap" >/dev/null 2>&1
  "$ADB" pull /sdcard/c700-tcpdump.log "$cap_dir/c700-tcpdump.log" >/dev/null 2>&1
  "$ADB" exec-out screencap -p > "$cap_dir/99-end.png" 2>/dev/null
  echo
  echo "CAP_DIR=$cap_dir"
  ls -lh "$cap_dir"
}
trap cleanup EXIT INT TERM

mitmdump \
  --listen-host 0.0.0.0 \
  --listen-port "$MITM_PORT" \
  --set flow_detail=2 \
  -w "$cap_dir/flows.mitm" \
  > "$cap_dir/mitmdump.log" 2>&1 &
mitm_pid=$!

"$ADB" logcat -v threadtime > "$cap_dir/logcat.txt" 2>&1 &
logcat_pid=$!

"$ADB" shell 'nohup tcpdump -i any -s 0 -w /sdcard/c700-capture.pcap >/sdcard/c700-tcpdump.log 2>&1 &' >/dev/null
"$ADB" exec-out screencap -p > "$cap_dir/00-start.png"

echo "CAP_DIR=$cap_dir"
echo "START=$(date '+%H:%M:%S')"
echo "Capture is running. Keep this process alive while operating Mi Home."
echo "Press Ctrl-C to stop and pull artifacts."

while true; do
  sleep 5
  if ! kill -0 "$mitm_pid" >/dev/null 2>&1; then
    echo "mitmdump exited early; see $cap_dir/mitmdump.log" >&2
    exit 1
  fi
  if ! kill -0 "$logcat_pid" >/dev/null 2>&1; then
    echo "logcat exited early; see $cap_dir/logcat.txt" >&2
    exit 1
  fi
done
