from __future__ import annotations

import argparse
import json
import signal
import sys
from datetime import date, datetime
from pathlib import Path

from .capture import create_capture_session
from .config import load_config
from .go2rtc import fetch_go2rtc_cameras, local_cameras, resolve_camera
from .playback import ProtocolNotMappedError, download_segment, expected_minute_window, list_segments
from .ptz import build_ptz_command, move


DEFAULT_CONFIG = Path("config/go2rtc.yaml")
DEFAULT_CAPTURE_ROOT = Path("captures")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="xiaomi-history")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--json", action="store_true", help="print machine-readable JSON where supported")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("cameras", help="list Xiaomi cameras from local config")

    cloud = sub.add_parser("go2rtc-cameras", help="list Xiaomi cameras via the running go2rtc API")
    cloud.add_argument("--user-id")
    cloud.add_argument("--region")

    list_cmd = sub.add_parser("list", help="list SD-card recording segments once protocol is mapped")
    list_cmd.add_argument("--camera", required=True)
    list_cmd.add_argument("--date", required=True, type=date.fromisoformat)
    list_cmd.add_argument(
        "--expected",
        action="store_true",
        help="print expected one-minute IDs without querying the camera",
    )

    download = sub.add_parser("download", help="download one SD-card minute once protocol is mapped")
    download.add_argument("--camera", required=True)
    download.add_argument("--start", required=True)
    download.add_argument("--output", required=True)

    ptz = sub.add_parser("ptz", help="move the camera once the P2P sender is wired")
    ptz.add_argument("--camera", required=True)
    ptz.add_argument(
        "--direction",
        required=True,
        choices=["up", "down", "left", "right", "stop", "calibrate", "get-angle"],
    )
    ptz.add_argument(
        "--expected",
        action="store_true",
        help="print the expected MISS command envelope without sending it",
    )

    capture = sub.add_parser("capture-session", help="create a reproducible capture session folder")
    capture.add_argument("--root", type=Path, default=DEFAULT_CAPTURE_ROOT)
    capture.add_argument("--label")

    return parser


def main(argv: list[str] | None = None) -> int:
    if hasattr(signal, "SIGPIPE"):
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)

    args = build_parser().parse_args(argv)

    try:
        if args.command == "capture-session":
            session = create_capture_session(args.root, args.label)
            print(session.path)
            return 0

        config = load_config(args.config)

        if args.command == "cameras":
            return print_result(local_cameras(config), args.json)

        if args.command == "go2rtc-cameras":
            return print_result(fetch_go2rtc_cameras(config, args.user_id, args.region), args.json)

        if args.command == "list":
            camera = resolve_camera(config, args.camera)
            segments = expected_minute_window(camera, args.date) if args.expected else list_segments(camera, args.date)
            return print_result([segment.__dict__ for segment in segments], args.json)

        if args.command == "download":
            camera = resolve_camera(config, args.camera)
            start = datetime.fromisoformat(args.start)
            download_segment(camera, start, args.output)
            return 0

        if args.command == "ptz":
            camera = resolve_camera(config, args.camera)
            if args.expected:
                return print_result(build_ptz_command(camera, args.direction).to_dict(), args.json)
            move(camera, args.direction)
            return 0

    except ProtocolNotMappedError as exc:
        print(f"not implemented: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    return 1


def print_result(value: object, as_json: bool) -> int:
    if as_json:
        print(json.dumps(value, ensure_ascii=False, indent=2, default=str))
    elif isinstance(value, list):
        for item in value:
            print(json.dumps(item, ensure_ascii=False, default=str))
    else:
        print(value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
