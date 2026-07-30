from pathlib import Path

from xiaomi_history.config import load_config, parse_xiaomi_stream


def test_parse_xiaomi_stream() -> None:
    camera = parse_xiaomi_stream(
        "c700",
        "xiaomi://123:cn@192.0.2.10?did=456&model=chuangmi.camera.81ac1&subtype=0",
    )

    assert camera.name == "c700"
    assert camera.user_id == "123"
    assert camera.region == "cn"
    assert camera.host == "192.0.2.10"
    assert camera.did == "456"
    assert camera.model == "chuangmi.camera.81ac1"
    assert camera.subtype == "0"


def test_load_config(tmp_path: Path) -> None:
    config = tmp_path / "go2rtc.yaml"
    config.write_text(
        """
xiaomi:
  "123": token
streams:
  c700: xiaomi://123:cn@192.0.2.10?did=456&model=chuangmi.camera.81ac1
  other: rtsp://example.invalid/live
""",
        encoding="utf-8",
    )

    loaded = load_config(config)

    assert sorted(loaded.tokens) == ["123"]
    assert sorted(loaded.cameras) == ["c700"]

