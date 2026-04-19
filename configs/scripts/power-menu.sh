#!/usr/bin/env bash
# Power menu with lock, sleep, reboot, shutdown options
# Uses wofi with proper sizing for all options

set -euo pipefail

options="🔒 Lock
😴 Sleep
🔄 Reboot
⏻ Shutdown
🚪 Logout"

choice=$(echo -e "$options" | wofi --dmenu \
    --prompt "Power" \
    --width 280 \
    --height 320 \
    --cache-file /dev/null \
    --insensitive)

[[ -z "$choice" ]] && exit 0

case "$choice" in
    *Lock*)
        hyprlock
        ;;
    *Sleep*)
        systemctl suspend
        ;;
    *Reboot*)
        systemctl reboot
        ;;
    *Shutdown*)
        systemctl poweroff
        ;;
    *Logout*)
        hyprctl dispatch exit
        ;;
    *)
        exit 0
        ;;
esac
