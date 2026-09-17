#!/usr/bin/env bash
set -euo pipefail

# Power menu (wofi) for Hyprland.

options=$(
  cat <<'EOF'
Lock
Sleep
Logout
Reboot
Shutdown
EOF
)

# hide_search: the CSS "#input { display: none }" trick is a no-op in GTK CSS,
# so the search bar still rendered and clipped Shutdown at height 300.
choice=$(
  printf '%s\n' "$options" | wofi --dmenu \
    --prompt "Power" \
    --style ~/.config/wofi/power-menu.css \
    --width 240 \
    --height 280 \
    -D hide_search=true \
    --cache-file /dev/null
)

[[ -z "${choice:-}" ]] && exit 0

case "$choice" in
  Lock) ~/.config/scripts/secure-lock.sh ;;
  Sleep) systemctl suspend ;;
  Logout) ~/.config/scripts/clear-sensitive-state.sh || true; hyprctl dispatch exit ;;
  Reboot) ~/.config/scripts/clear-sensitive-state.sh || true; systemctl reboot ;;
  Shutdown) ~/.config/scripts/clear-sensitive-state.sh || true; systemctl poweroff ;;
esac
