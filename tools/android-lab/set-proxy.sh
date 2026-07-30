#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

"$ADB" shell settings put global http_proxy "$MITM_HOST:$MITM_PORT"
"$ADB" shell settings get global http_proxy

