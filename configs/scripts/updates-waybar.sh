#!/usr/bin/env bash
# Compact package update indicator for Waybar.

set -euo pipefail

update_output=""
check_status=127
if command -v checkupdates >/dev/null 2>&1; then
	if update_output=$(checkupdates 2>/dev/null); then
		check_status=0
	else
		check_status=$?
	fi
fi

if ((check_status == 0)); then
	updates=$(awk 'NF { updates++ } END { print updates + 0 }' <<<"${update_output}")
	if ((updates > 0)); then
		text="󰏗 ${updates}"
		tooltip="${updates} package updates available"
		class="pending"
	else
		text=""
		tooltip="System up to date"
		class="none"
	fi
elif ((check_status == 2)); then
	text=""
	tooltip="System up to date"
	class="none"
else
	text="󰏗 ?"
	tooltip="Package update check failed"
	class="error"
fi

jq -nc --arg text "${text}" --arg tooltip "${tooltip}" --arg class "${class}" \
	'{text: $text, tooltip: $tooltip, class: $class}'
