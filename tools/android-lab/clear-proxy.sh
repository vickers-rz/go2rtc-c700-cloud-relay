#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

"$ADB" shell settings put global http_proxy :0
"$ADB" shell settings get global http_proxy

