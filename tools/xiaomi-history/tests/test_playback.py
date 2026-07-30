from datetime import date

from xiaomi_history.config import CameraConfig
from xiaomi_history.playback import expected_minute_window


def test_expected_minute_window() -> None:
    camera = CameraConfig(
        name="c700",
        user_id="123",
        region="cn",
        host="192.0.2.10",
        did="456",
        model="chuangmi.camera.81ac1",
    )

    segments = expected_minute_window(camera, date(2026, 6, 8))

    assert len(segments) == 1440
    assert segments[0].id == "xiaomi:456:20260608000000"
    assert segments[0].start.isoformat() == "2026-06-08T00:00:00"
    assert segments[-1].start.isoformat() == "2026-06-08T23:59:00"

