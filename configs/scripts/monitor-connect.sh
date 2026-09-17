#!/bin/bash
# Monitor connection script for Hyprland

# Get available monitors
monitors=$(hyprctl monitors | grep "Monitor" | awk '{print $2}')

echo "Available monitors:"
echo "$monitors"

# Auto-configure monitors
hyprctl reload

# Re-apply current wallpaper on all monitors
if [ -x "$HOME/.config/scripts/wallpaper-cycle.sh" ]; then
  "$HOME/.config/scripts/wallpaper-cycle.sh" apply >/dev/null 2>&1 || true
elif command -v swww >/dev/null 2>&1; then
  fallback_wallpaper=$(find "${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort | head -n 1)
  if [ -n "$fallback_wallpaper" ]; then
    swww img "$fallback_wallpaper" >/dev/null 2>&1 || true
  fi
fi

echo "Monitor configuration updated!"
