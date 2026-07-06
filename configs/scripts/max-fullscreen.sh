#!/usr/bin/env bash
set -euo pipefail

BAR_HEIGHT="${WAYBAR_HEIGHT:-36}"
BELOW_BAR="${MAXIMIZE_BELOW_BAR:-0}"

aw_json=$(hyprctl activewindow -j || echo '{}')
addr=$(echo "$aw_json" | jq -r '.address // empty')
[[ -z "$addr" ]] && exit 0

# .floating is a JSON boolean; jq's // would swallow `false`, so read it raw
floating=$(echo "$aw_json" | jq -r '.floating')
wx=$(echo "$aw_json" | jq -r '.at[0] // 0')
wy=$(echo "$aw_json" | jq -r '.at[1] // 0')
ww=$(echo "$aw_json" | jq -r '.size[0] // 0')
wh=$(echo "$aw_json" | jq -r '.size[1] // 0')

mon=$(hyprctl monitors -j | jq -r 'map(select(.focused==true))[0]')
mx=$(echo "$mon" | jq -r '.x // 0')
my=$(echo "$mon" | jq -r '.y // 0')
mw=$(echo "$mon" | jq -r '.width // 0')
mh=$(echo "$mon" | jq -r '.height // 0')

if [[ "$floating" == "true" ]]; then
  dx=$((wx - mx))
  dy=$((wy - my))
  dw=$((mw - ww))
  dh=$((mh - wh))
  abs() { echo $(($1 < 0 ? -$1 : $1)); }
  if (($(abs "$dx") <= 12 && $(abs "$dy") <= 48 && $(abs "$dw") <= 24 && $(abs "$dh") <= 60)); then
    hyprctl dispatch togglefloating
    exit 0
  fi
fi

[[ "$floating" != "true" ]] && hyprctl dispatch togglefloating

ty="$my"
th="$mh"
if [[ "$BELOW_BAR" == "1" ]]; then
  ty=$((my + BAR_HEIGHT))
  th=$((mh - BAR_HEIGHT))
fi

hyprctl dispatch movewindowpixel exact "$mx" "$ty"
hyprctl dispatch resizeactive exact "$mw" "$th"
