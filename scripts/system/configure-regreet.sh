#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script with sudo (root)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TARGET_USER=${1:-${SUDO_USER:-$(logname)}}
GREETER_USER="greeter"
RUNTIME_UID="$(id -u "$GREETER_USER")"

step() {
  printf '▶ %s\n' "$1"
}

step "Ensuring greetd/regreet dependencies are installed"
pacman -S --needed --noconfirm greetd greetd-regreet seatd cage

step "Stopping greetd"
systemctl stop greetd.service 2>/dev/null || true
systemctl disable greetd.service 2>/dev/null || true

step "Preparing greeter runtime directories"
install -d -m 755 -o "$GREETER_USER" -g "$GREETER_USER" /var/lib/greetd
for rel in .cache .config .local/share; do
  install -d -m 700 -o "$GREETER_USER" -g "$GREETER_USER" "/var/lib/greetd/$rel"
done
install -d -m 700 -o "$GREETER_USER" -g "$GREETER_USER" "/run/user/$RUNTIME_UID"

step "Writing /etc/greetd/config.toml"
install -d -m 755 /etc/greetd
# Unquoted heredoc so XDG_RUNTIME_DIR follows the actual greeter uid instead
# of a hardcoded /run/user/950.
cat >/etc/greetd/config.toml <<GREETD_CFG
[terminal]
vt = 1
switch = true

[default_session]
command = "/usr/bin/cage -s -- /usr/bin/regreet --config /etc/greetd/regreet.toml --style /etc/greetd/regreet.css"
user = "greeter"

[default_session.env]
HOME = "/var/lib/greetd"
XDG_CACHE_HOME = "/var/lib/greetd/.cache"
XDG_CONFIG_HOME = "/var/lib/greetd/.config"
XDG_DATA_HOME = "/var/lib/greetd/.local/share"
XDG_RUNTIME_DIR = "/run/user/${RUNTIME_UID}"
WAYLAND_DISPLAY = "wayland-0"
GREETD_CFG

step "Writing /etc/greetd/regreet.toml"
cat >/etc/greetd/regreet.toml <<REGREET_TOML
[session]
command = "Hyprland"
user = "$TARGET_USER"

[commands]
reboot = [ "systemctl", "reboot" ]
poweroff = [ "systemctl", "poweroff" ]
REGREET_TOML

step "Deploying regreet stylesheet"
if [[ -f "$REPO_ROOT/configs/greetd/regreet.css" ]]; then
  install -m 644 "$REPO_ROOT/configs/greetd/regreet.css" /etc/greetd/regreet.css
fi

step "Wiring gnome-keyring auto-unlock into greetd PAM"
if [[ -f /usr/lib/security/pam_gnome_keyring.so ]] && ! grep -q pam_gnome_keyring /etc/pam.d/greetd 2>/dev/null; then
  cat >>/etc/pam.d/greetd <<'PAM'

# Unlock the GNOME keyring with the login password (Chromium secret storage)
auth       optional     pam_gnome_keyring.so
session    optional     pam_gnome_keyring.so auto_start
PAM
fi

step "Ensuring seat group membership"
if ! id -nG "$TARGET_USER" | grep -qw seat; then
  usermod -aG seat "$TARGET_USER"
fi
if ! id -nG "$GREETER_USER" | grep -qw seat; then
  usermod -aG seat "$GREETER_USER"
fi

step "Re-enabling seatd and greetd"
systemctl enable --now seatd.service
systemctl reset-failed greetd.service || true
systemctl enable --now greetd.service

step "Setting graphical.target as default"
systemctl set-default graphical.target

printf '\nRegreet configured. Reboot with sudo reboot when ready.\n'
