#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  printf '▶ %s\n' "$*"
}

ok() {
  printf '✓ %s\n' "$*"
}

sync_dir() {
  local src="$1"
  local dest="$2"
  mkdir -p "$dest"
  rsync -a "$src/" "$dest/"
}

log "Syncing desktop configs"

mkdir -p \
  "$HOME/.config" \
  "$HOME/.config/systemd/user" \
  "$HOME/.config/arch-hypr-neobrutalist" \
  "$HOME/Pictures/wallpapers" \
  "$HOME/Documents/screenshots" \
  "$HOME/Documents/screenrecordings"

# hypridle has no entry here: its config is tracked as configs/hypr/hypridle.conf
# because hypridle only reads ~/.config/hypr/hypridle.conf.
for name in bash btop hypr kitty mako nvim scripts waybar wofi xdg-desktop-portal yazi; do
  sync_dir "$ROOT/configs/$name" "$HOME/.config/$name"
done

sync_dir "$ROOT/configs/arch-hypr-neobrutalist" "$HOME/.config/arch-hypr-neobrutalist"
sync_dir "$ROOT/configs/systemd/user" "$HOME/.config/systemd/user"
rsync -a \
  --exclude '.gitkeep' \
  --exclude 'README.md' \
  "$ROOT/wallpapers/" "$HOME/Pictures/wallpapers/"

if [[ -d "$ROOT/configs/greetd" ]]; then
  ok "greetd theme assets available for optional install"
fi

if [[ -f "$ROOT/configs/arch-hypr-neobrutalist/radio-stations.tsv.example" ]] && [[ ! -f "$HOME/.config/arch-hypr-neobrutalist/radio-stations.tsv" ]]; then
  install -m 644 \
    "$ROOT/configs/arch-hypr-neobrutalist/radio-stations.tsv.example" \
    "$HOME/.config/arch-hypr-neobrutalist/radio-stations.tsv"
  ok "Installed default radio station list"
fi

if [[ -f "$ROOT/configs/hypr/monitors.conf.example" ]] && [[ ! -f "$HOME/.config/hypr/monitors.conf" ]]; then
  install -m 644 \
    "$ROOT/configs/hypr/monitors.conf.example" \
    "$HOME/.config/hypr/monitors.conf"
  ok "Installed default monitor profile"
fi

chmod +x "$HOME/.config/scripts/"* 2>/dev/null || true

if [[ -f "$HOME/.config/bash/bashrc" ]]; then
  if ! grep -Fq '.config/bash/bashrc' "$HOME/.bashrc" 2>/dev/null; then
    {
      printf '\n# Source arch-hypr-neobrutalist bashrc\n'
      printf 'if [ -f "$HOME/.config/bash/bashrc" ]; then source "$HOME/.config/bash/bashrc"; fi\n'
    } >>"$HOME/.bashrc"
    ok "Added ~/.config/bash/bashrc to ~/.bashrc"
  fi
fi

systemctl --user daemon-reload || true
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
systemctl --user enable --now cache-cleanup.timer 2>/dev/null || true
# bashrc points SSH_AUTH_SOCK at this unit's socket
systemctl --user enable --now ssh-agent.service 2>/dev/null || true

if [[ -f "$HOME/.config/arch-hypr-neobrutalist/bluetooth-devices.conf" ]]; then
  systemctl --user enable --now bluetooth-autoconnect.service 2>/dev/null || true
fi

if command -v ya >/dev/null 2>&1; then
  (
    cd "$HOME/.config/yazi"
    ya pkg install
  ) >/dev/null 2>&1 || true
  ok "Yazi plugins/flavors synced"
fi

if command -v tldr >/dev/null 2>&1; then
  tldr --update >/dev/null 2>&1 &
fi

ok "Configs applied"
