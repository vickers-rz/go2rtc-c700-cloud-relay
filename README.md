# go2rtc C700 Cloud Relay

This folder contains a tested go2rtc build for Xiaomi C700 cloud-relay streaming.

## Start

Double-click `start-go2rtc.command`, or run:

```sh
~/Documents/go2rtc-c700-cloud-relay/start-go2rtc.command
```

Web UI:

```text
http://127.0.0.1:1984
```

RTSP stream:

```text
rtsp://127.0.0.1:8554/c700
```

## Switch C700 Mode

Use the stable stream name `c700` for players and automation.

```sh
~/Documents/go2rtc-c700-cloud-relay/switch-mode.command cloud
~/Documents/go2rtc-c700-cloud-relay/switch-mode.command lan
~/Documents/go2rtc-c700-cloud-relay/switch-mode.command lan 5
```

Then restart go2rtc:

```sh
~/Documents/go2rtc-c700-cloud-relay/uninstall-autostart.command
~/Documents/go2rtc-c700-cloud-relay/install-autostart.command
```

Direct stream names are also available:

```text
rtsp://127.0.0.1:8554/c700_remote_sim
rtsp://127.0.0.1:8554/c700_lan
```

## Stop

Double-click `stop-go2rtc.command`, or run:

```sh
~/Documents/go2rtc-c700-cloud-relay/stop-go2rtc.command
```

## Notes

- `config/go2rtc.yaml` contains local Xiaomi account credentials. Keep this folder private.
- `config/go2rtc.yaml` is intentionally excluded from Git.
- `config/go2rtc.example.yaml` is a redacted template.
- `bin/go2rtc` is a patched build based on AlexxIT/go2rtc PR #2264 with additional relay fallback addresses observed from the C700.
- `patches/` keeps the two changed source files for traceability.
