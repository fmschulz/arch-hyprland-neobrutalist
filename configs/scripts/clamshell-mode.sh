#!/bin/bash
# Hyprland lid watcher to support clamshell mode on docking stations
# Usage: clamshell-mode.sh [closed|opened|watch] (default: watch)

set -euo pipefail

# Internal panel is resolved by name (eDP-1) by default. Docked laptops whose
# internal output renumbers can instead match by stable EDID description, e.g.
#   INTERNAL_OUTPUT_DESC="BOE NE135A1M-NY1" clamshell-mode.sh
INTERNAL_OUTPUT_DESC="${INTERNAL_OUTPUT_DESC:-}"
INTERNAL_OUTPUT_FALLBACK="${INTERNAL_OUTPUT:-eDP-1}"
INTERNAL_MODE="${INTERNAL_MODE:-preferred,auto,1.0}"
LID_STATE_PATH="${LID_STATE_PATH:-/proc/acpi/button/lid/LID0/state}"
# Lid edges are handled by Hyprland 'bindl = , switch:on/off:Lid Switch' binds
# invoking this script with closed/opened; the watch loop is only a
# low-frequency reconcile backstop.
POLL_INTERVAL="${POLL_INTERVAL:-15}"
MONITOR_SETTLE_DELAY="${MONITOR_SETTLE_DELAY:-0.5}"
# Moved-workspace ids are persisted here so the one-shot 'closed' invocation
# can hand restore state to the one-shot 'opened' (separate processes).
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/clamshell-moved-workspaces"
LOG_PREFIX="[clamshell]"

INTERNAL_OUTPUT=""
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

resolve_internal_output() {
	local output
	output=$(
		hyprctl -j monitors all | jq -r \
			--arg desc "${INTERNAL_OUTPUT_DESC}" \
			--arg fallback "${INTERNAL_OUTPUT_FALLBACK}" '
      (
        (if $desc == "" then empty else map(select(((.description // "") == $desc) or ((.description // "") | startswith($desc)))) | .[0].name end)
      ) // (
        map(select(.name == $fallback)) | .[0].name
      ) // empty
    '
	)

	if [[ -z "${output}" ]]; then
		log "Internal display not found by description '${INTERNAL_OUTPUT_DESC}' or fallback '${INTERNAL_OUTPUT_FALLBACK}'"
		return 1
	fi

	INTERNAL_OUTPUT="${output}"
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
	hyprctl -j workspaces | jq -r --arg internal "${INTERNAL_OUTPUT}" '.[] | select(.monitor == $internal and .id > 0) | .id'
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
	# The in-memory array is primary; fall back to the state file written by a
	# prior one-shot 'closed' invocation.
	if ((${#MOVED_WORKSPACES[@]} == 0)) && [[ -r "${STATE_FILE}" ]]; then
		readarray -t MOVED_WORKSPACES <"${STATE_FILE}"
	fi
	for ws in "${MOVED_WORKSPACES[@]}"; do
		[[ -n "${ws}" ]] || continue
		hyprctl dispatch moveworkspacetomonitor "${ws}" "${INTERNAL_OUTPUT}" >/dev/null 2>&1 || true
	done
	MOVED_WORKSPACES=()
	rm -f "${STATE_FILE}" 2>/dev/null || true
}

set_internal_disabled() {
	local disabled="$1"

	if [[ "${disabled}" == "true" ]]; then
		hyprctl keyword monitor "${INTERNAL_OUTPUT},disable" >/dev/null 2>&1 || true
	else
		hyprctl keyword monitor "${INTERNAL_OUTPUT},${INTERNAL_MODE}" >/dev/null 2>&1 || true
	fi
}

reapply_wallpaper() {
	local wallpaper_script="${HOME}/.config/scripts/wallpaper-cycle.sh"
	if [[ -x "${wallpaper_script}" ]]; then
		"${wallpaper_script}" apply >/dev/null 2>&1 || true
	fi
}

restart_waybar() {
	local helper="${HOME}/.config/scripts/waybar-restart.sh"
	if [[ -x "${helper}" ]]; then
		"${helper}"
	fi
}

handle_lid_closed() {
	local target
	readarray -t MOVED_WORKSPACES < <(fetch_internal_workspaces)
	target=$(pick_target_monitor || true)
	if [[ -z "${target}" ]]; then
		log "No external monitor detected; skipping clamshell actions"
		MOVED_WORKSPACES=()
		rm -f "${STATE_FILE}" 2>/dev/null || true
		return
	fi

	log "Lid closed -> moving ${#MOVED_WORKSPACES[@]} workspaces to ${target}"
	mkdir -p "$(dirname "${STATE_FILE}")" 2>/dev/null || true
	: >"${STATE_FILE}" 2>/dev/null || true
	local ws
	for ws in "${MOVED_WORKSPACES[@]}"; do
		echo "${ws}" >>"${STATE_FILE}" 2>/dev/null || true
		hyprctl dispatch moveworkspacetomonitor "${ws}" "${target}" >/dev/null 2>&1 || true
	done

	set_internal_disabled true
	hyprctl dispatch focusmonitor "${target}" >/dev/null 2>&1 || true
	sleep "${MONITOR_SETTLE_DELAY}"
	reapply_wallpaper

	restart_waybar
}

handle_lid_opened() {
	log "Lid opened -> restoring internal display"
	set_internal_disabled false
	sleep 1
	restore_internal_workspaces
	reapply_wallpaper

	restart_waybar
}

run_once() {
	local action="$1"

	require_tools
	wait_for_hypr
	resolve_internal_output || exit 0

	if [[ "${action}" == "closed" ]]; then
		handle_lid_closed
	else
		# Workspace restore state from a prior one-shot close is read back
		# from STATE_FILE inside restore_internal_workspaces.
		handle_lid_opened
	fi
}

watch_loop() {
	require_tools

	if [[ ! -r "${LID_STATE_PATH}" ]]; then
		log "Lid state path ${LID_STATE_PATH} not readable; exiting"
		exit 0
	fi

	wait_for_hypr
	resolve_internal_output || exit 0

	log "Initial lid state: $(current_lid_state); internal output: ${INTERNAL_OUTPUT}"

	# Lid edges are handled by the bindl one-shots; this loop only reconciles
	# actual monitor enablement against the lid state so each edge is not
	# handled twice (double waybar restart, focus yank).
	while true; do
		local state
		state=$(current_lid_state)
		if [[ "${state}" == "closed" ]] && internal_output_enabled; then
			log "Lid closed but ${INTERNAL_OUTPUT} is enabled; re-applying clamshell mode"
			handle_lid_closed
		elif [[ "${state}" != "closed" ]] && ! internal_output_enabled; then
			log "Lid open but ${INTERNAL_OUTPUT} is disabled; restoring internal display"
			handle_lid_opened
		fi
		sleep "${POLL_INTERVAL}"
		resolve_internal_output || continue
	done
}

case "${1:-watch}" in
closed)
	run_once closed
	;;
opened | open)
	run_once opened
	;;
watch)
	watch_loop
	;;
*)
	echo "Usage: $0 [closed|opened|watch]" >&2
	exit 1
	;;
esac
