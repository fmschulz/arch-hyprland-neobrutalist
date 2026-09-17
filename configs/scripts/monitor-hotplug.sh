#!/usr/bin/env bash
set -euo pipefail

# Re-apply wallpaper when monitors are added/removed.
# Event-driven via Hyprland's socket2 when `socat` is available; otherwise polls.

command -v hyprctl >/dev/null 2>&1 || exit 0
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || exit 0

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
lockfile="${runtime_dir}/monitor-hotplug.lock"
exec 9>"$lockfile"
if ! flock -n 9; then
  exit 0
fi

wallpaper_script="$HOME/.config/scripts/wallpaper-cycle.sh"

apply_wallpaper() {
  if [ -x "$wallpaper_script" ]; then
    "$wallpaper_script" apply || true
  fi
}

socket2="${runtime_dir}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

if command -v socat >/dev/null 2>&1; then
  # Event-driven: react only to monitor add/remove events. Reconnect if the
  # socket drops (e.g. Hyprland restart).
  while true; do
    if [ -S "$socket2" ]; then
      # `|| true`: socat (and the while loop at EOF) exit non-zero on a normal
      # disconnect; without this, `set -euo pipefail` would abort the whole
      # script on the first Hyprland reload and stop re-applying wallpaper.
      socat -U - "UNIX-CONNECT:${socket2}" 2>/dev/null | while IFS= read -r line; do
        case "$line" in
          # Match one event version only; each hotplug also emits a v2 event.
          monitoradded\>\>*|monitorremoved\>\>*) apply_wallpaper ;;
        esac
      done || true
    fi
    sleep 2
  done
else
  # Fallback: poll the monitor list.
  get_monitors() { hyprctl monitors | awk '/Monitor/{print $2}' | sort | tr '\n' ' '; }
  prev="$(get_monitors)"
  while true; do
    sleep 2
    current="$(get_monitors)"
    if [ "$current" != "$prev" ]; then
      prev="$current"
      apply_wallpaper
    fi
  done
fi
