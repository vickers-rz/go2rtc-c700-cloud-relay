from xiaomi_history.config import CameraConfig
from xiaomi_history.ptz import build_ptz_command


def test_build_ptz_command_uses_motor_miss_command() -> None:
    camera = CameraConfig(
        name="c700",
        user_id="user",
        region="cn",
        host="192.0.2.10",
        did="123",
        model="chuangmi.camera.81ac1",
    )

    command = build_ptz_command(camera, "left")

    assert command.camera_id == "c700"
    assert command.direction == "left"
    assert command.operation == 1
    assert command.params == {"operation": 1}
    assert command.to_dict() == {
        "camera_id": "c700",
        "direction": "left",
        "transport": "xiaomi-c700-miss",
        "miss_command": "MISS_CMD_MOTOR_REQ",
        "params": {"operation": 1},
    }
    assert command.transport == "xiaomi-c700-miss"
    assert command.miss_command == "MISS_CMD_MOTOR_REQ"


def test_build_ptz_command_maps_known_operations() -> None:
    camera = CameraConfig(
        name="c700",
        user_id="user",
        region="cn",
        host="192.0.2.10",
        did="123",
        model="chuangmi.camera.81ac1",
    )

    assert build_ptz_command(camera, "right").operation == 2
    assert build_ptz_command(camera, "up").operation == 3
    assert build_ptz_command(camera, "down").operation == 4
    assert build_ptz_command(camera, "calibrate").operation == 5
    assert build_ptz_command(camera, "get-angle").operation == 6
    assert build_ptz_command(camera, "stop").operation == -1001
