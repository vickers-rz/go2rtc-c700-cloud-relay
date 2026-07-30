#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source tools/android-lab/env.sh

echo "ADB:"
"$ADB" version | head -2

echo
echo "SDK:"
sdkmanager --list_installed | grep -E 'platform-tools|emulator|android-31|system-images'

echo
echo "AVD:"
avdmanager list avd | grep -E 'Name:|Target:|Tag/ABI:'

echo
echo "Device:"
"$ADB" devices
"$ADB" shell getprop ro.build.version.release
"$ADB" shell getprop ro.product.cpu.abi
"$ADB" root >/dev/null
"$ADB" shell id

echo
echo "Proxy:"
"$ADB" shell settings get global http_proxy

echo
echo "Frida:"
"$FRIDA_VENV/bin/frida" --version

