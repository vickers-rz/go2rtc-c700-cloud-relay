#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

"$ADB" kill-server
"$ADB" start-server
"$ADB" reconnect offline || true
"$ADB" wait-for-device

for _ in $(seq 1 60); do
  state="$("$ADB" get-state 2>/dev/null || true)"
  booted="$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$state" == "device" && "$booted" == "1" ]]; then
    "$ADB" devices -l
    exit 0
  fi
  sleep 2
done

echo "ADB did not become stable; restart the AVD with tools/android-lab/start-avd.sh" >&2
"$ADB" devices -l
exit 1
