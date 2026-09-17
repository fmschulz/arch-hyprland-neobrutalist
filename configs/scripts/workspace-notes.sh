#!/bin/bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-hyprland-setup"
NOTES_FILE="${STATE_DIR}/workspace-notes.tsv"
CLICK_DIR="${STATE_DIR}/waybar-clicks"
DOUBLE_CLICK_MS="${DOUBLE_CLICK_MS:-450}"

mkdir -p "$STATE_DIR" "$CLICK_DIR"

die() {
  echo "workspace-notes: $*" >&2
  exit 1
}

normalize_workspace() {
  local raw="${1:-}"
  if [[ -z "$raw" || "$raw" == "{name}" || "$raw" == "{id}" ]]; then
    if [[ -n "${WAYBAR_WORKSPACE_ID:-}" ]]; then
      normalize_workspace "${WAYBAR_WORKSPACE_ID}"
      return 0
    fi
    if [[ -n "${WAYBAR_WORKSPACE:-}" ]]; then
      normalize_workspace "${WAYBAR_WORKSPACE}"
      return 0
    fi
    if [[ -n "${WAYBAR_WORKSPACE_NAME:-}" ]]; then
      normalize_workspace "${WAYBAR_WORKSPACE_NAME}"
      return 0
    fi
    if command -v hyprctl >/dev/null 2>&1; then
      raw="$(hyprctl activeworkspace -j 2>/dev/null | awk -F: '/"id"/ {gsub(/[^0-9]/,"",$2); print $2; exit}')"
      if [[ "$raw" =~ ^[1-9][0-9]*$ ]]; then
        echo "$raw"
        return 0
      fi
      die "invalid active workspace id: $raw"
    fi
    die "missing workspace id"
  fi

  if [[ "$raw" =~ ^[1-9][0-9]*$ ]]; then
    echo "$raw"
    return 0
  fi

  raw="${raw//[^0-9]/}"
  if [[ "$raw" =~ ^[1-9][0-9]*$ ]]; then
    echo "$raw"
    return 0
  fi

  die "invalid workspace id: $1"
}

get_note() {
  local ws="$1"
  [[ -f "$NOTES_FILE" ]] || return 0
  awk -F'\t' -v ws="$ws" '$1 == ws { sub(/^[^\t]*\t/, "", $0); print; exit }' "$NOTES_FILE"
}

set_note() {
  local ws="$1"
  local note="$2"
  local tmp

  mkdir -p "$(dirname "$NOTES_FILE")"
  tmp="$(mktemp)"

  if [[ -f "$NOTES_FILE" ]]; then
    awk -F'\t' -v ws="$ws" '$1 != ws { print }' "$NOTES_FILE" >"$tmp"
  fi

  if [[ -n "$note" ]]; then
    printf "%s\t%s\n" "$ws" "$note" >>"$tmp"
  fi

  mv "$tmp" "$NOTES_FILE"
}

wofi_dmenu() {
  if ! command -v wofi >/dev/null 2>&1; then
    die "wofi not installed"
  fi
  wofi -s "$HOME/.config/wofi/style.css" --dmenu "$@"
}

list_workspace_names_tsv() {
  if ! command -v hyprctl >/dev/null 2>&1; then
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    hyprctl workspaces -j 2>/dev/null | jq -r '.[] | "\(.id)\t\(.name)"' || true
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    hyprctl workspaces -j 2>/dev/null | python3 -c '
import json
import sys

data = json.load(sys.stdin)
for ws in data:
  ws_id = ws.get("id")
  name = ws.get("name", "")
  if ws_id is None:
    continue
  print(f"{ws_id}\t{name}")
' || true
    return 0
  fi
}

get_workspace_name() {
  local ws="$1"
  list_workspace_names_tsv | awk -F'\t' -v ws="$ws" '$1 == ws { print $2; exit }'
}

format_workspace_name() {
  local ws="$1"
  local name="$2"

  if [[ "$name" == "reset" ]]; then
    printf "%s\n" "$ws"
  elif [[ "$name" == "$ws" || "$name" == "$ws":* ]]; then
    printf "%s\n" "$name"
  else
    printf "%s:%s\n" "$ws" "$name"
  fi
}

rename_workspace() {
  local ws
  local current_name
  local new_name
  local new_name_lua

  command -v hyprctl >/dev/null 2>&1 || die "hyprctl not installed"
  ws="$(normalize_workspace "$1")"
  current_name="$(get_workspace_name "$ws" || true)"

  new_name="$(
    {
      if [[ -n "$current_name" ]]; then
        printf "%s\n" "$current_name"
      else
        printf "%s\n" "$ws"
      fi
    } | wofi_dmenu --prompt "Rename workspace ${ws}" --width 520 --height 140 --lines 1
  )" || return 0

  [[ -n "$new_name" ]] || return 0

  new_name="$(format_workspace_name "$ws" "$new_name")"
  new_name_lua=$(printf %s "$new_name" | od -An -v -t u1 | awk '{ for (i=1;i<=NF;i++) printf "\\%03d", $i }')

  hyprctl dispatch "hl.dsp.workspace.rename({ workspace = $ws, name = \"$new_name_lua\" })"
}

rename_menu() {
  local ws
  local name
  local selected
  local selected_ws

  selected="$(
    for ws in {1..10}; do
      name="$(get_workspace_name "$ws" || true)"
      if [[ -n "$name" && "$name" != "$ws" ]]; then
        printf "%-2s  %s\n" "$ws" "$name"
      else
        printf "%-2s  —\n" "$ws"
      fi
    done | wofi_dmenu --prompt "Rename which workspace?" --width 520 --height 420
  )" || return 0

  selected_ws="$(awk '{print $1}' <<<"$selected")"
  [[ -n "$selected_ws" ]] || return 0
  rename_workspace "$selected_ws"
}

active_workspace_id() {
  command -v hyprctl >/dev/null 2>&1 || return 1
  hyprctl activeworkspace -j 2>/dev/null | awk -F: '/"id"/ {gsub(/[^0-9]/,"",$2); print $2; exit}'
}

now_ms() {
  date +%s%3N 2>/dev/null && return 0
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
    return 0
  fi
  date +%s000
}

annotate_workspace() {
  local ws="$1"
  local current_note
  local new_note

  current_note="$(get_note "$ws" || true)"
  new_note="$(
    {
      printf "%s\n" "$current_note"
    } | wofi_dmenu --prompt "Annotate workspace ${ws}" --width 520 --height 140 --lines 1
  )" || return 0

  set_note "$ws" "$new_note"
}

menu() {
  local ws
  local note
  local selected
  local selected_ws

  selected="$(
    printf "%s\n" "✎ Rename current workspace…"
    printf "%s\n" "✎ Rename workspace…"
    for ws in {1..10}; do
      note="$(get_note "$ws" || true)"
      if [[ -n "$note" ]]; then
        printf "%-2s  %s\n" "$ws" "$note"
      else
        printf "%-2s  —\n" "$ws"
      fi
    done | wofi_dmenu --prompt "Workspaces" --width 520 --height 420
  )" || return 0

  case "$selected" in
    "✎ Rename current workspace…"*)
      rename_workspace "$(active_workspace_id)"
      return 0
      ;;
    "✎ Rename workspace…"*)
      rename_menu
      return 0
      ;;
  esac

  selected_ws="$(awk '{print $1}' <<<"$selected")"
  [[ -n "$selected_ws" ]] || return 0
  selected_ws="$(normalize_workspace "$selected_ws")"

  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch "hl.dsp.focus({ workspace = $selected_ws })"
  fi
}

click() {
  local ws
  local click_now_ms
  local click_file
  local last_ms

  ws="$(normalize_workspace "${1:-}")"

  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch "hl.dsp.focus({ workspace = $ws })"
  fi

  click_now_ms="$(now_ms)"
  click_file="${CLICK_DIR}/ws-${ws}"
  last_ms=""
  [[ -f "$click_file" ]] && last_ms="$(cat "$click_file" 2>/dev/null || true)"
  printf "%s" "$click_now_ms" >"$click_file"

  if [[ -n "$last_ms" ]] && [[ "$click_now_ms" =~ ^[0-9]+$ ]] && [[ "$last_ms" =~ ^[0-9]+$ ]]; then
    if (( click_now_ms - last_ms <= DOUBLE_CLICK_MS )); then
      rm -f "$click_file" || true
      annotate_workspace "$ws" >/dev/null 2>&1 &
    fi
  fi
}

usage() {
  cat <<'EOF'
Usage:
  workspace-notes.sh click <workspace_id>     # for Waybar: switches; double-click prompts for note
  workspace-notes.sh annotate <workspace_id>  # prompt to set/clear note
  workspace-notes.sh rename <workspace_id>    # prompt to set workspace name (type 'reset' to revert to numeric)
  workspace-notes.sh menu                    # wofi list of workspaces with notes
EOF
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    click)
      click "${2:-}"
      ;;
    annotate)
      annotate_workspace "$(normalize_workspace "${2:-}")"
      ;;
    rename)
      rename_workspace "${2:-}"
      ;;
    menu)
      menu
      ;;
    -h|--help|"")
      usage
      ;;
    *)
      die "unknown command: $cmd"
      ;;
  esac
}

main "$@"
