#!/bin/bash

# Volume control helper for Hyprland media keys.
# Uses wpctl (PipeWire) if available, otherwise falls back to pactl.

set -euo pipefail

STEP="${2:-5}"
if ! [[ $STEP =~ ^[0-9]+$ ]]; then
  STEP=5
fi

action="${1:-}"
if [[ -z "$action" ]]; then
  echo "Usage: $0 {up|down|mute} [step-percent]" >&2
  exit 1
fi

if command -v wpctl >/dev/null 2>&1; then
  TARGET='@DEFAULT_AUDIO_SINK@'
  case "$action" in
    up)
      wpctl set-volume --limit 1.5 "$TARGET" "${STEP}%+"
      ;;
    down)
      wpctl set-volume "$TARGET" "${STEP}%-"
      ;;
    mute)
      wpctl set-mute "$TARGET" toggle
      ;;
    *)
      echo "Usage: $0 {up|down|mute} [step-percent]" >&2
      exit 1
      ;;
  esac
elif command -v pactl >/dev/null 2>&1; then
  # Fallback for systems without wpctl: adjust the current default sink
  DEFAULT_TARGET=$(pactl info | awk -F': ' '/Default Sink/ {print $2}')
  case "$action" in
    up)
      pactl set-sink-volume "$DEFAULT_TARGET" "+${STEP}%"
      ;;
    down)
      pactl set-sink-volume "$DEFAULT_TARGET" "-${STEP}%"
      ;;
    mute)
      pactl set-sink-mute "$DEFAULT_TARGET" toggle
      ;;
    *)
      echo "Usage: $0 {up|down|mute} [step-percent]" >&2
      exit 1
      ;;
  esac
else
  echo "Neither wpctl nor pactl found. Install PipeWire (wpctl) or pulseaudio-utils (pactl)." >&2
  exit 1
fi
