#!/bin/bash
# Restart waybar (shared helper for clamshell-mode.sh and monitor-connect.sh)

set -euo pipefail

LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-restart.lock"
LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar.log"

stop_waybar() {
    pkill -x waybar || true
    for _ in $(seq 1 20); do
        pgrep -x waybar >/dev/null 2>&1 || return 0
        sleep 0.1
    done

    pkill -KILL -x waybar || true
    for _ in $(seq 1 10); do
        pgrep -x waybar >/dev/null 2>&1 || return 0
        sleep 0.1
    done

    return 1
}

# Serialize concurrent restarts (dock events can fire clamshell-mode.sh and
# monitor-connect.sh at the same time) and wait for the old instance to exit
# so the respawn cannot race a second pkill into duplicate waybars.
(
    flock -x 200

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi

    if command -v systemctl >/dev/null 2>&1 &&
        systemctl --user cat waybar.service >/dev/null 2>&1; then
        systemctl --user stop waybar.service >/dev/null 2>&1 || true
        stop_waybar
        if systemctl --user start waybar.service &&
            systemctl --user is-active --quiet waybar.service; then
            exit 0
        fi
        systemctl --user stop waybar.service >/dev/null 2>&1 || true
    fi

    stop_waybar
    setsid waybar >"${LOG_FILE}" 2>&1 200>&- &
    disown
) 200>"${LOCK_FILE}"
