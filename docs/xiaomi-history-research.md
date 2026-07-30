# Xiaomi C700 History Research Notes

## Current Reusable Pieces

The local go2rtc build already proves these pieces work against the C700:

- Xiaomi Home token-based cloud login from `config/go2rtc.yaml`.
- Device metadata from Xiaomi cloud, including `did`, model, and local IP.
- `miss_get_vendor` lookup for P2P vendor parameters.
- CS2 cloud relay handshake and fallback relay hosts.
- Real-time media session setup for go2rtc RTSP/WebRTC output.

## Missing Protocol Pieces

The SD-card history feature still needs these fields mapped from Mi Home:

- Timeline/list request endpoint or P2P command.
- Date/time format and timezone handling.
- Response structure for available one-minute segments.
- Playback/download command ID and parameters.
- Media payload framing, encryption, and end-of-file marker.
- Whether the App downloads an existing file, remuxes a playback stream, or saves
  locally from a history playback session.

## Evidence Needed Before Implementing Download

For a single known minute, collect:

- Mi Home operation timestamps.
- Mac/OpenWrt `pcapng` for idle, live, timeline, playback, and download.
- Android `logcat` for timeline, playback, and download.
- mitmproxy flows if TLS can be decrypted.
- The downloaded file and `ffprobe` output.

The first implementation should use only fields observed in these captures.

## Static Findings from Pulled Mi Home Plugins

The pulled runtime plugin bundle for `chuangmi.camera.81ac1` confirms that C700
uses the Mi Home camera bridge rather than RTSP for both SD-card playback and
PTZ control.

### SD-card Timeline and Download

The standard camera storage module builds timeline requests with:

- domain: `business.smartcamera`
- API: `/common/app/get/eventlist`
- method flag: `false`
- common params: `region: "CN"`, `did: Device.deviceID`
- list params: `model`, `eventType`, `beginTime`, `endTime`, `limit`,
  `needMerge`, `doorBell`, `sortType`

The list response is consumed from `result.data.thirdPartPlayUnits`. Each item
contains fields used by the UI and downloader:

- `createTime`
- `eventType`
- `imgStoreId`
- `fileId`
- `isRead`
- `offset`
- optional related `minorFileId` from `extraInfo.relatedFileId`

Selected videos are downloaded by the native camera module:

```text
Service.miotcamera.downloadM3U8ToMP4V2(
  fileId,
  outputPath,
  "M3U8ToMP4CallBack",
  true,
  "H265"
)
```

Playback URLs are requested through:

```text
Service.miotcamera.getVideoFileUrl(fileId, true, "H265", Device.deviceID)
```

This means the first API clone should reproduce the cloud event-list request
first, then map what the native `getVideoFileUrl` / `downloadM3U8ToMP4V2`
methods do with the returned `fileId`.

### Historical Playback

The C700 plugin starts historical playback by sending a MISS P2P command:

```text
MISS_CMD_PLAYBACK_REQ
```

with params:

```json
{
  "sessionid": "<startTime>",
  "starttime": "<startTime>",
  "endtime": "<endTime>",
  "autoswitchtolive": 0,
  "offset": "<offset>",
  "speed": "<speed>",
  "avchannelmerge": 1
}
```

Speed changes use `MISS_CMD_PLAYBACK_SET_SPEED`; stopping playback uses
`MISS_CMD_VIDEO_STOP`.

### PTZ Control

The C700 plugin exposes camera movement through:

```text
Service.miotcamera.sendP2PCommandToDevice(MISS_CMD_MOTOR_REQ, obj)
```

where:

```json
{
  "operation": "<direction-or-action>"
}
```

Static bundle constants map the basic operations as:

```text
left       1
right      2
up         3
down       4
calibrate  5
get-angle  6
stop      -1001
set-angle 13  with {"angle": h, "elevation": v}
```

The command transport is therefore likely the existing Xiaomi camera
P2P/MISS channel already used for live video and historical playback. The
remaining implementation work is to wire the standalone prototype into a
working Xiaomi CS2/P2P command sender and confirm the values on the physical
C700.

## Runtime Hook

Use the Frida probe while manually operating Mi Home:

```sh
tools/android-lab/hook-xiaomi-camera-api.sh
```

Expected useful output:

- `callSmartHomeCameraAPI` calls for `/common/app/get/eventlist` and
  `/miot/camera/app/v1/get/fileIdMetas`
- `getVideoFileUrl(fileId, true, "H265", did)`
- `downloadM3U8ToMP4V2(fileId, outputPath, "M3U8ToMP4CallBack", true, "H265")`
- `sendP2PCommandToDevice(MISS_CMD_PLAYBACK_REQ, params)`
- `sendP2PCommandToDevice(MISS_CMD_MOTOR_REQ, {"operation": ...})`

The hook script redacts common token/cookie fields before printing.

## Dynamic Capture: 2026-07-30 16:34

Capture directory:

```text
captures/c700-history-api-2-20260730-163416
```

Artifacts collected:

- `c700-capture.pcap` raw packet capture.
- `flows.mitm` mitmproxy flow dump.
- `logcat.txt` Android logcat.
- `frida-camera-api.log` Frida probe output.
- `downloaded-videos/` pulled Mi Home output videos.

Pulled Mi Home output files:

```text
VIDEO_20260730_163541834.mp4  60.032s  HEVC 3840x2160  AAC mono 16 kHz
VIDEO_20260730_163714008.mp4  60.032s  HEVC 3840x2160  AAC mono 16 kHz
VIDEO_20260730_163720161.mp4  60.032s  HEVC 3840x2160  AAC mono 16 kHz
```

Packet-level evidence:

- C700 local IP observed in the capture: `192.168.31.215`.
- The dominant media flow was local TCP from `192.168.31.215:11427` to the
  emulator at `10.0.2.16:50936`.
- Approximate TCP payload in that direction was 39 MB during the capture.
- Emulator-to-camera traffic on the same connection was tiny by comparison.

This strongly suggests that Mi Home uses cloud APIs for metadata and
coordination, but the historical video payload itself is delivered over a
camera/P2P media channel rather than as a simple HTTPS MP4 download.

mitmproxy-visible endpoints included:

- `app.business.smartcamera.api.mijia.tech/common/app/get/eventlist`
- `app.business.smartcamera.api.mijia.tech/common/app/get/downloadImgDomain`
- `app.business.smartcamera.api.mijia.tech/miot/camera/...`
- `core.api.mijia.tech/app/miotspec/prop/get`
- `api.mijia.tech/app/home/rpc/<did>`

The request query payloads are still Mi Home encrypted/signed (`data`,
`rc4_hash__`, `_nonce`, `ssecurity`, `signature`), so avoid committing raw
mitmproxy exports outside ignored capture directories.

Frida confirmed the Java bridge methods are present, but this run did not log
runtime calls for `downloadM3U8ToMP4V2` or `getVideoFileUrl`. Likely causes:

- The relevant method was invoked before the hook completed.
- The React Native bridge dispatch path bypassed the concrete class hook.
- This screen path used a lower-level native download/playback method.

The hook now also probes React Native `JavaMethodWrapper.invoke`, media muxer
creation, and content/file output streams so the next run should capture the
actual module name and argument array.

## Next Capture Checklist

For SD-card history download:

1. Start `capture-live.sh`.
2. Start `hook-xiaomi-camera-api.sh` against the new capture directory.
3. Open the C700 camera page.
4. Enter storage management and the microSD tab.
5. Play one known minute.
6. Select and download the same minute.
7. Wait until the download succeeds or fails.
8. Stop Frida and capture.
9. Pull `VIDEO_*.mp4` files and run `ffprobe`.

For PTZ:

1. Start capture and Frida before entering the live camera page.
2. Press exactly one direction at a time: left, right, up, down.
3. Pause at least 3 seconds between presses.
4. If the UI has press-and-hold behavior, do one short tap and one long press
   per direction in separate marked windows.
5. Look for `MISS_CMD_MOTOR_REQ` and the `operation` value in
   `rn-java-method-invoke` or `sendP2PCommandToDevice` logs.

## Dynamic Capture: 2026-07-30 18:01

Capture directory:

```text
captures/c700-history-api-3-20260730-180139
```

Observed output:

```text
VIDEO_20260730_180438915.mp4  61.248s  HEVC 3840x2160  AAC mono 16 kHz
```

Packet-level evidence again showed the dominant stream from C700 local IP
`192.168.31.215:11427` to the emulator at `10.0.2.16:50936`, with about 25 MB
of TCP payload from camera to emulator.

Logcat showed repeated IJK player sessions using:

```text
rtmj:did=<did>&videoType=2&sampleRate=16000&audioType=2&channel=1&dataBits=2&fps=400
```

The new MP4 was opened by Android MediaProvider at `18:04:49`.

Important hook issue found in this run:

- Frida was attached to base process `com.xiaomi.smarthome` PID 9700.
- Playback/download logs came from `com.xiaomi.smarthome:camera` PID 14355.
- The hook script now prefers `com.xiaomi.smarthome:camera` and only falls back
  to the base process if the camera process is not alive.
