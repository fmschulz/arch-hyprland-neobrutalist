#!/bin/bash
# Restart waybar (shared helper for clamshell-mode.sh and monitor-connect.sh)

set -euo pipefail

LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-restart.lock"
LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar.log"

# Serialize concurrent restarts (dock events can fire clamshell-mode.sh and
# monitor-connect.sh at the same time) and wait for the old instance to exit
# so the respawn cannot race a second pkill into duplicate waybars.
(
    flock -x 200
    pkill -x waybar || true
    for _ in $(seq 1 20); do
        pgrep -x waybar >/dev/null 2>&1 || break
        sleep 0.1
    done
    setsid waybar >"${LOG_FILE}" 2>&1 200>&- &
    disown
) 200>"${LOCK_FILE}"
