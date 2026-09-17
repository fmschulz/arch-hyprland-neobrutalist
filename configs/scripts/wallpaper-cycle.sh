#!/usr/bin/env bash
set -euo pipefail

DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-cycle"
INDEX_FILE="$CACHE/index"
CURRENT_LINK="$CACHE/current"

fail() {
  printf 'wallpaper-cycle: %s\n' "$*" >&2
  exit 1
}

[[ -d "$DIR" ]] || fail "Wallpaper directory not found: $DIR"
DIR=$(realpath "$DIR")
mapfile -d '' -t files < <(find "$DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0 | sort -z)
((${#files[@]})) || fail "No images found in $DIR"

mkdir -p "$CACHE"
exec 9>"$CACHE/lock"
flock 9

# Prefer the saved path so adding an image does not change the selection.
index=0
if [[ -f "$INDEX_FILE" ]]; then
  saved=$(<"$INDEX_FILE")
  if [[ "$saved" =~ ^[0-9]+$ ]] && ((10#$saved < ${#files[@]})); then
    index=$((10#$saved))
  fi
fi
current=$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)
for i in "${!files[@]}"; do
  if [[ "${files[$i]}" == "$current" ]]; then
    index=$i
    break
  fi
done

case "${1:-next}" in
  next) index=$(((index + 1) % ${#files[@]})) ;;
  prev) index=$(((index + ${#files[@]} - 1) % ${#files[@]})) ;;
  random) index=$((RANDOM % ${#files[@]})) ;;
  apply|current) ;;
  set)
    [[ -n "${2:-}" ]] || fail "Usage: $0 set <path>"
    index=-1
    for i in "${!files[@]}"; do
      if [[ "${files[$i]}" == "$2" ]]; then
        index=$i
        break
      fi
    done
    ((index >= 0)) || fail "Wallpaper is not in $DIR: $2"
    ;;
  *) fail "Usage: $0 [next|prev|random|set <path>|apply|current]" ;;
esac

selected=${files[$index]}
[[ "$selected" != *,* && "$selected" != *$'\n'* ]] || fail "Hyprpaper IPC cannot accept commas or newlines in wallpaper paths"
[[ -n "${WAYLAND_DISPLAY:-}" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || fail "Run this command inside the Hyprland session"

# One owner starts the daemon. Changes use IPC, without restarts or process kills.
if ! timeout 2s hyprctl hyprpaper listactive >/dev/null 2>&1; then
  systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
  systemctl --user start hyprpaper.service || fail "Cannot start hyprpaper.service; check its user journal"
  ready=false
  deadline=$((SECONDS + 5))
  while ((SECONDS < deadline)); do
    if timeout 2s hyprctl hyprpaper listactive >/dev/null 2>&1; then
      ready=true
      break
    fi
    sleep 0.1
  done
  "$ready" || fail "Hyprpaper IPC is unavailable; check hyprpaper.service and its configuration"
fi

# Explicit outputs override the saved fallback configured at daemon startup.
monitor_list=$(hyprctl monitors) || fail "Cannot read the active monitors"
mapfile -t monitors < <(awk '/^Monitor / {print $2}' <<<"$monitor_list")
((${#monitors[@]})) || fail "No active monitors"
for monitor in "${monitors[@]}"; do
  timeout 5s hyprctl hyprpaper wallpaper "$monitor,$selected,cover" || fail "Hyprpaper rejected the wallpaper for $monitor"
done

# The IPC acknowledgment precedes image loading. Check the rendered selection.
applied=false
deadline=$((SECONDS + 5))
while ((SECONDS < deadline)); do
  active=$(timeout 2s hyprctl hyprpaper listactive) || fail "Cannot read hyprpaper status"
  applied=true
  for monitor in "${monitors[@]}"; do
    grep -Fxq -- "$monitor: $selected" <<<"$active" || applied=false
  done
  "$applied" && break
  sleep 0.1
done
"$applied" || fail "Wallpaper did not become active; saved selection is unchanged"

printf '%s\n' "$index" >"$INDEX_FILE"
ln -sfn "$selected" "$CURRENT_LINK"
