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
for cmd in Hyprland kitty nvim yazi waybar mako wofi jq rsync mpv; do
  check_cmd "$cmd"
done

printf '\n== Files ==\n'
for path in \
  "$HOME/.config/hypr/hyprland.conf" \
  "$HOME/.config/hypr/monitors.conf" \
  "$HOME/.config/kitty/kitty.conf" \
  "$HOME/.config/nvim/init.lua" \
  "$HOME/.config/yazi/yazi.toml" \
  "$HOME/.config/waybar/config.jsonc" \
  "$HOME/.config/mako/config" \
  "$HOME/.config/arch-hypr-neobrutalist/radio-stations.tsv"; do
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
if [[ -f "$HOME/.config/hypr/workspace-names.json" ]]; then
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
