#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  echo "Please run this script with sudo (root)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
LIBEXEC_DIR="/usr/local/libexec/arch-hypr-neobrutalist"
LAUNCHER="$LIBEXEC_DIR/launch-regreet.sh"
SESSION_WRAPPER="$LIBEXEC_DIR/hyprland-session.sh"

repair_shutdown_warning() {
  local config=/etc/greetd/config.toml
  local launcher_source="$REPO_ROOT/configs/greetd/launch-regreet.sh"
  local backup
  local config_tmp

  [[ -f "$config" ]] || {
    echo "Missing $config" >&2
    return 1
  }
  [[ -f "$launcher_source" ]] || {
    echo "Missing $launcher_source" >&2
    return 1
  }

  config_tmp=$(mktemp "${config}.repair.XXXXXX")
  trap 'rm -f "$config_tmp"' RETURN
  awk -v launcher="$LAUNCHER" '
    /^\[[^]]+\]$/ {
      section = $0
      if (section == "[default_session.env]")
        next
    }
    section == "[default_session.env]" { next }
    section == "[default_session]" && /^[[:space:]]*command[[:space:]]*=/ {
      print "command = \"" launcher "\""
      found++
      next
    }
    { print }
    END { if (found != 1) exit 1 }
  ' "$config" >"$config_tmp" || {
    echo "Expected exactly one default_session.command in $config" >&2
    return 1
  }

  if [[ $(grep -Fxc "command = \"$LAUNCHER\"" "$config_tmp") -ne 1 ]] \
    || grep -q '^\[default_session\.env\]$' "$config_tmp"; then
    echo "Refusing to install invalid repaired greetd configuration" >&2
    return 1
  fi

  install -d -m 755 "$LIBEXEC_DIR"
  install -m 755 "$launcher_source" "$LAUNCHER"

  if ! cmp -s "$config" "$config_tmp"; then
    backup=$(mktemp "${config}.pre-shutdown-repair.XXXXXX")
    cp --preserve=mode,ownership,timestamps "$config" "$backup"
    chmod --reference="$config" "$config_tmp"
    chown --reference="$config" "$config_tmp"
    mv "$config_tmp" "$config"
    printf 'Backed up the previous config to %s\n' "$backup"
  fi

  printf 'Installed the greetd shutdown-race repair. It takes effect the next time greetd starts.\n'
}

# This mode does not need a login user and may be invoked through pkexec.
if [[ ${1:-} == --repair-shutdown ]]; then
  if (( $# != 1 )); then
    echo "--repair-shutdown does not accept other arguments" >&2
    exit 2
  fi
  repair_shutdown_warning
  exit
fi

TARGET_USER=${SUDO_USER:-}
RESTART=0
INSTALL=0

in_active_wayland_session() {
  if [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    return 0
  fi
  if command -v loginctl >/dev/null 2>&1 && [[ -n "${XDG_SESSION_ID:-}" ]]; then
    loginctl show-session "$XDG_SESSION_ID" -p Type 2>/dev/null | grep -qi 'Type=wayland' && return 0
  fi
  return 1
}

while (( $# )); do
  case "${1:-}" in
    --restart)
      RESTART=1
      ;;
    --no-restart)
      RESTART=0
      ;;
    --install)
      INSTALL=1
      ;;
    --no-install)
      INSTALL=0
      ;;
    --user)
      shift
      TARGET_USER=${1:-}
      ;;
    --help|-h)
      echo "Usage: sudo $(basename "$0") [--install] [--restart] --user USER | --repair-shutdown" >&2
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -z "$TARGET_USER" || "$TARGET_USER" == root ]]; then
  echo "Pass the regular login account with --user USER." >&2
  exit 2
fi
if ! getent passwd "$TARGET_USER" >/dev/null; then
  echo "Unknown login account: $TARGET_USER" >&2
  exit 2
fi

# A display-manager restart would terminate the caller's active desktop. Check
# before installing packages or writing system files.
if in_active_wayland_session && (( RESTART )); then
  echo "You are in an active Wayland session; refusing to stop/start greetd. Omit --restart and apply from a TTY later." >&2
  exit 2
fi

GREETER_USER="greeter"

step() {
  printf '▶ %s\n' "$1"
}

if (( INSTALL )); then
  step "Ensuring greetd/regreet dependencies are installed"
  pacman -S --needed --noconfirm greetd greetd-regreet seatd cage
else
  step "Skipping package install (use --install to install greetd/regreet/seatd)"
fi

if (( RESTART )); then
  step "Stopping greetd and seatd"
  systemctl disable --now greetd.service || true
  systemctl disable --now seatd.service || true
else
  step "Will not stop services (use --restart to apply immediately)"
fi

step "Preparing greeter runtime directories"
install -d -m 755 -o "$GREETER_USER" -g "$GREETER_USER" /var/lib/greetd
for rel in .cache .config .local/share; do
  install -d -m 700 -o "$GREETER_USER" -g "$GREETER_USER" "/var/lib/greetd/$rel"
done

step "Installing ReGreet launcher"
install -d -m 755 "$LIBEXEC_DIR"
install -m 755 "$REPO_ROOT/configs/greetd/launch-regreet.sh" "$LAUNCHER"

step "Writing /etc/greetd/config.toml"
install -d -m 755 /etc/greetd
cat >/etc/greetd/config.toml <<GREETD_CFG
[terminal]
vt = 1
switch = true

[default_session]
# The launcher skips Cage if shutdown prevents pam_systemd from creating the
# greeter runtime directory.
command = "$LAUNCHER"
user = "greeter"
GREETD_CFG

step "Installing Hyprland session wrapper"
cat >"$SESSION_WRAPPER" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail

LOGFILE="$HOME/.local/share/hyprland-launch.log"
mkdir -p "$(dirname "$LOGFILE")"
printf '=== Hyprland launch %s ===\n' "$(date)" >>"$LOGFILE"

export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Hyprland
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

/usr/bin/dbus-run-session /usr/bin/Hyprland 2>&1 \
  | /usr/bin/tee -a "$LOGFILE" \
  | /usr/bin/systemd-cat -t hyprland-greetd
WRAP
chmod 755 "$SESSION_WRAPPER"

step "Writing Hyprland wayland-session entry"
install -d -m 755 /usr/share/wayland-sessions
cat >/usr/share/wayland-sessions/hyprland.desktop <<DESK
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Wayland session
Exec=$SESSION_WRAPPER
Type=Application
DesktopNames=Hyprland
DESK

step "Writing /etc/greetd/regreet.toml"
cat >/etc/greetd/regreet.toml <<REGREET_TOML
[session]
command = "$SESSION_WRAPPER"
user = "$TARGET_USER"

[env]
XDG_SESSION_TYPE = "wayland"
XDG_CURRENT_DESKTOP = "Hyprland"

[commands]
reboot = [ "systemctl", "reboot" ]
poweroff = [ "systemctl", "poweroff" ]
REGREET_TOML

step "Deploying regreet stylesheet"
install -m 644 "$REPO_ROOT/configs/greetd/regreet.css" /etc/greetd/regreet.css

step "Ensuring seat access"
for group in seat input video; do
  if ! id -nG "$TARGET_USER" | grep -qw "$group"; then
    usermod -aG "$group" "$TARGET_USER"
  fi
  if ! id -nG "$GREETER_USER" | grep -qw "$group"; then
    usermod -aG "$group" "$GREETER_USER"
  fi
done

if (( RESTART )); then
  step "Re-enabling seatd and greetd"
  systemctl enable --now seatd.service
  systemctl reset-failed greetd.service || true
  systemctl enable --now greetd.service
  systemctl set-default graphical.target
  printf '\nRegreet configured and applied. Switch to greeter (VT1).\n'
else
  step "Enabling seatd and greetd for the next boot"
  systemctl enable seatd.service greetd.service
  systemctl set-default graphical.target
  printf '\nRegreet configured. To apply safely from a TTY run:\n'
  printf '  sudo systemctl restart seatd greetd\n\n'
fi
