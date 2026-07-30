#!/bin/zsh
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$BASE_DIR/config/go2rtc.yaml"
MODE_FILE="$BASE_DIR/config/active-mode"

usage() {
  echo "Usage: $0 cloud|lan [subtype]|status"
  echo
  echo "cloud: use Xiaomi cs2 cloud-relay source"
  echo "lan:   use local LAN/P2P source via camera IP"
  echo "subtype: optional Xiaomi quality value: auto, sd, hd, or 0..5"
  echo "status: show current mode"
}

mode="${1:-}"
subtype="${2:-}"
if [[ -z "$mode" && -t 0 ]]; then
  echo "Choose C700 mode:"
  echo "1) cloud - Xiaomi cloud-relay"
  echo "2) lan   - local LAN/P2P"
  printf "> "
  read choice
  case "$choice" in
    1|cloud) mode="cloud" ;;
    2|lan) mode="lan" ;;
    *) usage; exit 1 ;;
  esac
fi

if [[ "$mode" == "status" ]]; then
  if [[ -f "$MODE_FILE" ]]; then
    echo "Current mode: $(cat "$MODE_FILE")"
  else
    echo "Current mode: unknown"
  fi
  echo "Stable RTSP: rtsp://127.0.0.1:8554/c700"
  echo "Synology RTSP: rtsp://127.0.0.1:8554/c700_synology?video=h265&audio=aac"
  echo "Cloud RTSP:  rtsp://127.0.0.1:8554/c700_remote_sim"
  echo "LAN RTSP:    rtsp://127.0.0.1:8554/c700_lan"
  exit 0
fi

case "$mode" in
  cloud)
    source_name="c700_remote_sim"
    ;;
  lan)
    source_name="c700_lan"
    ;;
  *)
    usage
    exit 1
    ;;
esac

source_line="$(awk -v name="$source_name" '$1 == name ":" { sub(/^[^:]+:[[:space:]]*/, ""); print; exit }' "$CONFIG_FILE")"
if [[ -z "$source_line" ]]; then
  echo "Missing stream source: $source_name"
  exit 1
fi

if [[ -n "$subtype" ]]; then
  case "$subtype" in
    auto|sd|hd|0|1|2|3|4|5) ;;
    *)
      echo "Invalid subtype: $subtype"
      usage
      exit 1
      ;;
  esac
  source_line="$(printf '%s\n' "$source_line" | sed -E 's/([?&])subtype=[^&]*&?/\1/; s/[?]$/?/; s/[&]$//; s/[?]&/?/')"
  if [[ "$source_line" == *"?"* ]]; then
    source_line="${source_line}&subtype=${subtype}"
  else
    source_line="${source_line}?subtype=${subtype}"
  fi
fi

tmp_file="$(mktemp)"
awk -v source="$source_line" '
  BEGIN { in_streams=0; wrote=0 }
  /^streams:[[:space:]]*$/ {
    in_streams=1
    print
    next
  }
  in_streams && /^[^[:space:]]/ {
    if (!wrote) {
      print "  c700: " source
      wrote=1
    }
    in_streams=0
  }
  in_streams && /^[[:space:]]+c700:[[:space:]]/ {
    if (!wrote) {
      print "  c700: " source
      wrote=1
    }
    next
  }
  { print }
  END {
    if (in_streams && !wrote) {
      print "  c700: " source
    }
  }
' "$CONFIG_FILE" > "$tmp_file"
mv "$tmp_file" "$CONFIG_FILE"
echo "$mode" > "$MODE_FILE"
if [[ -n "$subtype" ]]; then
  echo "$mode subtype=$subtype" > "$MODE_FILE"
fi

echo "C700 mode set to: $(cat "$MODE_FILE")"
echo "Stable RTSP: rtsp://127.0.0.1:8554/c700"
echo "Synology RTSP: rtsp://127.0.0.1:8554/c700_synology?video=h265&audio=aac"
echo "Web preview: http://127.0.0.1:1984/stream.html?src=c700&mode=mse"
