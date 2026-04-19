#!/bin/bash
# Hyprland lid watcher to support clamshell mode on docking stations

set -euo pipefail

INTERNAL_OUTPUT="${INTERNAL_OUTPUT:-eDP-1}"
INTERNAL_MODE="${INTERNAL_MODE:-2880x1920@120,0x0,1.5}"
LID_STATE_PATH="${LID_STATE_PATH:-/proc/acpi/button/lid/LID0/state}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"
MONITOR_SETTLE_DELAY="${MONITOR_SETTLE_DELAY:-0.5}"
LOG_PREFIX="[clamshell]"

declare -a MOVED_WORKSPACES=()

log() {
	echo "${LOG_PREFIX} $*"
}

require_tools() {
	command -v hyprctl >/dev/null 2>&1 || {
		log "hyprctl not found; exiting"
		exit 0
	}
	command -v jq >/dev/null 2>&1 || {
		log "jq not found; exiting"
		exit 0
	}
}

wait_for_hypr() {
	local retries=0
	while ! hyprctl -j monitors >/dev/null 2>&1; do
		sleep 1
		retries=$((retries + 1))
		if ((retries >= 30)); then
			log "Hyprland IPC unavailable; exiting"
			exit 0
		fi
	done
}

current_lid_state() {
	if [[ -r "${LID_STATE_PATH}" ]]; then
		awk '{print $2}' "${LID_STATE_PATH}"
	else
		echo "open"
	fi
}

pick_target_monitor() {
	hyprctl -j monitors | jq -r --arg internal "${INTERNAL_OUTPUT}" '
    map(select(.name != $internal and (.disabled == false))) as $exts |
    if ($exts | length) == 0 then "" else
      (if ($exts | map(select(.focused == true)) | length) > 0 then
         ($exts | map(select(.focused == true)) | .[0].name)
       else
         $exts[0].name
       end)
    end
  '
}

fetch_internal_workspaces() {
	hyprctl -j workspaces | jq -r --arg internal "${INTERNAL_OUTPUT}" '.[] | select(.monitor == $internal) | .id'
}

internal_output_enabled() {
	local disabled
	disabled=$(
		hyprctl -j monitors all | jq -r --arg internal "${INTERNAL_OUTPUT}" '
      map(select(.name == $internal)) | .[0].disabled // false
    '
	)
	[[ "${disabled}" == "false" ]]
}

restore_internal_workspaces() {
	local ws
	for ws in "${MOVED_WORKSPACES[@]}"; do
		hyprctl dispatch moveworkspacetomonitor "${ws}" "${INTERNAL_OUTPUT}" >/dev/null 2>&1 || true
	done
	MOVED_WORKSPACES=()
}

reapply_wallpaper() {
	local wallpaper_script="${HOME}/.config/scripts/wallpaper-cycle.sh"
	if [[ -x "${wallpaper_script}" ]]; then
		"${wallpaper_script}" apply >/dev/null 2>&1 || true
	fi
}

handle_lid_closed() {
	local target
	readarray -t MOVED_WORKSPACES < <(fetch_internal_workspaces)
	target=$(pick_target_monitor)
	if [[ -z "${target}" ]]; then
		log "No external monitor detected; skipping clamshell actions"
		MOVED_WORKSPACES=()
		return
	fi

	log "Lid closed -> moving ${#MOVED_WORKSPACES[@]} workspaces to ${target}"
	local ws
	for ws in "${MOVED_WORKSPACES[@]}"; do
		hyprctl dispatch moveworkspacetomonitor "${ws}" "${target}" >/dev/null 2>&1 || true
	done

	hyprctl keyword monitor "${INTERNAL_OUTPUT}",disable >/dev/null 2>&1 || true
	hyprctl dispatch focusmonitor "${target}" >/dev/null 2>&1 || true
	sleep "${MONITOR_SETTLE_DELAY}"
	reapply_wallpaper

	# Restart waybar to fix duplication issues on dock
	pkill -x waybar || true
	waybar &
}

handle_lid_opened() {
	log "Lid opened -> restoring internal display"
	hyprctl keyword monitor "${INTERNAL_OUTPUT}","${INTERNAL_MODE}" >/dev/null 2>&1 || true
	sleep 1
	restore_internal_workspaces
	reapply_wallpaper

	# Restart waybar to fix layout
	pkill -x waybar || true
	waybar &
}

main() {
	require_tools

	if [[ ! -r "${LID_STATE_PATH}" ]]; then
		log "Lid state path ${LID_STATE_PATH} not readable; exiting"
		exit 0
	fi

	wait_for_hypr

	local last_state
	last_state=$(current_lid_state)
	log "Initial lid state: ${last_state}"

	if [[ "${last_state}" == "closed" ]]; then
		handle_lid_closed
	fi

	while true; do
		sleep "${POLL_INTERVAL}"
		local state
		state=$(current_lid_state)
		if [[ "${state}" != "${last_state}" ]]; then
			if [[ "${state}" == "closed" ]]; then
				handle_lid_closed
			else
				handle_lid_opened
			fi
			last_state="${state}"
			continue
		fi

		if [[ "${state}" == "closed" ]] && internal_output_enabled; then
			log "Lid still closed but ${INTERNAL_OUTPUT} is enabled; re-applying clamshell mode"
			handle_lid_closed
		elif [[ "${state}" != "closed" ]] && ! internal_output_enabled; then
			log "Lid open but ${INTERNAL_OUTPUT} is disabled; restoring internal display"
			handle_lid_opened
		fi
	done
}

main
