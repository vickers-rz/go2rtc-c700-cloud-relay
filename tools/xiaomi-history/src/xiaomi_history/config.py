from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

import yaml


@dataclass(frozen=True)
class XiaomiToken:
    user_id: str
    token: str


@dataclass(frozen=True)
class CameraConfig:
    name: str
    user_id: str
    region: str
    host: str
    did: str
    model: str
    subtype: str | None = None


@dataclass(frozen=True)
class AppConfig:
    path: Path
    tokens: dict[str, XiaomiToken]
    cameras: dict[str, CameraConfig]
    go2rtc_api: str = "http://127.0.0.1:1984"


def load_config(path: Path) -> AppConfig:
    if not path.exists():
        raise FileNotFoundError(f"config not found: {path}")

    raw = yaml.safe_load(path.read_text()) or {}
    tokens = {
        str(user_id): XiaomiToken(user_id=str(user_id), token=str(token))
        for user_id, token in (raw.get("xiaomi") or {}).items()
    }

    cameras: dict[str, CameraConfig] = {}
    for name, value in (raw.get("streams") or {}).items():
        if isinstance(value, list):
            values = value
        else:
            values = [value]
        for stream_url in values:
            if not isinstance(stream_url, str) or not stream_url.startswith("xiaomi://"):
                continue
            camera = parse_xiaomi_stream(name, stream_url)
            cameras[name] = camera
            break

    return AppConfig(path=path, tokens=tokens, cameras=cameras)


def parse_xiaomi_stream(name: str, stream_url: str) -> CameraConfig:
    parsed = urlparse(stream_url)
    if parsed.scheme != "xiaomi":
        raise ValueError(f"not a xiaomi stream: {name}")

    if not parsed.username:
        raise ValueError(f"xiaomi stream has no user id: {name}")

    query = parse_qs(parsed.query)

    def one(key: str) -> str:
        values = query.get(key)
        if not values or values[0] == "":
            raise ValueError(f"xiaomi stream {name} missing query parameter: {key}")
        return values[0]

    return CameraConfig(
        name=name,
        user_id=unquote(parsed.username),
        region=unquote(parsed.password or ""),
        host=parsed.hostname or "",
        did=one("did"),
        model=one("model"),
        subtype=(query.get("subtype") or [None])[0],
    )

