# Android Lab for Xiaomi C700 Research

This folder contains local helper scripts for the Android AVD used to inspect
Mi Home history playback and one-minute downloads.

## Installed Environment

- AVD: `C700_API31_GoogleAPIs`
- Android: 12 / API 31
- ABI: `arm64-v8a`
- Image: Google APIs, no Play Store, `dev-keys`
- Root: `adb root` works
- Writable system: start with `-writable-system`; `adb remount` works
- mitmproxy CA: installed as a system CA in the current AVD
- Frida: Python tools in `~/venvs/xiaomi-reverse`; matching server pushed to
  `/data/local/tmp/frida-server`

## Common Commands

Start the AVD:

```sh
tools/android-lab/start-avd.sh
```

Start mitmweb:

```sh
tools/android-lab/start-mitmweb.sh
```

After each emulator boot, set the emulator proxy:

```sh
tools/android-lab/set-proxy.sh
```

Clear proxy:

```sh
tools/android-lab/clear-proxy.sh
```

Start Frida server and verify it:

```sh
tools/android-lab/start-frida.sh
```

Attach the camera API probe to Mi Home:

```sh
tools/android-lab/hook-xiaomi-camera-api.sh
```

By default this attaches to `com.xiaomi.smarthome:camera`, because camera
playback/download runs in that process rather than the base
`com.xiaomi.smarthome` process. To override the process name:

```sh
tools/android-lab/hook-xiaomi-camera-api.sh captures/my-capture com.xiaomi.smarthome:plugin0
```

Leave it running while opening the C700 page, entering microSD history,
downloading one minute, and pressing the PTZ direction buttons. The probe logs
camera history, download, playback, and motor-control bridge calls with common
token and cookie fields redacted. Pass a capture directory to store the Frida
log beside the other artifacts:

```sh
tools/android-lab/hook-xiaomi-camera-api.sh captures/my-capture
```

Start a robust capture session:

```sh
tools/android-lab/start-full-capture.sh c700-history
```

This captures three layers at once:

- mitmproxy flows: `flows.mitm`
- Android logcat: `logcat.txt`
- raw AVD packet capture from Android tcpdump: `c700-capture.pcap`

Add timestamp markers while operating the app:

```sh
tools/android-lab/mark-capture.sh "tap microSD"
```

Stop and pull all artifacts:

```sh
tools/android-lab/stop-full-capture.sh
```

For manual app operation, prefer the foreground live capture so the capture
process cannot be cleaned up when the launching shell exits:

```sh
tools/android-lab/capture-live.sh c700-history
```

Leave it running while operating Mi Home, then press `Ctrl-C` to stop and pull
artifacts.

Open a shell:

```sh
tools/android-lab/adb-root-shell.sh
```

## Mi Home APK

Install a legally obtained Mi Home APK:

```sh
adb install XiaomiHome.apk
```

For split APKs:

```sh
adb install-multiple base.apk split_config.arm64_v8a.apk split_config.zh.apk
```

Expected package name is usually `com.xiaomi.smarthome`, but confirm with:

```sh
adb shell pm list packages | grep -i xiaomi
```
