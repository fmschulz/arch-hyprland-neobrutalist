#!/bin/bash
# Let the fingerprint reader satisfy sudo and polkit prompts (password stays
# as fallback). Deliberately does NOT touch login (system-login/greetd): the
# keyring needs the typed password at login to auto-unlock — fingerprint there
# would bring the keyring prompts right back.
# Run with sudo: sudo bash configure-fingerprint.sh
# Then enroll as your user (no sudo): fprintd-enroll

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (sudo)." >&2
  exit 1
fi

if [[ ! -e /usr/lib/security/pam_fprintd.so ]]; then
  echo "pam_fprintd.so not found — install fprintd first." >&2
  exit 1
fi

wire() {
  local pam_file="$1"
  if [[ ! -f "$pam_file" ]]; then
    echo "skip: $pam_file does not exist"
    return 0
  fi
  if grep -q pam_fprintd "$pam_file"; then
    echo "ok:   $pam_file already wired"
    return 0
  fi
  cp "$pam_file" "${pam_file}.bak-fprintd-$(date +%Y%m%d)"
  # First auth line: try the finger, fall through to password on failure.
  sed -i '0,/^auth/s//auth       sufficient pam_fprintd.so\nauth/' "$pam_file"
  echo "wired: $pam_file (backup kept)"
}

wire /etc/pam.d/sudo
wire /etc/pam.d/polkit-1

echo
echo "Done. Now enroll a finger as your normal user:  fprintd-enroll"
echo "hyprlock picks up fingerprint auth from its own config (auth { fingerprint })."
