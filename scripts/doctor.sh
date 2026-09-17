#!/usr/bin/env bash
set -euo pipefail

failures=0

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '✓ %s\n' "$1"
  else
    printf '✖ %s\n' "$1"
    failures=$((failures + 1))
  fi
}

printf '== Commands ==\n'
for cmd in Hyprland kitty nvim yazi waybar mako wofi jq rsync mpv grimblast wf-recorder hyprlock hypridle hyprpaper hyprsunset; do
  check_cmd "$cmd"
done

printf '\n== Music TUI ==\n'
if command -v bester-ytm >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/bester-ytm" ]]; then
  printf '✓ bester-ytm installed\n'
else
  printf '✖ bester-ytm missing (apply.sh installs it via uv)\n'
  failures=$((failures + 1))
fi

printf '\n== AGS Runtime ==\n'
runtime_env="${AGS_RUNTIME_ENV:-$HOME/.local/share/arch-hypr-neobrutalist/ags/env.sh}"
if [[ -f "$runtime_env" ]] && (
  # shellcheck disable=SC1090
  source "$runtime_env"
  command -v ags >/dev/null 2>&1
  [[ -d "${AGS_JS_PACKAGE:-}" ]]
); then
  printf '✓ pinned AGS runtime: %s\n' "$runtime_env"
else
  printf '✖ pinned AGS runtime missing or incomplete: %s\n' "$runtime_env"
  failures=$((failures + 1))
fi

printf '\n== Files ==\n'
for path in \
  "$HOME/.config/ags/app.tsx" \
  "$HOME/.config/hypr/hypridle.conf" \
  "$HOME/.config/hypr/hyprsunset.conf" \
  "$HOME/.config/kitty/kitty.conf" \
  "$HOME/.config/nvim/init.lua" \
  "$HOME/.config/yazi/yazi.toml" \
  "$HOME/.config/waybar/config.jsonc" \
  "$HOME/.config/waybar/style.css" \
  "$HOME/.config/waybar/theme.css" \
  "$HOME/.config/mako/config"; do
  if [[ -f "$path" ]]; then
    printf '✓ %s\n' "$path"
  else
    printf '✖ %s\n' "$path"
    failures=$((failures + 1))
  fi
done

printf '\n== Active Hyprland Config ==\n'
if [[ -f "$HOME/.config/hypr/hyprland.lua" ]]; then
  hypr_paths=(
    "$HOME/.config/hypr/hyprland.lua"
    "$HOME/.config/hypr/monitors.lua"
    "$HOME/.config/hypr/conf.d/50-binds.lua"
    "$HOME/.config/hypr/theme.lua"
  )
  printf '✓ Lua entrypoint selected\n'
else
  hypr_paths=(
    "$HOME/.config/hypr/hyprland.conf"
    "$HOME/.config/hypr/monitors.conf"
    "$HOME/.config/hypr/conf.d/50-binds.conf"
    "$HOME/.config/hypr/theme.conf"
  )
  printf '✓ legacy entrypoint selected\n'
fi
for path in "${hypr_paths[@]}"; do
  if [[ -f "$path" ]]; then
    printf '✓ %s\n' "$path"
  else
    printf '✖ %s\n' "$path"
    failures=$((failures + 1))
  fi
done

printf '\n== Bash Integration ==\n'
if grep -Fq '.config/bash/bashrc' "$HOME/.bashrc" 2>/dev/null; then
  printf '✓ ~/.bashrc sources ~/.config/bash/bashrc\n'
else
  printf '✖ ~/.bashrc is not sourcing ~/.config/bash/bashrc\n'
  failures=$((failures + 1))
fi

printf '\n== State Preservation ==\n'
if [[ -f "${XDG_STATE_HOME:-$HOME/.local/state}/hypr/workspace-names.json" ]]; then
  printf '✓ Workspace name state file is present and will not be deleted by make apply\n'
else
  printf '• Workspace names will be created on first rename and preserved on future applies\n'
fi

printf '\n== Result ==\n'
if (( failures == 0 )); then
  printf 'All checks passed.\n'
  exit 0
fi

printf '%d check(s) failed.\n' "$failures"
exit 1
