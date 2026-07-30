#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cap_dir="$(cat /tmp/c700-current-capdir)"
message="${*:-mark}"

{
  echo "  - time: '$(date '+%H:%M:%S')'"
  echo "    action: '$message'"
} >> "$cap_dir/markers.yaml"

echo "$(date '+%H:%M:%S') $message"

