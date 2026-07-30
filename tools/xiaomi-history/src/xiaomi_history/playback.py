from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta

from .config import CameraConfig


class ProtocolNotMappedError(RuntimeError):
    """Raised until the Xiaomi Home SD-card history protocol is mapped."""


@dataclass(frozen=True)
class RecordingSegment:
    id: str
    camera_id: str
    start: datetime
    end: datetime
    source: str = "xiaomi-c700-sdcard"


def expected_minute_window(camera: CameraConfig, day: date) -> list[RecordingSegment]:
    """Return deterministic minute IDs for planning and fixture work.

    This is not a device query. It is useful when comparing Mi Home screenshots,
    downloaded files, and captures while the real history-list command is still
    being reverse engineered.
    """

    start = datetime.combine(day, datetime.min.time())
    segments: list[RecordingSegment] = []
    for minute in range(24 * 60):
        segment_start = start + timedelta(minutes=minute)
        segment_end = segment_start + timedelta(minutes=1)
        segments.append(
            RecordingSegment(
                id=f"xiaomi:{camera.did}:{segment_start:%Y%m%d%H%M%S}",
                camera_id=camera.name,
                start=segment_start,
                end=segment_end,
            )
        )
    return segments


def list_segments(_: CameraConfig, __: date) -> list[RecordingSegment]:
    raise ProtocolNotMappedError(
        "Xiaomi C700 SD-card timeline query is not mapped yet. "
        "Run the capture workflow and map the Mi Home playback/list request first."
    )


def download_segment(_: CameraConfig, __: datetime, ___: str) -> None:
    raise ProtocolNotMappedError(
        "Xiaomi C700 SD-card download command is not mapped yet. "
        "Capture Mi Home downloading the same minute and identify the control "
        "command plus media payload framing before enabling this command."
    )

