#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  printf '▶ %s\n' "$*"
}

if command -v paru >/dev/null 2>&1; then
  exit 0
fi

log "Installing AUR bootstrap dependencies"
sudo pacman -S --needed --noconfirm base-devel git

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

log "Bootstrapping paru-bin from AUR"
git clone https://aur.archlinux.org/paru-bin.git "$tmpdir/paru-bin"
(
  cd "$tmpdir/paru-bin"
  makepkg -si --noconfirm
)

log "paru is now available"
