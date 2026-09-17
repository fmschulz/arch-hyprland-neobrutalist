#!/usr/bin/env bash
set -euo pipefail
umask 077

SELF=$(realpath "${BASH_SOURCE[0]}")
export AGS_ROOT
AGS_ROOT=$(dirname "$(dirname "$SELF")")
RUNTIME=${XDG_RUNTIME_DIR:?Run this command inside the desktop session}
LOCK="$RUNTIME/controlcenter-ags.lock"
PID_FILE="$RUNTIME/controlcenter-ags.pid"
READY_FILE="$RUNTIME/controlcenter-ags.ready"
LOG_FILE="$RUNTIME/controlcenter-ags.log"
login=false

fail() {
  printf 'ags-shell: %s\n' "$*" >&2
  exit 1
}

# Keep Waybar as the login fallback until AGS reports ready. A failed fallback
# must not prevent AGS from starting.
if [[ ${1:-start} == login ]]; then
  login=true
  exec >>"$LOG_FILE" 2>&1
  printf 'ags-shell: login startup\n'
  systemctl --user start waybar.service || true
  set -- start
fi

runtime_env=${AGS_RUNTIME_ENV:-$HOME/.local/share/arch-hypr-neobrutalist/ags/env.sh}
[[ -f "$runtime_env" ]] || fail "AGS runtime is missing: $runtime_env"
# shellcheck disable=SC1090
source "$runtime_env"
command -v ags >/dev/null || fail "The configured runtime does not provide ags"

# Waybar can inherit the systemd bus while Hyprland owns a private session bus.
# Use the compositor's address for both the app and every request to it.
find_compositor_pid() {
  hyprctl -j instances |
    jq -er --arg signature "${HYPRLAND_INSTANCE_SIGNATURE:-}" '.[] | select(.instance == $signature) | .pid'
}

compositor_pid=
if "$login"; then
  deadline=$((SECONDS + 5))
  until compositor_pid=$(find_compositor_pid 2>/dev/null); do
    ((SECONDS < deadline)) || fail "Cannot identify the current Hyprland session"
    sleep 0.1
  done
else
  compositor_pid=$(find_compositor_pid) || fail "Cannot identify the current Hyprland session"
fi
session_bus=
while IFS= read -r -d '' setting; do
  if [[ "$setting" == DBUS_SESSION_BUS_ADDRESS=* ]]; then
    session_bus=${setting#*=}
    break
  fi
done <"/proc/$compositor_pid/environ"
[[ -n "$session_bus" ]] || fail "The Hyprland session has no D-Bus address"
export DBUS_SESSION_BUS_ADDRESS="$session_bus"

running() {
  ! flock -n "$LOCK" true
}

request() {
  timeout 3s ags request -i controlcenter "$@"
}

cleanup() {
  local result=$1
  trap - EXIT INT TERM
  if [[ -n "$child" ]]; then
    kill -TERM -- "-$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
  fi
  if "$stopped_bar"; then
    systemctl --user start waybar.service || result=1
  fi
  rm -f "$PID_FILE" "$READY_FILE"
  exit "$result"
}

supervise() {
  exec 9>"$LOCK"
  flock -n 9 || fail "The trial is already running"
  rm -f "$READY_FILE"
  printf '%s\n' "$$" >"$PID_FILE"

  local child='' was_active=false stopped_bar=false
  trap 'cleanup "$?"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  if systemctl --user is-active --quiet waybar.service; then
    was_active=true
  fi
  local managed_pid
  managed_pid=$(systemctl --user show waybar.service -p MainPID --value 2>/dev/null || true)
  local bar_pid
  while IFS= read -r bar_pid; do
    [[ "$bar_pid" == "$managed_pid" ]] || fail "An unmanaged Waybar is running; the trial cannot replace it"
  done < <(pgrep -x waybar || true)

  # Close the supervisor lock in children so an app crash cannot leave it held.
  setsid ags run --gtk 4 "$AGS_ROOT/ags/app.tsx" 9>&- &
  child=$!
  local deadline=$((SECONDS + 20))
  while ((SECONDS < deadline)); do
    kill -0 "$child" 2>/dev/null || fail "AGS exited before it was ready; see $LOG_FILE"
    if [[ "$(request ping 2>/dev/null || true)" == ready ]]; then
      if "$was_active"; then
        stopped_bar=true
        systemctl --user stop waybar.service
      fi
      : >"$READY_FILE"
      wait "$child"
      exit 0
    fi
    sleep 0.1
  done
  fail "AGS did not become ready; Waybar was left running. See $LOG_FILE"
}

case "${1:-start}" in
  supervise)
    supervise
    ;;
  start|toggle)
    case "${2:-network}" in
      network|sound|desktop|appearance|notifications|system) ;;
      *) fail "Unknown control center tab: $2" ;;
    esac
    if ! running; then
      rm -f "$READY_FILE"
      setsid "$SELF" supervise </dev/null >>"$LOG_FILE" 2>&1 &
      supervisor=$!
    fi
    deadline=$((SECONDS + 25))
    while [[ ! -f "$READY_FILE" ]] || ! running; do
      if [[ -n "${supervisor:-}" ]] && ! kill -0 "$supervisor" 2>/dev/null; then
        fail "The trial failed to start; see $LOG_FILE"
      fi
      ((SECONDS < deadline)) || fail "The trial is not ready; see $LOG_FILE"
      sleep 0.1
    done
    if [[ "${1:-start}" == toggle || -n "${2:-}" ]]; then
      request toggle "${2:-network}"
    fi
    ;;
  stop)
    if ! running; then
      exit 0
    fi
    [[ -f "$PID_FILE" ]] || fail "The trial is starting; retry stop shortly"
    supervisor=$(<"$PID_FILE")
    [[ "$supervisor" =~ ^[0-9]+$ ]] || fail "Invalid trial supervisor state"
    mapfile -d '' -t command_line <"/proc/$supervisor/cmdline"
    [[ "${command_line[1]:-}" == "$SELF" && "${command_line[2]:-}" == supervise ]] || fail "The trial supervisor does not match its saved state"
    kill -TERM "$supervisor"
    deadline=$((SECONDS + 10))
    while running; do
      ((SECONDS < deadline)) || fail "The trial has not stopped; see $LOG_FILE"
      sleep 0.1
    done
    ;;
  status)
    if running && [[ -f "$READY_FILE" ]]; then
      printf 'running\n'
    elif running; then
      printf 'starting\n'
    else
      printf 'stopped\n'
    fi
    ;;
  *) fail "Usage: $0 [login|start|stop|toggle [network|sound|desktop|appearance|notifications]|status]" ;;
esac
