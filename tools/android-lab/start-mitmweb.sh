#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

exec mitmweb --listen-host 0.0.0.0 --listen-port "$MITM_PORT"

