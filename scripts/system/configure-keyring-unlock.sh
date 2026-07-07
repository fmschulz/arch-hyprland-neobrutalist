#!/bin/bash
# Wire gnome-keyring into PAM so the default keyring is created with the login
# password and unlocked automatically at every login — no more keyring prompts
# from Chromium's Secret portal (Chromium 150+ stores its os_crypt key there).
# Run with sudo: sudo bash configure-keyring-unlock.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (sudo)." >&2
  exit 1
fi

PAM_FILE=/etc/pam.d/system-login

if [[ ! -f "$PAM_FILE" ]]; then
  echo "$PAM_FILE not found — not an Arch-style PAM layout?" >&2
  exit 1
fi

if grep -q pam_gnome_keyring "$PAM_FILE"; then
  echo "pam_gnome_keyring already wired in $PAM_FILE — nothing to do."
  exit 0
fi

cp "$PAM_FILE" "${PAM_FILE}.bak-keyring-$(date +%Y%m%d)"
printf '\nauth       optional   pam_gnome_keyring.so\nsession    optional   pam_gnome_keyring.so auto_start\n' >>"$PAM_FILE"

echo "Wired pam_gnome_keyring into $PAM_FILE (backup kept)."
echo "Log out and back in for the keyring to be created and auto-unlocked."
