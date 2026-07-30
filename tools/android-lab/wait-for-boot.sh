#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

"$ADB" wait-for-device
for _ in $(seq 1 120); do
  booted="$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  if [[ "$booted" == "1" ]]; then
    echo "boot_completed=1"
    exit 0
  fi
  sleep 2
done

echo "Timed out waiting for Android boot" >&2
exit 1

