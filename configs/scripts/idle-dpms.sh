#!/usr/bin/env bash
# Idle-DPMS guard for hypridle: turn the displays off on idle unless docked (an
# external monitor is attached = trusted desk; keep the screens on there).
# Undocked (laptop only) still blanks to save power. Shares is-docked.sh with
# the idle-lock guard. hypridle's on-resume already runs `dpms on`, so a display
# blanked while undocked comes back on the next input.
set -euo pipefail

guard="$(dirname "$(readlink -f "$0")")/is-docked.sh"

# Invoke via bash so a lost execute bit can't silently drop the docked check.
if [[ -r "$guard" ]] && bash "$guard"; then
  exit 0 # docked: keep the displays on
fi

# Playing media means a watching-not-typing user, not an absent one. Windowed
# players don't trigger the fullscreen idle_inhibit rule, so check here too.
if command -v playerctl >/dev/null 2>&1 && playerctl -a status 2>/dev/null | grep '^Playing' >/dev/null; then
  exit 0 # media playing: keep the displays on
fi

hyprctl dispatch dpms off
