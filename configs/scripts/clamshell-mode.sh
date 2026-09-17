#!/bin/bash
# Hyprland lid / clamshell handler.
#
# Modes:
#   closed   one-shot: lid closed  (called from `bindl = , switch:on:Lid Switch`)
#   open     one-shot: lid opened  (called from `bindl = , switch:off:Lid Switch`)
#   init     one-shot: apply current lid state once at startup (exec-once)
#   sync     one-shot: re-apply lid state after a config reload (no lock,
#            no state-file rewrite). A reload can re-enable the panel while
#            the lid is still closed, with no switch event to correct it.
#   daemon   polling fallback loop (default if no/unknown arg)
#
# When docked (an external monitor is present) and the lid closes, internal
# workspaces are moved to the external display, the internal panel is disabled,
# and the session is locked. Workspace placement is persisted so `open` can restore it
# even though each invocation is a separate process.

set -euo pipefail

INTERNAL_OUTPUT="${INTERNAL_OUTPUT:-}"
INTERNAL_MODE="${INTERNAL_MODE:-}"
LID_STATE_PATH="${LID_STATE_PATH:-/proc/acpi/button/lid/LID0/state}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"
STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/clamshell-moved-workspaces"
LOG_PREFIX="[clamshell]"

log() { echo "${LOG_PREFIX} $*"; }

require_tools() {
  command -v hyprctl >/dev/null 2>&1 || { log "hyprctl not found; exiting"; exit 0; }
  command -v jq >/dev/null 2>&1 || { log "jq not found; exiting"; exit 0; }
}

find_internal_output() {
  [[ -n "${INTERNAL_OUTPUT}" ]] || INTERNAL_OUTPUT=$(hyprctl -j monitors all | jq -r \
    '[.[] | select(.name | test("^(eDP|LVDS)-"))][0].name // empty')
  [[ -n "${INTERNAL_OUTPUT}" ]] || { log "No internal display found; exiting"; exit 0; }
}

current_lid_state() {
  if [[ -r "${LID_STATE_PATH}" ]]; then
    awk '{print $2}' "${LID_STATE_PATH}"
  else
    echo "open"
  fi
}

on_ac() {
  local supply
  for supply in /sys/class/power_supply/*; do
    [[ -r "$supply/online" && "$(cat "$supply/online")" == 1 ]] || continue
    [[ "$(cat "$supply/type" 2>/dev/null)" != Battery ]] && return 0
  done
  return 1
}

pick_target_monitor() {
  hyprctl -j monitors | jq -r --arg internal "${INTERNAL_OUTPUT}" '
    map(select(.name != $internal and (.disabled == false))) as $exts |
    if ($exts | length) == 0 then "" else
      (if ($exts | map(select(.focused == true)) | length) > 0 then
         ($exts | map(select(.focused == true)) | .[0].name)
       else
         $exts[0].name
       end)
    end
  '
}

fetch_internal_workspaces() {
  hyprctl -j workspaces | jq -r --arg internal "${INTERNAL_OUTPUT}" '.[] | select(.monitor == $internal) | .id'
}

apply_lid_closed() {
  # CLAMSHELL_SYNC=1: reload re-sync — keep the lid-close STATE_FILE (so a
  # later `open` still restores the original set) and skip the session lock.
  local target ws sync="${CLAMSHELL_SYNC:-0}"
  target=$(pick_target_monitor)

  if [[ -z "${target}" ]]; then
    [[ "${sync}" == "1" ]] || : >"${STATE_FILE}" 2>/dev/null || true
    if on_ac; then
      # On AC logind ignores the lid (setup/configure-clamshell-awake.sh) so
      # SSH sessions survive a closed lid at the desk: lock and blank the
      # panel ourselves. On battery logind suspends (before_sleep_cmd locks).
      hyprctl dispatch dpms off >/dev/null 2>&1 || true
      log "Lid closed (undocked, on AC) -> session locked, panel off, no suspend"
    else
      log "Lid closed, no external monitor, on battery -> handled by logind suspend"
    fi
    return 0
  fi

  # Docked clamshell.
  [[ "${sync}" == "1" ]] || : >"${STATE_FILE}" 2>/dev/null || true
  while IFS= read -r ws; do
    [[ -n "${ws}" ]] || continue
    [[ "${sync}" == "1" ]] || echo "${ws}" >>"${STATE_FILE}" 2>/dev/null || true
    hyprctl dispatch moveworkspacetomonitor "${ws}" "${target}" >/dev/null 2>&1 || true
  done < <(fetch_internal_workspaces)

  hyprctl keyword monitor "${INTERNAL_OUTPUT}",disable >/dev/null 2>&1 || true
  hyprctl dispatch focusmonitor "${target}" >/dev/null 2>&1 || true
  if [[ "${sync}" == "1" ]]; then
    log "Reload sync (lid closed, docked) -> external ${target}; internal panel re-disabled"
  else
    log "Lid closed (docked) -> external ${target}; internal panel disabled; session locked"
  fi
}

apply_lid_opened() {
  local ws
  log "Lid opened -> restoring internal display"
  if [[ -n "${INTERNAL_MODE}" ]]; then
    hyprctl keyword monitor "${INTERNAL_OUTPUT}","${INTERNAL_MODE}" >/dev/null 2>&1 || true
  else
    hyprctl reload >/dev/null 2>&1 || true
  fi
  hyprctl dispatch dpms on >/dev/null 2>&1 || true  # undocked-on-AC close blanked it
  sleep 1
  if [[ -r "${STATE_FILE}" ]]; then
    while IFS= read -r ws; do
      [[ -n "${ws}" ]] || continue
      hyprctl dispatch moveworkspacetomonitor "${ws}" "${INTERNAL_OUTPUT}" >/dev/null 2>&1 || true
    done <"${STATE_FILE}"
    : >"${STATE_FILE}" 2>/dev/null || true
  fi
}

with_display_lock() {
  local action=$1 profile_dir profile_script
  profile_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/controlcenter-display-${HYPRLAND_INSTANCE_SIGNATURE:-none}"
  profile_script="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/display-profile.sh"
  mkdir -p "$profile_dir"
  # End a preview before lid changes, then hold its transaction lock while applying
  # the lid policy. The preview guard restores first and cannot undo our lid state.
  if [[ -x "$profile_script" ]]; then "$profile_script" revert || true; fi
  (
    flock -w 5 8 || { log "Display preview did not release its lock"; exit 1; }
    "$action"
  ) 8>"$profile_dir/lock"
}

handle_lid_closed() {
  # Lock before waiting for a display transaction, including a failed guard.
  [[ "${CLAMSHELL_SYNC:-0}" == "1" ]] || loginctl lock-session >/dev/null 2>&1 || true
  with_display_lock apply_lid_closed
}
handle_lid_opened() { with_display_lock apply_lid_opened; }

run_daemon() {
  if [[ ! -r "${LID_STATE_PATH}" ]]; then
    log "Lid state path ${LID_STATE_PATH} not readable; exiting"
    exit 0
  fi

  local last_state state
  last_state=$(current_lid_state)
  log "Daemon fallback; initial lid state: ${last_state}"
  [[ "${last_state}" == "closed" ]] && handle_lid_closed

  while true; do
    sleep "${POLL_INTERVAL}"
    state=$(current_lid_state)
    if [[ "${state}" != "${last_state}" ]]; then
      if [[ "${state}" == "closed" ]]; then
        handle_lid_closed
      else
        handle_lid_opened
      fi
      last_state="${state}"
    fi
  done
}

main() {
  require_tools
  find_internal_output
  case "${1:-daemon}" in
    closed) handle_lid_closed ;;
    open)   handle_lid_opened ;;
    init)
      if [[ "$(current_lid_state)" == "closed" ]]; then
        handle_lid_closed
      fi
      ;;
    sync)
      if [[ "$(current_lid_state)" == "closed" ]]; then
        CLAMSHELL_SYNC=1 handle_lid_closed
      fi
      ;;
    daemon|"") run_daemon ;;
    *) log "Unknown mode: ${1}"; exit 2 ;;
  esac
}

main "$@"
