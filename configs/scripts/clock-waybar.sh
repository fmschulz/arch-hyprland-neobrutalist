#!/usr/bin/env bash
set -euo pipefail

text="$(date '+%a %b %d  %I:%M %p')"
month="$(date '+%B %Y')"
calendar="$(cal -m -w)"
# Real newlines ($'\n'): jq --arg would escape a literal backslash-n and the
# tooltip would render "\n" as text.
tooltip="${month}"$'\n'"${calendar}"$'\n\n'"Click: open calendar window"

jq -cn --arg text "${text}" --arg tooltip "${tooltip}" '{text: $text, tooltip: $tooltip}'
