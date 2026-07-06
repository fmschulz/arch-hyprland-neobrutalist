#!/usr/bin/env bash
# Master desktop menu (Super+Alt+Space): one wofi dispatcher for apps,
# capture, style, toggles, and system actions.
set -euo pipefail

SCRIPTS="${XDG_CONFIG_HOME:-$HOME/.config}/scripts"

menu() {
  local prompt="$1"
  shift
  printf '%s\n' "$@" | wofi --dmenu --prompt "$prompt" \
    --width 420 --height 380 --cache-file /dev/null 2>/dev/null
}

main_menu() {
  menu "Desktop" \
    "Apps" \
    "Capture" \
    "Style" \
    "Toggles" \
    "System"
}

capture_menu() {
  case "$(menu "Capture" \
    "Screenshot area" \
    "Screenshot output" \
    "Record area (toggle)" \
    "Color picker")" in
  "Screenshot area") exec "$SCRIPTS/screenshot.sh" save-area ;;
  "Screenshot output") exec "$SCRIPTS/screenshot.sh" save-output ;;
  "Record area (toggle)") exec "$SCRIPTS/screenrecord.sh" ;;
  "Color picker") hyprpicker -a && notify-send -t 2000 "Color picker" "Copied $(wl-paste)" ;;
  esac
}

style_menu() {
  local choice
  choice=$(menu "Style" \
    "Theme: next" \
    "Theme: pick" \
    "Wallpaper: next" \
    "Wallpaper: random")
  case "$choice" in
  "Theme: next") exec "$SCRIPTS/theme-set.sh" next ;;
  "Theme: pick")
    local t
    t=$("$SCRIPTS/theme-set.sh" list | wofi --dmenu --prompt "Theme" \
      --width 300 --height 320 --cache-file /dev/null 2>/dev/null) || exit 0
    [[ -n "$t" ]] && exec "$SCRIPTS/theme-set.sh" "$t"
    ;;
  "Wallpaper: next") exec "$SCRIPTS/wallpaper-cycle.sh" next ;;
  "Wallpaper: random") exec "$SCRIPTS/wallpaper-cycle.sh" random ;;
  esac
}

toggles_menu() {
  case "$(menu "Toggles" \
    "Waybar show/hide" \
    "Night light: warm (4200K)" \
    "Night light: off")" in
  "Waybar show/hide") pkill -SIGUSR1 -x waybar ;;
  "Night light: warm (4200K)") hyprctl hyprsunset temperature 4200 >/dev/null ;;
  "Night light: off") hyprctl hyprsunset identity >/dev/null ;;
  esac
}

system_menu() {
  case "$(menu "System" \
    "Update packages" \
    "Reload Hyprland + Waybar" \
    "Lock screen" \
    "Power menu")" in
  "Update packages") exec kitty -e bash -c 'sudo pacman -Syu; pkill -RTMIN+9 waybar; echo; echo Press any key to close...; read -n1' ;;
  "Reload Hyprland + Waybar") exec "$SCRIPTS/reload.sh" ;;
  "Lock screen") exec hyprlock ;;
  "Power menu") exec "$SCRIPTS/power-menu.sh" ;;
  esac
}

case "$(main_menu)" in
Apps) exec wofi -c ~/.config/wofi/config -s ~/.config/wofi/style.css ;;
Capture) capture_menu ;;
Style) style_menu ;;
Toggles) toggles_menu ;;
System) system_menu ;;
esac
