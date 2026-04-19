#!/usr/bin/env bash
set -euo pipefail

DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-cycle"
INDEX_FILE="$CACHE/index"
FILES=()

wallpaper_backend() {
  if command -v awww >/dev/null 2>&1; then
    echo "awww"
    return 0
  fi

  if command -v swww >/dev/null 2>&1; then
    echo "swww"
    return 0
  fi

  return 1
}

if [ ! -d "$DIR" ]; then
  notify-send "Wallpapers" "Directory $DIR not found" -u low >/dev/null 2>&1 || true
  exit 0
fi

mapfile -t FILES < <(find "$DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)
if [ ${#FILES[@]} -eq 0 ]; then
  notify-send "Wallpapers" "No images found in $DIR" -u low >/dev/null 2>&1 || true
  exit 0
fi

mkdir -p "$CACHE"
current=${FILES[0]}
if [ -f "$INDEX_FILE" ]; then
  saved=$(cat "$INDEX_FILE" 2>/dev/null || echo 0)
  if [[ "$saved" =~ ^[0-9]+$ ]] && [ "$saved" -lt ${#FILES[@]} ]; then
    current=${FILES[$saved]}
  fi
fi

shift_index() {
  local delta=$1
  local idx=${2:-0}
  local total=${#FILES[@]}
  idx=$(( (idx + delta) % total ))
  if [ $idx -lt 0 ]; then
    idx=$((idx + total))
  fi
  echo $idx
}

ensure_daemon() {
  local backend=${1:-}
  local runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  local display=${WAYLAND_DISPLAY:-wayland-0}

  if [ -z "$backend" ]; then
    backend=$(wallpaper_backend || true)
  fi

  case "$backend" in
    awww)
      if ! pgrep -x awww-daemon >/dev/null 2>&1; then
        rm -f "$runtime_dir/${display}-awww-daemon.sock"
        setsid -f env WAYLAND_DISPLAY="$display" awww-daemon >/dev/null 2>&1
        sleep 0.5
      fi
      ;;
    swww)
      if ! pgrep -x swww-daemon >/dev/null 2>&1; then
        setsid -f env WAYLAND_DISPLAY="$display" swww-daemon >/dev/null 2>&1
        sleep 0.5
      fi
      ;;
  esac
}

current_index() {
  local target="$1"
  local i
  for i in "${!FILES[@]}"; do
    if [ "${FILES[$i]}" = "$target" ]; then
      echo "$i"
      return 0
    fi
  done
  echo 0
}

op=${1:-next}
case "$op" in
  next)
    ensure_daemon
    base_index=$(current_index "$current")
    new_index=$(shift_index 1 "$base_index")
    ;;
  prev)
    ensure_daemon
    base_index=$(current_index "$current")
    new_index=$(shift_index -1 "$base_index")
    ;;
  random)
    ensure_daemon
    new_index=$(( RANDOM % ${#FILES[@]} ))
    ;;
  set)
    target=${2:-}
    if [ -z "$target" ]; then
      echo "Usage: $0 set <path>" >&2
      exit 1
    fi
    for i in "${!FILES[@]}"; do
      if [ "${FILES[$i]}" = "$target" ]; then
        new_index=$i
        break
      fi
    done
    if [ -z "${new_index:-}" ]; then
      echo "Wallpaper $target not found in $DIR" >&2
      exit 1
    fi
    ensure_daemon
    ;;
  apply|current)
    ensure_daemon
    new_index=$(current_index "$current")
    ;;
  *)
    new_index=$(shift_index 1 0)
    ;;
esac

selected=${FILES[$new_index]}
backend=$(wallpaper_backend || true)

case "$backend" in
  awww)
    ensure_daemon "$backend"
    if ! awww img "$selected" --transition-type grow --transition-duration 1 >/dev/null 2>&1; then
      awww img "$selected" >/dev/null 2>&1 || true
    fi
    ;;
  swww)
    ensure_daemon "$backend"
    if ! swww img "$selected" --transition-type grow --transition-duration 1 >/dev/null 2>&1; then
      swww img "$selected" >/dev/null 2>&1 || true
    fi
    ;;
  *)
    notify-send "Wallpapers" "Neither awww nor swww is installed" -u low >/dev/null 2>&1 || true
    ;;
esac

echo "$new_index" >"$INDEX_FILE"
