#!/usr/bin/env bash
# Exit 0 when docked (an external monitor is attached), non-zero otherwise.
# "External" = any enabled Hyprland monitor whose name differs from the internal
# panel (override with INTERNAL_OUTPUT). The idle guards use this
# so a trusted desk setup neither auto-locks nor blanks its screens on idle.
internal="${INTERNAL_OUTPUT:-}"
if [[ -z "$internal" ]]; then
  internal=$(hyprctl -j monitors all 2>/dev/null | jq -r \
    '[.[] | select(.name | test("^(eDP|LVDS)-"))][0].name // empty')
fi

command -v hyprctl >/dev/null 2>&1 || exit 1
command -v jq >/dev/null 2>&1 || exit 1

# jq -e sets the exit status from the boolean result: 0 when an external monitor
# is present, 1 when not. That status is the script's status.
hyprctl -j monitors 2>/dev/null |
  jq -e --arg i "$internal" \
    'map(select(.name != $i and .disabled == false)) | length > 0' >/dev/null
