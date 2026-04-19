#!/bin/bash
# Keep trusted Bluetooth devices connected and promote preferred audio sinks.

set -uo pipefail

WATCH_MODE=false
WATCH_INTERVAL="${WATCH_INTERVAL:-30}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/arch-hypr-neobrutalist"
DEVICE_FILE="${DEVICE_FILE:-$CONFIG_DIR/bluetooth-devices.conf}"
DEVICE_SPECS=()

log() {
  echo "[bluetooth-autoconnect] $*"
}

load_device_specs() {
  if [[ ! -f "$DEVICE_FILE" ]]; then
    return 0
  fi

  mapfile -t DEVICE_SPECS < <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$DEVICE_FILE")
}

wait_for_bluetoothd() {
  for _ in {1..10}; do
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
      return 0
    fi
    sleep 1
  done
  log "Bluetooth service not ready after 10s"
  return 1
}

is_connected() {
  local mac=$1
  bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"
}

ensure_trusted() {
  local mac=$1
  if bluetoothctl info "$mac" 2>/dev/null | grep -q "Trusted: yes"; then
    return 0
  fi

  log "Trusting $mac"
  bluetoothctl trust "$mac" >/dev/null 2>&1 || true
}

connect_device() {
  local mac=$1
  local label=$2
  local attempts=${3:-1}

  for _ in $(seq 1 "$attempts"); do
    bluetoothctl connect "$mac" >/dev/null 2>&1 || true
    sleep 1

    if is_connected "$mac"; then
      log "Connected $label ($mac)"
      return 0
    fi
  done

  return 1
}

card_ready() {
  local card_name=$1
  pactl list cards short | awk -v card="$card_name" '$2 == card {found=1} END {exit found ? 0 : 1}'
}

set_best_profile() {
  local card_name=$1
  local profiles=(
    "a2dp-sink-aptx_ll"
    "a2dp-sink"
    "a2dp-sink-sbc_xq"
    "a2dp-sink-sbc"
  )

  for profile in "${profiles[@]}"; do
    if pactl set-card-profile "$card_name" "$profile" >/dev/null 2>&1; then
      log "Set $card_name to $profile"
      return 0
    fi
  done

  log "Unable to set A2DP profile on $card_name"
  return 1
}

promote_sink() {
  local mac=$1
  local sink_pattern="bluez_output.${mac//:/_}"
  local sink_name

  sink_name=$(pactl list short sinks | awk -v pattern="$sink_pattern" '$2 ~ "^" pattern {print $2; exit}')
  if [[ -z $sink_name ]]; then
    log "No sink found for $mac"
    return 1
  fi

  pactl set-default-sink "$sink_name"
  pactl list short sink-inputs | awk '{print $1}' | xargs -r -I{} pactl move-sink-input {} "$sink_name"
  log "Default sink set to $sink_name"
}

setup_audio_device() {
  local mac=$1
  local card_name="bluez_card.${mac//:/_}"

  for _ in {1..5}; do
    if card_ready "$card_name"; then
      set_best_profile "$card_name" || true
      promote_sink "$mac" || true
      return 0
    fi
    sleep 1
  done

  return 1
}

reconcile_devices() {
  local attempts=${1:-1}
  local spec mac kind label

  for spec in "${DEVICE_SPECS[@]}"; do
    IFS="|" read -r mac kind label <<<"$spec"

    ensure_trusted "$mac"

    if ! is_connected "$mac"; then
      if ! connect_device "$mac" "$label" "$attempts"; then
        continue
      fi
    fi

    if [[ "$kind" == "audio" ]]; then
      setup_audio_device "$mac" || true
    fi
  done
}

main() {
  if ! command -v bluetoothctl >/dev/null 2>&1 || ! command -v pactl >/dev/null 2>&1; then
    exit 0
  fi

  if [[ "${1:-}" == "--watch" ]]; then
    WATCH_MODE=true
  fi

  load_device_specs
  if [[ ${#DEVICE_SPECS[@]} -eq 0 ]]; then
    exit 0
  fi

  wait_for_bluetoothd || exit 0
  reconcile_devices 3

  if ! $WATCH_MODE; then
    exit 0
  fi

  trap 'exit 0' INT TERM

  while true; do
    sleep "$WATCH_INTERVAL"
    wait_for_bluetoothd || continue
    reconcile_devices 1
  done
}

main "$@"
