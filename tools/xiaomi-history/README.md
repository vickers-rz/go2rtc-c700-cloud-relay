# xiaomi-history

Prototype CLI for reverse engineering Xiaomi C700 SD-card history listing and
one-minute downloads.

This tool intentionally does not pretend the private history protocol is known.
It implements the local project integration points now available:

- Reads the existing `config/go2rtc.yaml` Xiaomi token and stream metadata.
- Lists configured C700 streams.
- Can ask the running patched go2rtc API for Xiaomi camera discovery.
- Creates reproducible capture-session folders for Mi Home black-box testing.
- Provides stable `list` and `download` command surfaces for the future protocol
  implementation.
- Provides a PTZ command envelope for the Mi Home pan/tilt operations already
  found in the plugin bundle.

## Install

```sh
cd ~/Documents/go2rtc-c700-cloud-relay/tools/xiaomi-history
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -e '.[dev]'
```

## Commands

From the repository root:

```sh
xiaomi-history cameras
xiaomi-history go2rtc-cameras
xiaomi-history capture-session --label mac-ios
xiaomi-history list --camera c700 --date 2026-06-08 --expected
xiaomi-history ptz --camera c700 --direction left --expected
xiaomi-history ptz --camera c700 --direction get-angle --expected --json
```

Reserved final commands:

```sh
xiaomi-history list --camera c700 --date 2026-06-08
xiaomi-history download --camera c700 --start "2026-06-08 13:01:00" --output 20260608_130100.mp4
xiaomi-history ptz --camera c700 --direction left
```

Until the Mi Home history request, media framing, and Xiaomi P2P command sender
are wired into this prototype, the non-`--expected` commands exit with code `2`
and explain which implementation piece is missing.

Known PTZ operation values:

```text
left       {"operation": 1}
right      {"operation": 2}
up         {"operation": 3}
down       {"operation": 4}
calibrate  {"operation": 5}
get-angle  {"operation": 6}
stop       {"operation": -1001}
```

## Capture Workflow

Create one folder per test session:

```sh
xiaomi-history capture-session --label android-avd
```

Run the five experiments in the generated folder:

1. App idle.
2. C700 live view.
3. SD-card timeline open, no playback.
4. SD-card playback for one known minute.
5. Download that same minute.

Collect `pcapng`, mitmproxy exports, Android `logcat`, and the downloaded media
file when available. Keep real tokens, device IDs, captures, and videos out of
Git.
