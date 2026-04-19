#!/bin/bash
# Reload Hyprland configuration

hyprctl reload
echo "Hyprland configuration reloaded!"

# Send notification
if command -v notify-send >/dev/null 2>&1; then
  notify-send "Hyprland" "Configuration reloaded!" -t 2000
fi
