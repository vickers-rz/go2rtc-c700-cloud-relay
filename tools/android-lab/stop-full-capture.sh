#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

cap_dir="${1:-$(cat /tmp/c700-current-capdir)}"

for name in logcat mitmdump; do
  pid_file="$cap_dir/${name}.pid"
  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file")"
    if [[ -n "$pid" ]]; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  fi
done

"$ADB" shell 'pkill tcpdump 2>/dev/null || true'
sleep 1
"$ADB" pull /sdcard/c700-capture.pcap "$cap_dir/c700-capture.pcap" >/dev/null 2>&1 || true
"$ADB" pull /sdcard/c700-tcpdump.log "$cap_dir/c700-tcpdump.log" >/dev/null 2>&1 || true
"$ADB" exec-out screencap -p > "$cap_dir/99-end.png" || true

echo "CAP_DIR=$cap_dir"
ls -lh "$cap_dir"

