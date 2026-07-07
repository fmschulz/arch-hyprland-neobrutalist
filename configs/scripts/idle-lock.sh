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

loginctl lock-session
