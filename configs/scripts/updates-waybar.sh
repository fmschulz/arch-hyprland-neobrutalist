#!/usr/bin/env bash
# Compact package update indicator for Waybar.

set -euo pipefail

updates=0
if command -v checkupdates >/dev/null 2>&1; then
	# checkupdates exits 2 when there are no updates (and 1 on error); without
	# the || true, set -e would kill the script before it prints any JSON.
	updates=$(checkupdates 2>/dev/null | wc -l) || true
fi

if ((updates > 0)); then
	text="󰏗 ${updates}"
	tooltip="${updates} package updates available"
	class="pending"
else
	text=""
	tooltip="System up to date"
	class="none"
fi

jq -nc --arg text "${text}" --arg tooltip "${tooltip}" --arg class "${class}" \
	'{text: $text, tooltip: $tooltip, class: $class}'
