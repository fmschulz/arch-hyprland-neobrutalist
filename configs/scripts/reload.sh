#!/bin/bash
# Reload Hyprland configuration

hyprctl reload
echo "Hyprland configuration reloaded!"

# Waybar is not managed by hyprctl; restart it so a "reload" also clears any
# stale workspace/active-highlight state that drifts over long sessions.
if [ -x "$HOME/.config/scripts/waybar-restart.sh" ]; then
  "$HOME/.config/scripts/waybar-restart.sh"
fi

# Send notification
if command -v notify-send >/dev/null 2>&1; then
  notify-send "Hyprland" "Configuration reloaded!" -t 2000
fi
