#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/arch-hypr-neobrutalist"
STATIONS_FILE="${RADIO_STATIONS_FILE:-$CONFIG_DIR/radio-stations.tsv}"

die() {
  printf 'radio: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"
}

list_stations() {
  [[ -f "$STATIONS_FILE" ]] || die "station file not found: $STATIONS_FILE"
  awk -F '\t' '
    $0 !~ /^[[:space:]]*#/ && NF >= 2 {
      label = $1
      if (NF >= 3 && length($3) > 0) {
        label = label " [" $3 "]"
      }
      printf "%s\t%s\t%s\n", $1, $2, label
    }
  ' "$STATIONS_FILE"
}

choose_station() {
  local selection

  selection="$(
    list_stations | \
      fzf \
        --delimiter=$'\t' \
        --with-nth=3 \
        --prompt='Radio station > ' \
        --height=50% \
        --layout=reverse \
        --border=rounded
  )" || exit 130

  printf '%s\n' "$selection"
}

play_station() {
  local name="$1"
  local url="$2"

  clear
  printf 'Neo Brutalist Radio\n'
  printf 'Station: %s\n' "$name"
  printf 'Press q to stop playback.\n\n'

  exec mpv \
    --no-video \
    --force-window=no \
    --term-title="radio:${name}" \
    "$url"
}

play_by_name() {
  local target="$1"
  local entry

  entry="$(list_stations | awk -F '\t' -v target="$target" '$1 == target { print; exit }')"
  [[ -n "$entry" ]] || die "unknown station: $target"

  play_station "$(printf '%s\n' "$entry" | cut -f1)" "$(printf '%s\n' "$entry" | cut -f2)"
}

usage() {
  cat <<'EOF'
Usage: radio.sh [command]

Commands:
  list           Print configured stations
  play <name>    Play a station by its short name
  menu           Open the interactive selector (default)
EOF
}

case "${1:-menu}" in
  list)
    list_stations | cut -f1,3
    ;;
  play)
    need_cmd mpv
    [[ $# -ge 2 ]] || die "Usage: radio.sh play <name>"
    shift
    play_by_name "$*"
    ;;
  menu)
    need_cmd fzf
    need_cmd mpv
    entry="$(choose_station)"
    play_station "$(printf '%s\n' "$entry" | cut -f1)" "$(printf '%s\n' "$entry" | cut -f2)"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    die "unknown command: $1"
    ;;
esac
