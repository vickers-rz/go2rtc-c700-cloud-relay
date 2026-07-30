from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from .config import CameraConfig
from .playback import ProtocolNotMappedError


PtzDirection = Literal["up", "down", "left", "right", "stop", "calibrate", "get-angle"]


PTZ_OPERATION_BY_DIRECTION: dict[PtzDirection, int] = {
    "left": 1,
    "right": 2,
    "up": 3,
    "down": 4,
    "calibrate": 5,
    "get-angle": 6,
    "stop": -1001,
}


@dataclass(frozen=True)
class PtzCommand:
    camera_id: str
    direction: PtzDirection
    operation: int
    transport: str = "xiaomi-c700-miss"
    miss_command: str = "MISS_CMD_MOTOR_REQ"

    @property
    def params(self) -> dict[str, int]:
        return {"operation": self.operation}

    def to_dict(self) -> dict[str, object]:
        return {
            "camera_id": self.camera_id,
            "direction": self.direction,
            "transport": self.transport,
            "miss_command": self.miss_command,
            "params": self.params,
        }


def build_ptz_command(camera: CameraConfig, direction: PtzDirection) -> PtzCommand:
    return PtzCommand(
        camera_id=camera.name,
        direction=direction,
        operation=PTZ_OPERATION_BY_DIRECTION[direction],
    )


def move(camera: CameraConfig, direction: PtzDirection) -> None:
    command = build_ptz_command(camera, direction)
    raise ProtocolNotMappedError(
        f"PTZ command is mapped to {command.miss_command} with "
        f"params={command.params}, but the Xiaomi CS2/P2P command sender is not "
        "wired into this prototype yet."
    )
