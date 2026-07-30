#!/usr/bin/env bash
set -euo pipefail

export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export ADB="$ANDROID_HOME/platform-tools/adb"
export EMULATOR="$ANDROID_HOME/emulator/emulator"
export AVD_NAME="C700_API31_GoogleAPIs"
export MITM_HOST="10.0.2.2"
export MITM_PORT="8080"
export FRIDA_VENV="$HOME/venvs/xiaomi-reverse"
