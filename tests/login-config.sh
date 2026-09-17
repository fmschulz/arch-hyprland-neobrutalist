#!/usr/bin/env bash
# Exercise fw12's parser and root repair without access to the running session.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
hypr="$repo/configs/hypr"
test_root=$(mktemp -d /tmp/arch-hypr-login.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
legacy_probe="$test_root/hyprland.conf"
printf 'this is deliberately invalid legacy syntax = [\n' >"$legacy_probe"
sandbox=(bwrap --unshare-all --die-with-parent --ro-bind / / --dev /dev
  --proc /proc --tmpfs /tmp --tmpfs /run --dir /run/user/1000
  --setenv XDG_RUNTIME_DIR /run/user/1000
  --unsetenv WAYLAND_DISPLAY --unsetenv DISPLAY
  --unsetenv DBUS_SESSION_BUS_ADDRESS --unsetenv HYPRLAND_INSTANCE_SIGNATURE)

for palette in yellow blue purple green orange black darkgrey white; do
  result=$("${sandbox[@]}" --tmpfs "$hypr" \
    --ro-bind "$hypr/conf.d" "$hypr/conf.d" \
    --ro-bind "$hypr/hyprland.lua" "$hypr/hyprland.lua" \
    --ro-bind "$hypr/monitors.lua.example" "$hypr/monitors.lua" \
    --ro-bind "$repo/configs/arch-hypr-neobrutalist/themes/$palette/hyprland.lua" "$hypr/theme.lua" \
    Hyprland --verify-config -c "$hypr/hyprland.lua" 2>&1) || {
    printf '%s\n' "$result" >&2
    exit 1
  }
  [[ $result == *'config ok'* ]]
  printf '%s: native Hyprland Lua parser PASS\n' "$palette"
done

result=$("${sandbox[@]}" --setenv XDG_CONFIG_HOME "$repo/configs" \
  --tmpfs "$hypr" \
  --ro-bind "$hypr/conf.d" "$hypr/conf.d" \
  --ro-bind "$legacy_probe" "$hypr/hyprland.conf" \
  --ro-bind "$hypr/hyprland.lua" "$hypr/hyprland.lua" \
  --ro-bind "$hypr/monitors.lua.example" "$hypr/monitors.lua" \
  --ro-bind "$repo/configs/arch-hypr-neobrutalist/themes/yellow/hyprland.lua" "$hypr/theme.lua" \
  Hyprland --verify-config 2>&1) || {
  printf '%s\n' "$result" >&2
  exit 1
}
[[ $result == *'config ok'* ]]
printf 'Hyprland 0.56.2 default config selection uses the Lua entry: PASS\n'

env -u XDG_RUNTIME_DIR bash "$repo/configs/greetd/launch-regreet.sh"
XDG_RUNTIME_DIR=/does-not-exist bash "$repo/configs/greetd/launch-regreet.sh"
XDG_RUNTIME_DIR=/root bash "$repo/configs/greetd/launch-regreet.sh"
printf 'Greeter refuses absent and wrong-owner runtime directories: PASS\n'

"${sandbox[@]}" --uid 0 --gid 0 \
  --tmpfs /etc/greetd --tmpfs /usr/local bash -s -- "$repo" <<'FIXTURE'
set -euo pipefail
repo=$1
cat >/etc/greetd/config.toml <<'CONFIG'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/cage -s -- /usr/bin/regreet"
user = "greeter"

[default_session.env]
HOME = "/var/lib/greetd"
CONFIG
bash "$repo/scripts/system/configure-regreet.sh" --repair-shutdown
cmp "$repo/configs/greetd/launch-regreet.sh" /usr/local/libexec/arch-hypr-neobrutalist/launch-regreet.sh
test "$(stat -c %a /usr/local/libexec/arch-hypr-neobrutalist/launch-regreet.sh)" = 755
rg -q '^command = "/usr/local/libexec/arch-hypr-neobrutalist/launch-regreet.sh"$' /etc/greetd/config.toml
rg -q '^user = "greeter"$' /etc/greetd/config.toml
! rg -q '^\[default_session.env\]' /etc/greetd/config.toml
first=$(sha256sum /etc/greetd/config.toml)
backups=$(find /etc/greetd -name '*.pre-shutdown-repair.*' | wc -l)
bash "$repo/scripts/system/configure-regreet.sh" --repair-shutdown
test "$first" = "$(sha256sum /etc/greetd/config.toml)"
test "$backups" = "$(find /etc/greetd -name '*.pre-shutdown-repair.*' | wc -l)"
printf 'Isolated greeter installation and repeat-run idempotence: PASS\n'
FIXTURE

mock_dir="$test_root/mock-bin"
mkdir -p "$mock_dir"
cat >"$mock_dir/id" <<'MOCK'
#!/usr/bin/env bash
if [[ ${1:-} == -nG ]]; then
  printf 'users seat input video\n'
else
  exec /usr/bin/id "$@"
fi
MOCK
cat >"$mock_dir/usermod" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected usermod: %s\n' "$*" >&2
exit 90
MOCK
cat >"$mock_dir/install" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
directory=false
options=()
while (( $# )); do
  case "$1" in
    -d)
      directory=true
      shift
      ;;
    -m)
      options+=("$1" "$2")
      shift 2
      ;;
    -o|-g)
      shift 2
      ;;
    *)
      break
      ;;
  esac
done
if "$directory"; then
  exec /usr/bin/install -d "${options[@]}" "$@"
fi
exec /usr/bin/install "${options[@]}" "$@"
MOCK
cat >"$mock_dir/dbus-run-session" <<'MOCK'
#!/usr/bin/env bash
printf 'mock compositor output\n'
MOCK
cat >"$mock_dir/systemd-cat" <<'MOCK'
#!/usr/bin/env bash
cat >/dev/null
MOCK
cat >"$mock_dir/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HOME/systemctl-actions"
MOCK
chmod +x "$mock_dir"/*

"${sandbox[@]}" --uid 0 --gid 0 \
  --tmpfs /etc/greetd --tmpfs /usr/local \
  --tmpfs "$HOME" \
  --tmpfs /var/lib/greetd --tmpfs /usr/share/wayland-sessions \
  --dir /tmp/repo --ro-bind "$repo" /tmp/repo \
  --dir /run/mock-bin --ro-bind "$mock_dir" /run/mock-bin \
  --ro-bind "$mock_dir/dbus-run-session" /usr/bin/dbus-run-session \
  --ro-bind "$mock_dir/systemd-cat" /usr/bin/systemd-cat \
  --setenv PATH /run/mock-bin:/usr/bin \
  bash -s -- /tmp/repo "$USER" <<'FIXTURE'
set -euo pipefail
repo=$1
target_user=$2
bash "$repo/scripts/system/configure-regreet.sh" --user "$target_user"
grep -Fxq 'enable seatd.service greetd.service' "$HOME/systemctl-actions"
grep -Fxq 'set-default graphical.target' "$HOME/systemctl-actions"
! grep -q -- '--now' "$HOME/systemctl-actions"
session=/usr/local/libexec/arch-hypr-neobrutalist/hyprland-session.sh
test -x "$session"
PUBLIC_ENV_SECRET=must-not-be-logged "$session"
rg -q 'mock compositor output' "$HOME/.local/share/hyprland-launch.log"
! rg -q 'must-not-be-logged' "$HOME/.local/share/hyprland-launch.log"
printf 'Generated session wrapper does not disclose environment values: PASS\n'
FIXTURE

if "${sandbox[@]}" --uid 0 --gid 0 \
  --tmpfs /etc/greetd --tmpfs /usr/local \
  --tmpfs /var/lib/greetd --tmpfs /usr/share/wayland-sessions \
  --setenv WAYLAND_DISPLAY wayland-test \
  bash "$repo/scripts/system/configure-regreet.sh" --restart --user "$USER"; then
  printf 'Unexpected greetd restart from an active Wayland session\n' >&2
  exit 1
fi
printf 'Active Wayland session restart refusal before system writes: PASS\n'
