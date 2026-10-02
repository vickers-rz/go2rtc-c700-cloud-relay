# C700 SD Timeline Indexer

This tool persists Xiaomi C700 microSD timeline metadata on the Raspberry Pi so
retention decisions do not depend on how long the camera itself keeps its
rolling SD index.

## Protocol

The Mi Home camera transport uses Xiaomi MISS over CS2/TCP. Packet capture and
live C700 tests confirm:

- CS2 channel `0`: MISS command/control.
- CS2 channel `1`: RDT (Reliable Data Transfer).
- CS2 channel `2`: media.

RDT payloads use the same MISS shared-key `crypto.Encode` / `crypto.Decode`
path already present in go2rtc. The local patches expose channel 1 through
`ReadRDT` and `WriteRDT`.

### Command 6: SD file timeline

The request is a 24-byte little-endian payload whose first uint32 is `6` and
whose channel field at offset 16 is `0` for the C700 PTZ channel.

Each returned SD record is 8 bytes:

```text
0..3  uint32 LE  start Unix time (seconds)
4     uint8      duration seconds; zero means 60
5     uint8      motion flag
6     uint8      saved flag
7     uint8      deleting flag
```

On 2026-09-17 the physical C700 returned roughly 1,670 records covering about
25 hours. A normal command-6 poll takes about 1.2 seconds on the Pi 3B.

### Command 11: event type enrichment

Mi Home asks command 11 after command 6. The request embeds JSON:

```json
{"mac":"F1F2F3F4F5F6","time":"YYYYMMDD"}
```

The response is paginated. Each 32-byte event record contains:

```text
+0  uint64 LE  start Unix time (seconds)
+8  uint32 LE  SD event type
```

For the 2026-09-16 sample:

```text
command-6 motion starts  579
command-11 unique events 579
exact timestamp matches  579
PeopleMotion              42
Face                     537
```

Thus command 11 is an enrichment layer for command-6 motion segments, not an
independent timeline. Event enrichment is deliberately not required for safe
deletion: command 6 remains the authoritative motion/still signal.

## Runtime layout

```text
/usr/local/libexec/c700-rdt-list
/usr/local/sbin/c700-sd-indexer
/etc/systemd/system/c700-sd-indexer.service
/etc/systemd/system/c700-sd-indexer.timer
/var/lib/c700-video-cleanup/timeline.sqlite3
```

The timer runs about every 10 minutes. Each run always polls command 6. Command
11 is requested only if the last successful event sync is at least one hour
old.

The Go helper resolves the current camera LAN address through Xiaomi
`/v2/home/device_list_page`; it does not rely on a hard-coded DHCP address.

## SQLite

`segments` is keyed by `(did, start_ts)` and keeps the historical timeline even
after the camera rotates its own microSD index. Important fields are:

```text
start_ts, duration_s, end_ts
motion, saved
event_type, event_name, event_seen_ts
first_seen_ts, last_seen_ts
```

Existing databases created before event enrichment are migrated online with
`ALTER TABLE`; existing rows are retained.

Metadata includes:

```text
last_success_ts
last_success_host
last_events_attempt_ts
last_events_success_ts
last_events_count
last_events_matched
last_events_days
last_events_error
```

## Retention safety

`c700-retention-agent.py` reads this database in read-only mode. A deletion is
authorized only when the requested recording interval has complete timeline
coverage and every overlapping segment is `motion=false` and `saved=0`.
Unknown, missing, stale, motion, or saved timeline state fails closed.

Command-11 labels are returned to the N100 planner for audit statistics only;
they do not broaden deletion permission.

## Build

The build is pinned to the tested upstream go2rtc commit in
`build-rdt-list.sh` and applies the repository's `patches/client.go` and
`patches/conn.go` before building.

```sh
tools/c700-sd-indexer/build-rdt-list.sh dist/c700-rdt-list-linux-arm64
```

## Useful checks

```sh
systemctl list-timers c700-sd-indexer.timer
journalctl -u c700-sd-indexer.service -n 30
sqlite3 /var/lib/c700-video-cleanup/timeline.sqlite3 \
  'select event_name,count(*) from segments where event_type is not null group by event_name;'
```
