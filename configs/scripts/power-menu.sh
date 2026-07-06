#!/usr/bin/env bash
# Power menu with lock, sleep, reboot, shutdown options
# Uses wofi with proper sizing for all options

set -euo pipefail

options="󰌾 Lock
󰒲 Sleep
󰜉 Reboot
󰐥 Shutdown
󰍃 Logout"

# 520 = window chrome (~110px) + 5 full ~82px text rows; 320 cut the menu
# off after "Reboot" with this CSS (verified by screenshot)
choice=$(echo -e "$options" | wofi --dmenu \
    --prompt "Power" \
    --width 300 \
    --height 520 \
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
