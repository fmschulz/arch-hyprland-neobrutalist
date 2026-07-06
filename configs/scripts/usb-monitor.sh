#!/usr/bin/env bash
# USB device monitor for waybar
# Shows connected USB storage devices

set -euo pipefail

get_usb_devices() {
	# Get USB block devices (excludes system drives)
	lsblk -o NAME,TRAN,SIZE,MOUNTPOINT -J 2>/dev/null | jq -r '
        .blockdevices[] |
        select(.tran == "usb") |
        "\(.name) \(.size) \(.mountpoint // "not mounted")"
    ' 2>/dev/null
}

usb_info=$(get_usb_devices)
usb_count=$(printf '%s\n' "$usb_info" | sed '/^$/d' | wc -l)

if [ "$usb_count" -gt 0 ] && [ -n "$usb_info" ]; then
	# Build tooltip with device info (real newlines: jq --arg would escape
	# a literal backslash-n and the tooltip would render "\n" as text)
	tooltip="USB Devices:"$'\n'
	while IFS= read -r line; do
		[ -n "$line" ] && tooltip+="• $line"$'\n'
	done <<<"$usb_info"
	tooltip+=$'\n'"Click to open file manager"

	text="󰕓 ${usb_count}"
	class="connected"
else
	text=""
	tooltip=""
	class="disconnected"
fi

jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
	'{text: $text, tooltip: $tooltip, class: $class}'
