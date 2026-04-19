#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_ONLY=false
CONFIGS_ONLY=false
SKIP_AUR=false
SKIP_SYSTEM=false
WITH_GREETD="${WITH_GREETD:-0}"

log() {
  printf '▶ %s\n' "$*"
}

ok() {
  printf '✓ %s\n' "$*"
}

die() {
  printf '✖ %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [options]

Options:
  --packages-only  Install pacman/AUR packages only
  --configs-only   Apply configs only
  --skip-aur       Skip AUR package installation
  --skip-system    Skip root-level system tuning scripts
  --with-greetd    Also configure greetd/regreet
EOF
}

install_pacman_file() {
  local file="$1"
  local -a pkgs=()
  mapfile -t pkgs < <(sed -E 's/[[:space:]]+#.*$//' "$file" | sed '/^[[:space:]]*$/d')
  (( ${#pkgs[@]} )) || return 0
  log "Installing pacman packages from $(basename "$file")"
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

install_aur_file() {
  local file="$1"
  local -a pkgs=()
  mapfile -t pkgs < <(sed -E 's/[[:space:]]+#.*$//' "$file" | sed '/^[[:space:]]*$/d')
  (( ${#pkgs[@]} )) || return 0
  log "Installing AUR packages from $(basename "$file")"
  paru -S --needed --noconfirm "${pkgs[@]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --packages-only)
      PACKAGES_ONLY=true
      ;;
    --configs-only)
      CONFIGS_ONLY=true
      ;;
    --skip-aur)
      SKIP_AUR=true
      ;;
    --skip-system)
      SKIP_SYSTEM=true
      ;;
    --with-greetd)
      WITH_GREETD=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

if $PACKAGES_ONLY && $CONFIGS_ONLY; then
  die "--packages-only and --configs-only are mutually exclusive"
fi

[[ -f /etc/arch-release ]] || die "This installer is intended for Arch Linux"

if ! $CONFIGS_ONLY; then
  log "Installing bootstrap dependencies"
  sudo pacman -S --needed --noconfirm base-devel git rsync

  install_pacman_file "$ROOT/packages/pacman.txt"

  if command -v lspci >/dev/null 2>&1 && lspci | grep -Eiq '(AMD|Radeon)'; then
    install_pacman_file "$ROOT/packages/pacman-amd.txt"
  fi

  if ! $SKIP_AUR; then
    "$ROOT/scripts/bootstrap-aur.sh"
    install_aur_file "$ROOT/packages/aur.txt"
  fi

  log "Enabling base services"
  sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
  sudo systemctl enable --now bluetooth.service 2>/dev/null || true
fi

if ! $PACKAGES_ONLY; then
  "$ROOT/scripts/apply.sh"
fi

if ! $PACKAGES_ONLY && ! $SKIP_SYSTEM; then
  log "Applying system-level tuning"
  sudo "$ROOT/scripts/system/configure-system-performance.sh" "${USER}"
  sudo "$ROOT/scripts/system/configure-usb-automount.sh" "${USER}"
  if [[ "$WITH_GREETD" == "1" ]]; then
    sudo "$ROOT/scripts/system/configure-regreet.sh" "${USER}"
  fi
fi

ok "Install flow completed"
