#!/usr/bin/env bash
set -euo pipefail
umask 077

SELF=$(realpath "${BASH_SOURCE[0]}")
signature=${HYPRLAND_INSTANCE_SIGNATURE:?Run inside Hyprland}
state_dir="${XDG_RUNTIME_DIR:?}/controlcenter-display-$signature"
mkdir -p "$state_dir"
lock="$state_dir/lock"
internal=${INTERNAL_OUTPUT:-}
internal_mode=${INTERNAL_MODE:-preferred,auto,1}
lid_path=${LID_STATE_PATH:-/proc/acpi/button/lid/LID0/state}

lid_closed() { [[ -r "$lid_path" ]] && [[ $(awk '{print $2}' "$lid_path") == closed ]]; }
monitors() { hyprctl -j monitors all; }
resolve_internal() {
  [[ -n "$internal" ]] || internal=$(monitors | jq -r \
    '[.[] | select(.name | test("^(eDP|LVDS)-"))][0].name // empty')
}
active() { ! flock -n "$lock" true; }
state() {
  jq -n --arg phase "$1" --arg message "$2" --argjson deadline "${3:-0}" \
    '{phase:$phase,message:$message,deadline:$deadline}' >"$state_dir/state.new"
  mv "$state_dir/state.new" "$state_dir/state.json"
}
keyword() {
  local reply
  reply=$(hyprctl keyword monitor "$1")
  [[ "$reply" == ok ]]
}
rule() {
  jq -r '"\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale),transform,\(.transform)" +
    (if .mirrorOf != "none" and .mirrorOf != null then ",mirror,\(.mirrorOf)" else "" end)'
}

restore() {
  local monitor name current
  current=$(monitors) || return 1
  # Enable the original visible outputs first. Never disable the last output.
  while IFS= read -r monitor; do
    name=$(jq -r '.name' <<<"$monitor")
    jq -e --arg name "$name" 'any(.[]; .name == $name)' <<<"$current" >/dev/null || continue
    keyword "$(rule <<<"$monitor")" || return 1
  done < <(jq -c 'sort_by(.mirrorOf != "none")[] | select(.disabled == false)' "$state_dir/before.json")
  current=$(hyprctl -j monitors)
  while IFS= read -r name; do
    if jq -e --arg name "$name" 'any(.[]; .name != $name and (.mirrorOf == "none" or .mirrorOf == null))' <<<"$current" >/dev/null; then
      keyword "$name,disable" || return 1
      current=$(hyprctl -j monitors)
    fi
  done < <(jq -r '.[] | select(.disabled) | .name' "$state_dir/before.json")
  # Disabling an output moves workspaces; restore surviving workspace placement too.
  current=$(hyprctl -j monitors)
  while IFS=$'\t' read -r workspace name; do
    if jq -e --arg name "$name" 'any(.[]; .name == $name)' <<<"$current" >/dev/null; then
      hyprctl dispatch moveworkspacetomonitor "$workspace" "$name" >/dev/null || true
    fi
  done < <(jq -r '.[] | [.id,.monitor] | @tsv' "$state_dir/workspaces.json")
  for ((attempt=0; attempt<20; attempt++)); do
    if monitors | jq -e --slurpfile before "$state_dir/before.json" '
      . as $after | all($before[0][]; . as $old |
        any($after[]; .name == $old.name and .disabled == $old.disabled and
          (if $old.disabled then true else
            .width == $old.width and .height == $old.height and
            ((.refreshRate - $old.refreshRate) | fabs) < 0.1 and
            .x == $old.x and .y == $old.y and .scale == $old.scale and
            .transform == $old.transform and .mirrorOf == $old.mirrorOf
          end)))' >/dev/null; then return 0; fi
    sleep 0.1
  done
  return 1
}

preview() (
  local profile=$1 external target before kept=false changed=false failure=''
  exec 9>"$lock"
  flock -n 9 || exit 1
  state starting 'Checking displays…'
  before=$(monitors)
  external=$(jq -r --arg internal "$internal" '[.[] | select(.name != $internal)] | sort_by(.disabled) | .[0].name // empty' <<<"$before")
  if ! jq -e --arg internal "$internal" 'any(.[]; .name == $internal)' <<<"$before" >/dev/null; then
    state error 'The laptop display is not available.'; return 1
  fi
  if [[ "$profile" != laptop && -z "$external" ]]; then
    state error 'Connect an external display first.'; return 1
  fi
  if [[ "$profile" != external ]] && lid_closed; then
    state error 'Open the laptop lid before using this profile.'; return 1
  fi
  printf '%s\n' "$before" >"$state_dir/before.json"
  hyprctl -j workspaces >"$state_dir/workspaces.json"
  rm -f "$state_dir/action"
  # ShellCheck cannot follow this EXIT callback inside the transaction subshell.
  # shellcheck disable=SC2329
  finish() {
    trap - EXIT INT TERM
    if ! "$kept" && "$changed"; then
      if restore; then
        if [[ -n "$failure" ]]; then state error "$failure Previous layout restored."
        else state restored 'Previous display layout restored.'; fi
      else state error 'Could not restore every display. Check connections or use Super+Ctrl+M to reset.'; fi
    fi
  }
  trap 'finish' EXIT
  trap 'exit 1' INT TERM
  changed=true
  target=$internal
  [[ "$profile" != external ]] || target=$external
  # Preserve active targets; use a portable preferred mode when re-enabling one.
  local target_rule
  target_rule=$(jq -c --arg name "$target" '.[] | select(.name == $name)' <<<"$before")
  if jq -e '.disabled' <<<"$target_rule" >/dev/null; then
    if [[ "$target" == "$internal" ]]; then keyword "$target,$internal_mode"
    else keyword "$target,preferred,auto,1"; fi
  else keyword "$(jq '.mirrorOf="none"' <<<"$target_rule" | rule)"; fi
  # Wait for the target to be usable before disabling another output.
  local ready=false
  for ((attempt=0; attempt<20; attempt++)); do
    if hyprctl -j monitors | jq -e --arg name "$target" 'any(.[]; .name == $name and .disabled == false)' >/dev/null; then ready=true; break; fi
    sleep 0.1
  done
  "$ready" || return 1
  if [[ "$profile" == mirror ]]; then
    keyword "$external,preferred,auto,1,mirror,$internal"
  else
    local name
    while IFS= read -r name; do keyword "$name,disable"; done < <(jq -r --arg target "$target" '.[] | select(.name != $target) | .name' <<<"$before")
  fi
  # A successful IPC reply alone does not mean the backend applied the request.
  local applied=false after
  for ((attempt=0; attempt<20; attempt++)); do
    after=$(monitors)
    if [[ "$profile" == mirror ]]; then
      if jq -e --arg external "$external" --arg internal "$internal" 'any(.[]; .name == $external and .mirrorOf == $internal)' <<<"$after" >/dev/null; then applied=true; break; fi
    elif jq -e --arg target "$target" '[.[] | select(.disabled == false)] | length == 1 and .[0].name == $target' <<<"$after" >/dev/null; then applied=true; break
    fi
    sleep 0.1
  done
  if ! "$applied"; then failure='The compositor did not apply that profile.'; return 1; fi
  local deadline=$(( $(date +%s) + 15 ))
  state preview 'Keep this display layout?' "$deadline"
  while (( $(date +%s) < deadline )); do
    case "$(cat "$state_dir/action" 2>/dev/null || true)" in
      keep) kept=true; state kept 'Display layout kept for this session.'; return 0 ;;
      revert) return 0 ;;
    esac
    sleep 0.1
  done
)

case "${1:-status}" in
  preview)
    case "${2:-}" in laptop|external|mirror) ;; *) exit 2 ;; esac
    resolve_internal
    [[ -n "$internal" ]] || { state error 'No internal display was detected.'; exit 1; }
    active && { printf 'A display change is already pending.\n' >&2; exit 1; }
    rm -f "$state_dir/state.json"
    # The guard lives in its own user unit, outside the AGS process group/cgroup.
    systemd-run --user --collect --quiet --unit="controlcenter-display-$signature" \
      --setenv="HYPRLAND_INSTANCE_SIGNATURE=$signature" --setenv="INTERNAL_OUTPUT=$internal" \
      --setenv="LID_STATE_PATH=$lid_path" "$SELF" guard "$2"
    ;;
  guard)
    case "${2:-}" in laptop|external|mirror) preview "$2" ;; *) exit 2 ;; esac
    ;;
  keep|revert)
    if active; then
      printf '%s\n' "$1" >"$state_dir/action"
      flock -w 5 "$lock" true
    fi
    ;;
  status)
    if [[ -f "$state_dir/state.json" ]]; then
      if active; then jq . "$state_dir/state.json"
      else jq 'if .phase == "preview" or .phase == "starting" then .phase="error" | .message="Display preview stopped unexpectedly." else . end' "$state_dir/state.json"; fi
    else printf '{"phase":"idle","message":"","deadline":0}\n'; fi
    ;;
  *) printf 'Usage: display-profile.sh preview laptop|external|mirror | keep | revert | status\n' >&2; exit 2 ;;
esac
