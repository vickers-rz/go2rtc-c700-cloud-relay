#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

FRIDA_VERSION="$("$FRIDA_VENV/bin/python" - <<'PY'
import frida
print(frida.__version__)
PY
)"
SERVER="$HOME/.local/share/frida-server/frida-server-${FRIDA_VERSION}-android-arm64"

if [[ ! -x "$SERVER" ]]; then
  echo "Missing frida-server: $SERVER" >&2
  exit 1
fi

"$ADB" root >/dev/null
"$ADB" push "$SERVER" /data/local/tmp/frida-server >/dev/null
"$ADB" shell chmod 755 /data/local/tmp/frida-server
"$ADB" shell 'pkill frida-server 2>/dev/null || true; nohup /data/local/tmp/frida-server >/data/local/tmp/frida-server.log 2>&1 &'
sleep 1
"$FRIDA_VENV/bin/frida-ps" -U | head -20

