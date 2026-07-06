#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '▶ %s\n' "$*"
}

# -V instead of command -v: a paru binary built against an older libalpm
# soname exists on PATH but cannot run.
if paru -V >/dev/null 2>&1; then
  exit 0
fi

log "Installing AUR bootstrap dependencies"
sudo pacman -S --needed --noconfirm base-devel git

# A previously installed paru-bin that can no longer run (libalpm soname bump)
# blocks the source package install through file conflicts; clear it first.
for leftover in paru-bin-debug paru-bin; do
  if pacman -Qq "$leftover" >/dev/null 2>&1; then
    log "Removing non-functional $leftover"
    sudo pacman -R --noconfirm "$leftover" || true
  fi
done

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Source build: paru-bin releases lag behind pacman's libalpm soname bumps
# and then fail to load; compiling links against the installed libalpm.
log "Bootstrapping paru from AUR (source build)"
git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
(
  cd "$tmpdir/paru"
  makepkg -si --noconfirm
)

paru -V >/dev/null
log "paru is now available"
