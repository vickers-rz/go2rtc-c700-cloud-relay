#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

exec "$EMULATOR" \
  -avd "$AVD_NAME" \
  -no-window \
  -no-audio \
  -no-boot-anim \
  -writable-system \
  -no-snapshot-load \
  -no-snapshot-save \
  -gpu swiftshader_indirect
