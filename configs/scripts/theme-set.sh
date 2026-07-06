#!/usr/bin/env bash
# Atomic desktop theme switch: point the per-app theme symlinks at a theme
# fragment directory and reload everything that renders live.
#
# Usage: theme-set.sh [<name>|next|list|current]
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
THEMES_DIR="${THEMES_DIR:-$CONFIG/arch-hypr-neobrutalist/themes}"
ORDER=(yellow blue purple green orange black darkgrey white)

die() {
  printf 'theme-set: %s\n' "$*" >&2
  exit 1
}

current_theme() {
  local target
  target=$(readlink "$CONFIG/waybar/theme.css" 2>/dev/null) || {
    echo yellow
    return
  }
  basename "$(dirname "$target")"
}

next_theme() {
  local cur i
  cur=$(current_theme)
  for i in "${!ORDER[@]}"; do
    if [[ "${ORDER[$i]}" == "$cur" ]]; then
      echo "${ORDER[$(((i + 1) % ${#ORDER[@]}))]}"
      return
    fi
  done
  echo "${ORDER[0]}"
}

set_theme() {
  local name="$1"
  local dir="$THEMES_DIR/$name"
  [[ -d "$dir" ]] || die "unknown theme: $name (see theme-set.sh list)"

  ln -sfn "$dir/hyprland.conf" "$CONFIG/hypr/theme.conf"
  ln -sfn "$dir/waybar.css" "$CONFIG/waybar/theme.css"
  ln -sfn "$dir/wofi.css" "$CONFIG/wofi/theme.css"
  ln -sfn "$dir/mako.conf" "$CONFIG/mako/theme"
  ln -sfn "$CONFIG/kitty/themes/$(<"$dir/kitty-theme")" "$CONFIG/kitty/theme-current.conf"

  # Live reloads, all guarded so this also works during a headless apply.
  command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
  pgrep -x waybar >/dev/null 2>&1 && pkill -SIGUSR2 -x waybar || true
  command -v makoctl >/dev/null 2>&1 && makoctl reload 2>/dev/null || true
  command -v notify-send >/dev/null 2>&1 &&
    notify-send -t 2000 "Theme: $name" "New Kitty windows pick up the palette (Ctrl+Alt+<n> for open ones)" || true
}

case "${1:-next}" in
list)
  printf '%s\n' "${ORDER[@]}"
  ;;
current)
  current_theme
  ;;
next)
  set_theme "$(next_theme)"
  ;;
-h | --help)
  echo "Usage: theme-set.sh [<name>|next|list|current]"
  ;;
*)
  set_theme "$1"
  ;;
esac
