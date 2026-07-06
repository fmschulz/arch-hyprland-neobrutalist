#!/usr/bin/env bash
# Idle-lock guard for hypridle: lock the session unless an external monitor
# is attached (docked = trusted desk; skip the auto-lock there).
# INTERNAL_OUTPUT overrides the internal panel name (default eDP-1).
set -euo pipefail

internal="${INTERNAL_OUTPUT:-eDP-1}"

if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  if hyprctl -j monitors 2>/dev/null |
    jq -e --arg i "$internal" 'map(select(.name != $i and (.disabled == false))) | length > 0' >/dev/null; then
    exit 0 # external display active: skip idle lock
  fi
fi

loginctl lock-session
