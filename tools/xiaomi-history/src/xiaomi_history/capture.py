from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


EXPERIMENTS = [
    ("A_idle", "Open Mi Home and leave it idle for 60 seconds."),
    ("B_live", "Open the C700 live view and keep it playing for 60 seconds."),
    ("C_timeline", "Open SD-card history timeline, but do not play video."),
    ("D_playback", "Play one known minute from SD-card history."),
    ("E_download", "Download that same one-minute history segment."),
]


@dataclass(frozen=True)
class CaptureSession:
    path: Path


def create_capture_session(root: Path, label: str | None = None) -> CaptureSession:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    suffix = f"-{label}" if label else ""
    path = root / f"{stamp}{suffix}"
    path.mkdir(parents=True, exist_ok=False)

    (path / "README.md").write_text(_readme_text(), encoding="utf-8")
    (path / "metadata.yaml").write_text(_metadata_text(), encoding="utf-8")
    for name, instructions in EXPERIMENTS:
        (path / f"{name}.md").write_text(_experiment_text(name, instructions), encoding="utf-8")
    return CaptureSession(path=path)


def _metadata_text() -> str:
    return """# Fill this before or during capture.
camera:
  name: c700
  ip:
  did:
  model:
  firmware:
mi_home:
  platform: mac-ios | android-avd | android-phone
  app_version:
  region:
network:
  mac_ip:
  openwrt_ip:
  capture_interface:
target_minute:
  local_start:
  local_end:
notes:
"""


def _readme_text() -> str:
    names = "\n".join(f"- `{name}`: {desc}" for name, desc in EXPERIMENTS)
    return f"""# Xiaomi C700 History Capture Session

Run the experiments in order and keep the target historical minute identical
for playback and download.

{names}

Expected files per experiment:

- `<experiment>.pcapng`
- `<experiment>.mitm`
- `<experiment>.logcat.txt` for Android runs
- downloaded media file for `E_download`
"""


def _experiment_text(name: str, instructions: str) -> str:
    return f"""# {name}

Action: {instructions}

Start time:
End time:

Files collected:

- pcapng:
- mitm export:
- logcat:
- downloaded media:

Observations:
"""

