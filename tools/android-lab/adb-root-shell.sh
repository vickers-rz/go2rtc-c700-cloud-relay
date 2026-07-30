#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

"$ADB" root >/dev/null
exec "$ADB" shell

