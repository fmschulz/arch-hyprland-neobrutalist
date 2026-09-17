#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d /tmp/arch-hypr-idle-suspend.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
mock_dir="$test_root/bin"
actions="$test_root/systemctl-actions"
mkdir -p "$mock_dir"

cat >"$mock_dir/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$IDLE_SUSPEND_ACTIONS"
MOCK
chmod +x "$mock_dir/systemctl"
export IDLE_SUSPEND_ACTIONS="$actions"

empty="$test_root/empty"
mkdir -p "$empty"
POWER_SUPPLY_DIR="$empty" PATH="$mock_dir:$PATH" \
  bash "$repo/configs/scripts/idle-suspend.sh"
[[ ! -e "$actions" ]]
printf 'PASS no battery does not suspend\n'

system_battery="$test_root/system-battery"
mkdir -p "$system_battery/BAT0"
printf 'Battery\n' >"$system_battery/BAT0/type"
printf 'System\n' >"$system_battery/BAT0/scope"
POWER_SUPPLY_DIR="$system_battery" PATH="$mock_dir:$PATH" \
  bash "$repo/configs/scripts/idle-suspend.sh"
grep -Fxq suspend "$actions"
printf 'PASS system battery without AC suspends\n'

rm -f "$actions"
peripheral="$test_root/peripheral"
mkdir -p "$peripheral/hidpp_battery_0"
printf 'Battery\n' >"$peripheral/hidpp_battery_0/type"
printf 'Device\n' >"$peripheral/hidpp_battery_0/scope"
POWER_SUPPLY_DIR="$peripheral" PATH="$mock_dir:$PATH" \
  bash "$repo/configs/scripts/idle-suspend.sh"
[[ ! -e "$actions" ]]
printf 'PASS peripheral battery alone does not suspend\n'
