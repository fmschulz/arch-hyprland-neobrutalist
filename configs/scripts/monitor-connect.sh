#!/bin/bash
# Monitor connection script for Hyprland

# Get available monitors
monitors=$(hyprctl monitors | grep "Monitor" | awk '{print $2}')

echo "Available monitors:"
echo "$monitors"

# Auto-configure monitors
hyprctl reload

# Restart waybar to fix duplication issues
pkill -x waybar || true
waybar &

# Re-apply the configured wallpaper after the monitor layout changes
if [[ -x ~/.config/scripts/wallpaper-cycle.sh ]]; then
	~/.config/scripts/wallpaper-cycle.sh apply >/dev/null 2>&1 || true
fi

echo "Monitor configuration updated!"
