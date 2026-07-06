#!/bin/bash
# Area screen-recording toggle wrapping wf-recorder for Hyprland binds:
# first press selects a region (slurp) and starts recording, second press
# stops it and finalizes the file under ~/Documents/screenrecordings.

set -euo pipefail

RECORDING_DIR="${RECORDING_DIR:-${HOME}/Documents/screenrecordings}"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/screenrecord-current"

notify() {
	notify-send "$1" "$2" 2>/dev/null || true
}

if pgrep -x wf-recorder >/dev/null 2>&1; then
	# SIGINT lets wf-recorder finalize the container before exiting
	pkill -INT -x wf-recorder
	for _ in $(seq 1 50); do
		pgrep -x wf-recorder >/dev/null 2>&1 || break
		sleep 0.1
	done
	path=$(cat "${STATE_FILE}" 2>/dev/null || true)
	rm -f "${STATE_FILE}"
	if [ -n "${path}" ] && [ -s "${path}" ]; then
		notify "Recording saved" "${path}"
	else
		notify "Recording stopped" "${path:-no output file found}"
	fi
else
	# SCREENRECORD_GEOMETRY ("X,Y WxH") bypasses slurp for scripted runs
	geometry="${SCREENRECORD_GEOMETRY:-$(slurp)}" || exit 0
	[ -n "${geometry}" ] || exit 0
	mkdir -p "${RECORDING_DIR}"
	path="${RECORDING_DIR}/$(date +%Y-%m-%d_%H-%M-%S).mp4"
	echo "${path}" >"${STATE_FILE}"
	wf-recorder -g "${geometry}" -f "${path}" >/dev/null 2>"${XDG_RUNTIME_DIR:-/tmp}/screenrecord.log" &
	notify "Recording started" "${path} — press again to stop"
fi
