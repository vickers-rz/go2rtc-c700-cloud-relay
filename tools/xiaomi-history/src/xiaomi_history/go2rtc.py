from __future__ import annotations

from dataclasses import asdict

import httpx

from .config import AppConfig, CameraConfig


def local_cameras(config: AppConfig) -> list[dict[str, str | None]]:
    return [asdict(camera) for camera in sorted(config.cameras.values(), key=lambda c: c.name)]


def fetch_go2rtc_cameras(config: AppConfig, user_id: str | None = None, region: str | None = None) -> list[dict]:
    """Ask the local patched go2rtc API for Xiaomi camera devices.

    This reuses the existing go2rtc Xiaomi cloud login implementation rather than
    duplicating Xiaomi signed cloud requests in the first Python prototype.
    """

    if user_id is None:
        if not config.tokens:
            raise ValueError("no Xiaomi users configured")
        user_id = sorted(config.tokens)[0]
    if region is None:
        regions = {camera.region for camera in config.cameras.values() if camera.user_id == user_id}
        region = sorted(regions)[0] if regions else "cn"

    url = f"{config.go2rtc_api.rstrip('/')}/api/xiaomi"
    response = httpx.get(url, params={"id": user_id, "region": region}, timeout=10)
    response.raise_for_status()
    return response.json()


def resolve_camera(config: AppConfig, name: str) -> CameraConfig:
    try:
        return config.cameras[name]
    except KeyError as exc:
        available = ", ".join(sorted(config.cameras)) or "none"
        raise KeyError(f"unknown camera {name!r}; available: {available}") from exc

