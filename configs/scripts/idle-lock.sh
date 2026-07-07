#!/usr/bin/env bash
# Idle-lock guard for hypridle: lock the session unless docked (an external
# monitor is attached = trusted desk; skip the auto-lock there).
# Docked detection lives in the shared is-docked.sh helper.
set -euo pipefail

guard="$(dirname "$(readlink -f "$0")")/is-docked.sh"

# Invoke via bash so a lost execute bit can't silently drop the docked check.
if [[ -r "$guard" ]] && bash "$guard"; then
  exit 0 # docked: skip the idle lock
fi

# Playing media means a watching-not-typing user, not an absent one. Windowed
# players don't trigger the fullscreen idle_inhibit rule, so check here too.
if command -v playerctl >/dev/null 2>&1 && playerctl -a status 2>/dev/null | grep '^Playing' >/dev/null; then
  exit 0 # media playing: skip the idle lock
fi

loginctl lock-session
