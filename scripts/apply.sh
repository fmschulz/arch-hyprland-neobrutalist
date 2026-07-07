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
SYNC_DIRS=(bash btop hypr kitty mako nvim scripts waybar wofi xdg-desktop-portal yazi)

# On machines deployed via ~/controlcenter these ~/.config paths are symlinks
# into that repo; rsync would write straight through them and overwrite its
# working tree (machine-specific customizations included). Refuse and point at
# the owning deployer instead. ARCH_APPLY_OVERRIDE=1 bypasses the guard.
if [[ -z "${ARCH_APPLY_OVERRIDE:-}" ]]; then
  for name in "${SYNC_DIRS[@]}"; do
    t="$HOME/.config/$name"
    if [[ -L "$t" && "$(readlink -f "$t" 2>/dev/null)" == "$HOME/controlcenter/"* ]]; then
      printf '✗ ~/.config/%s is managed by ~/controlcenter (symlink) — refusing to sync over it.\n' "$name" >&2
      printf '  Deploy with ~/controlcenter/apply.sh instead, or rerun with ARCH_APPLY_OVERRIDE=1.\n' >&2
      exit 1
    fi
  done
fi

for name in "${SYNC_DIRS[@]}"; do
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

# Music TUI (Super+Shift+R): installed once as a uv tool; upgrade with
# `uv tool upgrade bester-ytm`.
if command -v uv >/dev/null 2>&1; then
  if [[ ! -x "$HOME/.local/bin/bester-ytm" ]] && ! command -v bester-ytm >/dev/null 2>&1; then
    uv tool install --quiet "git+https://github.com/fmschulz/bester-ytm" 2>/dev/null \
      && ok "Installed bester-ytm (YouTube Music TUI)" \
      || printf '! bester-ytm install failed (network?); rerun make apply\n'
  fi
fi

if [[ -f "$ROOT/configs/hypr/monitors.conf.example" ]] && [[ ! -f "$HOME/.config/hypr/monitors.conf" ]]; then
  install -m 644 \
    "$ROOT/configs/hypr/monitors.conf.example" \
    "$HOME/.config/hypr/monitors.conf"
  ok "Installed default monitor profile"
fi

chmod +x "$HOME/.config/scripts/"* 2>/dev/null || true

# One-shot migrations: each runs once per machine (state survives applies),
# converging existing installs where rsync cannot (deletes, system cleanup).
MIGRATIONS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/arch-hypr-neobrutalist/migrations-applied"
mkdir -p "$(dirname "$MIGRATIONS_STATE")"
touch "$MIGRATIONS_STATE"
for migration in "$ROOT"/migrations/*.sh; do
  [[ -e "$migration" ]] || continue
  name=$(basename "$migration")
  grep -Fxq "$name" "$MIGRATIONS_STATE" && continue
  if bash "$migration"; then
    echo "$name" >>"$MIGRATIONS_STATE"
    ok "Migration applied: $name"
  else
    printf '! Migration %s failed; it will retry on the next apply\n' "$name"
  fi
done

# Default theme: create the per-app theme symlinks once; theme-set.sh
# switches them afterwards (Super+Ctrl+T cycles).
if [[ ! -e "$HOME/.config/waybar/theme.css" ]]; then
  "$HOME/.config/scripts/theme-set.sh" yellow
  ok "Default theme set (yellow)"
fi

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
