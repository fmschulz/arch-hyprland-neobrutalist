#!/usr/bin/env bash
# Idle-suspend guard for hypridle: suspend on idle only when on battery.
# Plugged in (desk) the laptop stays up, because suspend tears down wifi and
# kills every SSH session to the cluster with it.
#
# hypridle fires on-timeout once per idle period, so while on AC we keep
# re-checking: unplug while still idle -> suspend then. hypridle's on-resume
# kills this loop when the user comes back.
set -euo pipefail

POWER_SUPPLY_DIR="${POWER_SUPPLY_DIR:-/sys/class/power_supply}"

has_system_battery() {
  local supply
  for supply in "${POWER_SUPPLY_DIR}"/*; do
    [[ "$(cat "$supply/type" 2>/dev/null)" == Battery ]] || continue
    [[ "$(cat "$supply/scope" 2>/dev/null)" == Device ]] || return 0
  done
  return 1
}

on_ac() {
  local supply
  for supply in "${POWER_SUPPLY_DIR}"/*; do
    [[ -r "$supply/online" && "$(cat "$supply/online")" == 1 ]] || continue
    [[ "$(cat "$supply/type" 2>/dev/null)" != Battery ]] && return 0
  done
  return 1
}

has_system_battery || exit 0

hypridle_pid=$(pgrep -o -x hypridle || true)

while on_ac; do
  # hypridle gone (restart/crash): its on-resume can no longer stop us, bail
  # rather than suspend an active user later.
  [[ -n "${hypridle_pid}" && -d "/proc/${hypridle_pid}" ]] || exit 0
  sleep 60
done

systemctl suspend
