# C700 solar-night retention

Current architecture as of 2026-09-17.

The goal is to remove static overnight recordings while preserving intervals
where the C700 itself reports motion or a saved/event state. Solar boundaries
use Astral with Asia/Shanghai and the configured observer coordinates.

## Components

### C700 -> Pi recording backup

The C700 itself is the SMB client. On the Pi, `smbstatus` shows the camera at
`192.168.1.2` connected directly to the `[hdd_nfs]` share with SMB3.11.
There is no local ffmpeg/go2rtc recording process writing these MP4s.

The camera can upload microSD history faster than real time. Therefore:

- MP4 filename timestamps are the source-recording timeline.
- filesystem mtime is the later SMB upload/update time.
- a filename can legitimately be many hours behind current wall-clock time.

A 2026-09-17 sample showed about 22.3 hours of source lag while source time was
advancing about 1.64x real time. Retention must therefore tolerate multi-day
`hold` states while NAS backup catches up.

### Pi SD timeline indexer

`c700-sd-indexer.timer` polls the physical camera about every 10 minutes.

```text
C700 MISS/CS2 channel 1 (RDT)
  command 6 -> SD segment start/duration/motion/saved
  command 11 -> event-type enrichment (hourly at most)
        |
        v
/var/lib/c700-video-cleanup/timeline.sqlite3
```

Command 6 is the deletion safety authority. Command-11 labels are audit data;
a command-11 failure never converts unknown data into deletable data.

### N100 planner

Container: `c700-retention`.

The planner calls the Pi restricted agent over native IPv6 DDNS:

```text
ssh -6 wrz@pi.ic2id.fun
```

The restricted key invokes only the retention agent; it is not an arbitrary
remote shell interface.

HA/MQTT motion events remain an auxiliary protection signal. Xiaomi Home event
entities were observed to be unreliable (`unknown/unavailable`, no real event
history), so they are no longer required to authorize deletion.

### Pi restricted retention agent

Runtime:

```text
/usr/local/bin/c700-retention-agent.py
```

The agent inventories MP4s recursively so date folders created by the organizer
remain compatible. Paths are represented relative to the camera root, e.g.:

```text
2026-09-16/00_20260916180000_20260916180700.mp4
```

Before the first unlink, the agent independently re-reads local
`timeline.sqlite3`; it does not merely trust the N100 plan.

## Deletion policy

A solar night is eligible only after sunrise plus two hours.

The planner requires:

1. a recent successful RDT index (`last_success_ts` less than 30 minutes old),
2. Pi recording files covering the requested solar night,
3. no selected file modified within the last two hours,
4. a second identical file+timeline snapshot at least 30 minutes later,
5. execution inside 01:00-05:00 Asia/Shanghai.

First/last overlapping files and files crossing a solar boundary are mandatory
keeps.

For each interior MP4:

```text
saved != 0                    -> KEEP
any RDT motion=true overlap   -> KEEP
HA/MQTT event +/-180 seconds  -> KEEP
timeline missing/gapped       -> KEEP (unknown / fail closed)
complete RDT coverage,
  all motion=false,
  all saved=0                 -> DELETE candidate
```

The Pi agent repeats the RDT check immediately before deletion. Only plans with
reason `rdt_motion_filtered_night` may delete files. Old
`complete_healthy_night_without_events` plans no longer have deletion
authority.

Timeline gaps greater than five seconds within a recording's relevant interval
are treated as unknown and therefore protected.

## Backlog handling

New nights are considered from the last three days. Once a night reaches
`hold` or `ready`, it remains eligible for re-evaluation for up to 14 days.
This is specifically to support delayed C700 -> Pi SMB history backup.

When file coverage is incomplete, the decision record contains:

```text
latest_recording_end
required_night_end
source_lag_sec
```

When files are still arriving, the hold record contains the recent-file count
and newest mtime.

## Event-type audit metadata

RDT command 11 labels command-6 motion segments one-to-one in the validated
2026-09-16 sample. The SQLite and planner can report labels such as:

```text
ObjectMotion
PeopleMotion
Face
KnownFace
Pet
BabyCry
LouderSound
...
```

These labels are useful for audit/statistics only. A segment with
`motion=true` remains protected even if its event label is absent or unknown.

## Concurrency

These Pi-side mutators share:

```text
/var/lib/c700-video-cleanup/retention.lock
```

- `c700-retention-agent.py`
- `c700-clean-old-recordings.sh`
- `xiaomi-camera-organize`

They therefore do not move/delete the recording tree concurrently.

## Legacy rolling cleanup

`c700-clean-old-recordings.timer` remains the long-term capacity cleanup. The
script runs on its existing schedule and enforces at least 48 hours between
successful cleanups. It selects the oldest two eligible recording dates.

Current safeguards include:

- recursively understands date subdirectories,
- skips entries present in `night-protected.json`,
- skips files modified within the last two hours,
- uses the shared retention lock,
- logs every deleted relative path,
- removes only empty `YYYY-MM-DD` directories with `rmdir`,
- calls `sync` after real deletion,
- supports `C700_CLEANUP_DRY_RUN=1`.

This rolling cleanup remains a separate retention policy from selective night
pruning.

## Directory organizer

`xiaomi-camera-organize` groups old top-level files into `YYYY-MM-DD/`
directories using the filename's source-recording date. It does same-filesystem
renames only, skips recently modified files, and shares the retention lock.

## State and logs

Pi:

```text
/var/lib/c700-video-cleanup/timeline.sqlite3
/var/lib/c700-video-cleanup/night-protected.json
/var/lib/c700-video-cleanup/night-receipts/
/mnt/hdd_nfs/cleanup-logs/
```

N100:

```text
/mnt/nvme0n1-5/Configs/C700Retention/data/events.sqlite
/mnt/nvme0n1-5/Configs/C700Retention/data/plan-YYYY-MM-DD.json
```

Useful checks:

```sh
# Pi
systemctl list-timers c700-sd-indexer.timer
journalctl -u c700-sd-indexer.service -n 30
smbstatus -S

# N100
docker logs --tail 50 c700-retention
```

## Tests

The local regression suite covers solar boundaries, RDT selective retention,
Pi executor fail-closed behavior, legacy protected-file handling, and hold
re-evaluation beyond the original three-day window.

```sh
python -m unittest -v test_retention.py
```
