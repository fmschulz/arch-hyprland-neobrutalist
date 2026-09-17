#!/usr/bin/env bash
set -euo pipefail

# /proc exposes the initial environment. Give the fake compositor an address
# without depending on a running desktop or contacting its D-Bus service.
if [[ ${AGS_LIFECYCLE_TEST_READY:-} != 1 ]]; then
  exec env AGS_LIFECYCLE_TEST_READY=1 DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null bash "$0" "$@"
fi

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$REPO/configs/scripts/ags-shell.sh"
export AGS_MOCK_ROOT TEST_COMPOSITOR_PID=$$ HYPRLAND_INSTANCE_SIGNATURE=mock-session
AGS_MOCK_ROOT=$(mktemp -d /tmp/controlcenter-ags-lifecycle.XXXXXX)
export AGS_RUNTIME_ENV="$AGS_MOCK_ROOT/env.sh"
export XDG_RUNTIME_DIR="$AGS_MOCK_ROOT/runtime"
mkdir -p "$AGS_MOCK_ROOT/bin" "$XDG_RUNTIME_DIR"
printf "export PATH=\"%s/bin:\$PATH\"\n" "$AGS_MOCK_ROOT" >"$AGS_RUNTIME_ENV"

cat >"$AGS_MOCK_ROOT/bin/mock-tool" <<'MOCK'
#!/usr/bin/env bash
set -eu
case "${0##*/}" in
  hyprctl)
    if [[ -f "$AGS_MOCK_ROOT/hypr-failures" ]]; then
      remaining=$(<"$AGS_MOCK_ROOT/hypr-failures")
      if ((remaining > 0)); then
        printf '%s\n' "$((remaining - 1))" >"$AGS_MOCK_ROOT/hypr-failures"
        exit 8
      fi
    fi
    printf '[{"instance":"mock-session","pid":%s}]\n' "$TEST_COMPOSITOR_PID"
    ;;
  ags)
    case "$1" in
      run)
        mode=$(<"$AGS_MOCK_ROOT/mode")
        [[ "$mode" != fail ]] || exit 4
        trap 'rm -f "$AGS_MOCK_ROOT/app-ready"; exit 0' TERM INT EXIT
        sleep 0.15
        : >"$AGS_MOCK_ROOT/app-ready"
        if [[ "$mode" == crash ]]; then sleep 0.8; exit 7; fi
        while true; do sleep 0.1; done
        ;;
      request)
        [[ -f "$AGS_MOCK_ROOT/app-ready" ]] || exit 1
        [[ "${4:-}" != ping ]] || printf 'ready\n'
        ;;
    esac
    ;;
  systemctl)
    case "$2" in
      is-active) [[ $(<"$AGS_MOCK_ROOT/bar") == active ]] ;;
      show)
        [[ $(<"$AGS_MOCK_ROOT/mode") != fallback-fail ]] || exit 57
        printf '424242\n'
        ;;
      stop)
        [[ -f "$AGS_MOCK_ROOT/app-ready" ]] || exit 55
        printf 'stop\n' >>"$AGS_MOCK_ROOT/actions"
        printf 'inactive\n' >"$AGS_MOCK_ROOT/bar"
        ;;
      start)
        printf 'start\n' >>"$AGS_MOCK_ROOT/actions"
        [[ $(<"$AGS_MOCK_ROOT/mode") != fallback-fail ]] || exit 56
        printf 'active\n' >"$AGS_MOCK_ROOT/bar"
        ;;
      *) exit 90 ;;
    esac
    ;;
  pgrep)
    if [[ $(<"$AGS_MOCK_ROOT/mode") == unmanaged ]]; then
      printf '987654\n'
    elif [[ $(<"$AGS_MOCK_ROOT/bar") == active ]]; then
      printf '424242\n'
    fi
    ;;
  pkill|waybar)
    printf 'unexpected-%s\n' "${0##*/}" >>"$AGS_MOCK_ROOT/actions"
    exit 99
    ;;
esac
MOCK
chmod +x "$AGS_MOCK_ROOT/bin/mock-tool"
for tool in hyprctl ags systemctl pgrep pkill waybar; do
  ln -s mock-tool "$AGS_MOCK_ROOT/bin/$tool"
done

cleanup() {
  local result=$?
  "$script" stop >/dev/null 2>&1 || true
  if ((result != 0)) && [[ -f "$XDG_RUNTIME_DIR/controlcenter-ags.log" ]]; then
    tail -30 "$XDG_RUNTIME_DIR/controlcenter-ags.log" >&2
  fi
  rm -rf -- "$AGS_MOCK_ROOT"
  exit "$result"
}
trap cleanup EXIT

for initial in active inactive; do
  printf 'normal\n' >"$AGS_MOCK_ROOT/mode"
  printf '%s\n' "$initial" >"$AGS_MOCK_ROOT/bar"
  : >"$AGS_MOCK_ROOT/actions"
  "$script" start
  [[ $("$script" status) == running ]]
  [[ $(<"$AGS_MOCK_ROOT/bar") == inactive ]]
  before=$(<"$AGS_MOCK_ROOT/actions")
  PATH="$AGS_MOCK_ROOT/bin:$PATH" bash "$REPO/configs/scripts/waybar-restart.sh"
  [[ $(<"$AGS_MOCK_ROOT/actions") == "$before" ]]
  "$script" toggle appearance
  "$script" stop
  [[ $(<"$AGS_MOCK_ROOT/bar") == "$initial" ]]
  [[ $("$script" status) == stopped ]]
  flock -n "$XDG_RUNTIME_DIR/controlcenter-ags.lock" true
  if [[ "$initial" == active ]]; then
    [[ $(<"$AGS_MOCK_ROOT/actions") == $'stop\nstart' ]]
  else
    [[ ! -s "$AGS_MOCK_ROOT/actions" ]]
  fi
  printf 'PASS normal stop restores %s Waybar; restart lock holds and releases\n' "$initial"
done

printf 'normal\n' >"$AGS_MOCK_ROOT/mode"
printf 'inactive\n' >"$AGS_MOCK_ROOT/bar"
: >"$AGS_MOCK_ROOT/actions"
PATH="$AGS_MOCK_ROOT/bin:$PATH" "$script" login
[[ $(<"$AGS_MOCK_ROOT/bar") == inactive ]]
[[ $(<"$AGS_MOCK_ROOT/actions") == $'start\nstop' ]]
"$script" stop
[[ $(<"$AGS_MOCK_ROOT/bar") == active ]]
[[ $(<"$AGS_MOCK_ROOT/actions") == $'start\nstop\nstart' ]]
printf 'PASS login keeps Waybar until AGS is ready and restores it on stop\n'

printf 'normal\n' >"$AGS_MOCK_ROOT/mode"
printf 'inactive\n' >"$AGS_MOCK_ROOT/bar"
: >"$AGS_MOCK_ROOT/actions"
if PATH="$AGS_MOCK_ROOT/bin:$PATH" AGS_RUNTIME_ENV="$AGS_MOCK_ROOT/missing-env.sh" "$script" login 2>/dev/null; then
  printf 'Unexpected successful login without the AGS runtime\n' >&2
  exit 1
fi
[[ $(<"$AGS_MOCK_ROOT/bar") == active ]]
[[ $(<"$AGS_MOCK_ROOT/actions") == start ]]
printf 'PASS login leaves fallback Waybar running when the AGS runtime is missing\n'

printf 'fallback-fail\n' >"$AGS_MOCK_ROOT/mode"
printf 'inactive\n' >"$AGS_MOCK_ROOT/bar"
: >"$AGS_MOCK_ROOT/actions"
PATH="$AGS_MOCK_ROOT/bin:$PATH" "$script" login
[[ $(<"$AGS_MOCK_ROOT/bar") == inactive ]]
[[ $(<"$AGS_MOCK_ROOT/actions") == start ]]
"$script" stop
printf 'PASS failed fallback service calls do not block AGS\n'

printf 'normal\n' >"$AGS_MOCK_ROOT/mode"
printf 'inactive\n' >"$AGS_MOCK_ROOT/bar"
printf '3\n' >"$AGS_MOCK_ROOT/hypr-failures"
: >"$AGS_MOCK_ROOT/actions"
PATH="$AGS_MOCK_ROOT/bin:$PATH" "$script" login
[[ $(<"$AGS_MOCK_ROOT/hypr-failures") == 0 ]]
[[ $(<"$AGS_MOCK_ROOT/bar") == inactive ]]
[[ $(<"$AGS_MOCK_ROOT/actions") == $'start\nstop' ]]
"$script" stop
[[ $(<"$AGS_MOCK_ROOT/bar") == active ]]
rm "$AGS_MOCK_ROOT/hypr-failures"
printf 'PASS login waits for Hyprland discovery while Waybar remains available\n'

printf 'normal\n' >"$AGS_MOCK_ROOT/mode"
printf 'inactive\n' >"$AGS_MOCK_ROOT/bar"
printf '999\n' >"$AGS_MOCK_ROOT/hypr-failures"
: >"$AGS_MOCK_ROOT/actions"
: >"$XDG_RUNTIME_DIR/controlcenter-ags.log"
if PATH="$AGS_MOCK_ROOT/bin:$PATH" "$script" login; then
  printf 'Unexpected successful login without Hyprland discovery\n' >&2
  exit 1
fi
[[ $(<"$AGS_MOCK_ROOT/bar") == active ]]
[[ $(<"$AGS_MOCK_ROOT/actions") == start ]]
[[ ! -f "$XDG_RUNTIME_DIR/controlcenter-ags.pid" ]]
grep -q 'Cannot identify the current Hyprland session' "$XDG_RUNTIME_DIR/controlcenter-ags.log"
rm "$AGS_MOCK_ROOT/hypr-failures"
printf 'PASS login logs permanent Hyprland discovery failure without starting AGS\n'

printf 'crash\n' >"$AGS_MOCK_ROOT/mode"
printf 'inactive\n' >"$AGS_MOCK_ROOT/bar"
: >"$AGS_MOCK_ROOT/actions"
PATH="$AGS_MOCK_ROOT/bin:$PATH" "$script" login
sleep 1
[[ $(<"$AGS_MOCK_ROOT/bar") == active ]]
[[ $("$script" status) == stopped ]]
[[ $(<"$AGS_MOCK_ROOT/actions") == $'start\nstop\nstart' ]]
printf 'PASS app crash restores login fallback Waybar\n'

for mode in fail unmanaged; do
  printf '%s\n' "$mode" >"$AGS_MOCK_ROOT/mode"
  printf 'active\n' >"$AGS_MOCK_ROOT/bar"
  : >"$AGS_MOCK_ROOT/actions"
  if "$script" start 2>/dev/null; then
    printf 'Unexpected successful start for %s\n' "$mode" >&2
    exit 1
  fi
  [[ $(<"$AGS_MOCK_ROOT/bar") == active ]]
  [[ ! -s "$AGS_MOCK_ROOT/actions" ]]
  printf 'PASS %s leaves Waybar untouched\n' "$mode"
done
