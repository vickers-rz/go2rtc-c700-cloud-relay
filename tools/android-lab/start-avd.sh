#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

exec "$EMULATOR" \
  -avd "$AVD_NAME" \
  -writable-system \
  -no-snapshot-load \
  -no-snapshot-save
