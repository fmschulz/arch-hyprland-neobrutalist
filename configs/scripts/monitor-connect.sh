#!/bin/bash
# Monitor connection script for Hyprland

set -euo pipefail

# Auto-configure monitors
hyprctl reload || true

# Restart waybar to fix duplication issues
if [[ -x ~/.config/scripts/waybar-restart.sh ]]; then
	~/.config/scripts/waybar-restart.sh || true
fi

# Re-apply the configured wallpaper after the monitor layout changes
if [[ -x ~/.config/scripts/wallpaper-cycle.sh ]]; then
	~/.config/scripts/wallpaper-cycle.sh apply >/dev/null 2>&1 || true
fi

notify-send "Monitors reconfigured" 2>/dev/null || true
