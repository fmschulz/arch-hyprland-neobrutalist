#!/bin/bash

# Ensure volume keys adjust whichever PulseAudio/ PipeWire sink is currently
# playing audio (or, if idle, the first available sink).

set -euo pipefail

STEP="${2:-5}"
if ! [[ $STEP =~ ^[0-9]+$ ]]; then
  STEP=5
fi
if ! command -v pactl >/dev/null 2>&1; then
  echo "pactl is required but not available" >&2
  exit 1
fi

sink_dump=$(pactl list sinks)
mapfile -t sink_names < <(printf '%s\n' "$sink_dump" | awk -F': ' '$1 == "\tName" {print $2}')

if ((${#sink_names[@]} == 0)); then
  echo "No sinks found" >&2
  exit 1
fi

declare -a running_sinks=()
declare -a idle_sinks=()
declare -a other_sinks=()
current_name=""
current_state=""
while IFS= read -r line; do
  if [[ $line =~ ^Sink\ #[0-9]+ ]]; then
    current_name=""
    current_state=""
    continue
  fi
  if [[ $line =~ ^[[:space:]]*State:\ ([A-Z]+) ]]; then
    current_state=${BASH_REMATCH[1]}
    continue
  fi
  if [[ $line =~ ^[[:space:]]*Name:\ ([^[:space:]]+) ]]; then
    current_name=${BASH_REMATCH[1]}
    case "$current_state" in
      RUNNING)
        running_sinks+=("$current_name")
        ;;
      IDLE|UNKNOWN)
        idle_sinks+=("$current_name")
        ;;
      *)
        other_sinks+=("$current_name")
        ;;
    esac
  fi
done <<< "$sink_dump"

declare -a target_sinks
if ((${#running_sinks[@]})); then
  mapfile -t target_sinks < <(printf '%s\n' "${running_sinks[@]}" | awk '!seen[$0]++')
elif ((${#idle_sinks[@]})); then
  target_sinks=("${idle_sinks[0]}")
else
  target_sinks=("${sink_names[0]}")
fi

default_sink=$(pactl info | awk -F': ' '/^Default Sink: / {print $2; exit}')
if [[ -n ${target_sinks[0]:-} && $default_sink != "${target_sinks[0]}" ]]; then
  pactl set-default-sink "${target_sinks[0]}" >/dev/null
fi

case "${1:-}" in
  up)
    for sink in "${target_sinks[@]}"; do
      pactl set-sink-volume "$sink" "+${STEP}%"
    done
    ;;
  down)
    for sink in "${target_sinks[@]}"; do
      pactl set-sink-volume "$sink" "-${STEP}%"
    done
    ;;
  mute)
    for sink in "${target_sinks[@]}"; do
      pactl set-sink-mute "$sink" toggle
    done
    ;;
  *)
    echo "Usage: $0 {up|down|mute} [step-percent]" >&2
    exit 1
    ;;
esac
