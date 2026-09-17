#!/bin/bash
# Reload Hyprland configuration

hyprctl reload
echo "Hyprland configuration reloaded!"

# Restart Waybar if managed by systemd user service
if systemctl --user list-unit-files waybar.service >/dev/null 2>&1; then
  systemctl --user try-restart waybar.service >/dev/null 2>&1 || true
fi

# Re-apply wallpaper (and ensure swww-daemon matches current WAYLAND_DISPLAY)
if [[ -x ~/.config/scripts/wallpaper-cycle.sh ]]; then
  ~/.config/scripts/wallpaper-cycle.sh apply >/dev/null 2>&1 || true
fi

# Send notification
if command -v notify-send >/dev/null 2>&1; then
  notify-send "Hyprland" "Configuration reloaded!" -t 2000
fi
