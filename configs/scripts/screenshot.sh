#!/bin/bash
# Screenshot helper wrapping grimblast for Hyprland binds

set -euo pipefail

SCREENSHOT_DIR="${SCREENSHOT_DIR:-${HOME}/Documents/screenshots}"

usage() {
	echo "Usage: $0 {copy-area|copy-output|save-area|save-output}" >&2
	exit 1
}

notify() {
	notify-send "$1" "$2" 2>/dev/null || true
}

save_path() {
	mkdir -p "${SCREENSHOT_DIR}"
	echo "${SCREENSHOT_DIR}/$(date +%Y-%m-%d_%H-%M-%S).png"
}

case "${1:-}" in
copy-area)
	grimblast -f copy area
	notify "Screenshot copied" "Area copied to clipboard"
	;;
copy-output)
	grimblast copy output
	notify "Screenshot copied" "Output copied to clipboard"
	;;
save-area)
	path=$(save_path)
	grimblast -f save area "${path}"
	if wl-copy --type image/png <"${path}"; then
		notify "Screenshot saved and copied" "${path}"
	else
		notify "Screenshot saved" "Clipboard copy failed: ${path}"
		exit 1
	fi
	;;
save-output)
	path=$(save_path)
	grimblast save output "${path}"
	notify "Screenshot saved" "${path}"
	;;
*)
	usage
	;;
esac
