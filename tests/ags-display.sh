#!/usr/bin/env bash
set -euo pipefail

# Exercise the guard with a deterministic compositor boundary. Nested outputs
# on fw12 acknowledge disable but remain enabled, so cannot prove these paths.
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
helper="$REPO/configs/scripts/display-profile.sh"
export INTERNAL_OUTPUT=AGS-TEST
test_dir=$(mktemp -d /tmp/ags-display-test.XXXXXX)
export AGS_DISPLAY_TEST_DIR="$test_dir"
export XDG_RUNTIME_DIR="$test_dir/runtime" HYPRLAND_INSTANCE_SIGNATURE=ags-fixture
mkdir -p "$XDG_RUNTIME_DIR" "$test_dir/bin"
export PATH="$test_dir/bin:$PATH"
export LID_STATE_PATH="$test_dir/lid"
printf 'state: open\n' >"$LID_STATE_PATH"

cat >"$test_dir/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
file="$AGS_DISPLAY_TEST_DIR/monitors.json"
if [[ $1 == -j ]]; then
  case $2 in
    monitors)
      if [[ ${3:-} == all ]]; then jq . "$file"; else jq '[.[] | select(.disabled == false)]' "$file"; fi ;;
    workspaces) printf '[{"id":1,"monitor":"AGS-TEST"},{"id":2,"monitor":"WAYLAND-1"}]\n' ;;
  esac
elif [[ $1 == keyword ]]; then
  printf '%s\n' "$3" >>"$AGS_DISPLAY_TEST_DIR/monitor-actions"
  IFS=, read -ra fields <<<"$3"
  name=${fields[0]} mode=${fields[1]} mirror=none
  for ((i=4; i<${#fields[@]}; i++)); do
    if [[ ${fields[$i]} == mirror ]]; then mirror=${fields[$((i+1))]}; fi
  done
  if [[ ${AGS_DISPLAY_IGNORE:-} != 1 && ! -f "$AGS_DISPLAY_TEST_DIR/ignore-restore" ]]; then
    jq --arg name "$name" --arg mode "$mode" --arg mirror "${mirror:-none}" \
      'map(if .name == $name then .disabled=($mode == "disable") | .mirrorOf=$mirror else . end)' "$file" >"$file.new"
    mv "$file.new" "$file"
  fi
  printf 'ok\n'
elif [[ $1 == reload ]]; then
  printf 'reload\n' >>"$AGS_DISPLAY_TEST_DIR/monitor-actions"
  printf 'ok\n'
elif [[ $1 == dispatch ]]; then
  printf 'ok\n'
fi
MOCK
cat >"$test_dir/bin/systemd-run" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
while [[ $1 == --* ]]; do shift; done
setsid "$@" </dev/null >"$AGS_DISPLAY_TEST_DIR/guard.log" 2>&1 &
MOCK
chmod +x "$test_dir/bin/hyprctl" "$test_dir/bin/systemd-run"
cat >"$test_dir/bin/loginctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$AGS_DISPLAY_TEST_DIR/lock-actions"
MOCK
chmod +x "$test_dir/bin/loginctl"

phase() { "$helper" status | jq -r .phase; }
await_phase() {
  local expected=$1
  for ((attempt=0; attempt<100; attempt++)); do
    [[ $(phase) != "$expected" ]] || return 0
    sleep 0.1
  done
  "$helper" status >&2
  return 1
}
reset_layout() {
  "$helper" revert
  printf '%s\n' '[{"name":"AGS-TEST","width":1280,"height":800,"refreshRate":60,"x":0,"y":0,"scale":1,"transform":0,"disabled":false,"mirrorOf":"none"},{"name":"WAYLAND-1","width":3440,"height":1440,"refreshRate":85,"x":1280,"y":0,"scale":1,"transform":0,"disabled":false,"mirrorOf":"none"}]' >"$test_dir/monitors.json"
}
result=0
cleanup() {
  "$helper" revert || true
  if [[ $result != 0 ]]; then tail -15 "$test_dir/guard.log" >&2; fi
  rm -rf -- "$test_dir"
}
trap 'result=$?; cleanup' EXIT
reset_layout

: >"$test_dir/monitor-actions"
bash "$REPO/configs/scripts/clamshell-mode.sh" open >/dev/null
rg -Fx reload "$test_dir/monitor-actions" >/dev/null
if rg -q '^AGS-TEST,' "$test_dir/monitor-actions"; then
  exit 1
fi
printf 'PASS default lid-open path reloads the local monitor config\n'

: >"$test_dir/monitor-actions"
INTERNAL_MODE=preferred,auto,1 bash "$REPO/configs/scripts/clamshell-mode.sh" open >/dev/null
rg -Fx 'AGS-TEST,preferred,auto,1' "$test_dir/monitor-actions" >/dev/null
if rg -Fxq reload "$test_dir/monitor-actions"; then
  exit 1
fi
printf 'PASS explicit lid-open mode applies its monitor rule without reload\n'

"$helper" preview external
await_phase preview
hyprctl -j monitors | jq -e 'length == 1 and .[0].name == "WAYLAND-1"' >/dev/null
"$helper" keep
[[ $(phase) == kept ]]
printf 'PASS external profile and explicit confirmation\n'
reset_layout

"$helper" preview laptop
await_phase preview
hyprctl -j monitors | jq -e 'length == 1 and .[0].name == "AGS-TEST"' >/dev/null
"$helper" revert
[[ $(phase) == restored ]]
hyprctl -j monitors | jq -e 'length == 2' >/dev/null
printf 'PASS laptop profile and exact two-output rollback\n'

"$helper" preview mirror
await_phase preview
hyprctl -j monitors all | jq -e 'any(.[]; .name == "WAYLAND-1" and .mirrorOf == "AGS-TEST")' >/dev/null
"$helper" revert
hyprctl -j monitors all | jq -e 'all(.[]; .mirrorOf == "none")' >/dev/null
printf 'PASS mirrored profile and mirror reset\n'

for profile in laptop mirror; do
  reset_layout
  hyprctl keyword monitor AGS-TEST,disable >/dev/null
  : >"$test_dir/monitor-actions"
  "$helper" preview "$profile"
  await_phase preview
  rg -Fx 'AGS-TEST,preferred,auto,1' "$test_dir/monitor-actions" >/dev/null
  "$helper" revert
  printf 'PASS %s re-enables the laptop with the portable preferred rule\n' "$profile"
done
reset_layout
hyprctl keyword monitor WAYLAND-1,disable >/dev/null
: >"$test_dir/monitor-actions"
"$helper" preview external
await_phase preview
rg -Fx 'WAYLAND-1,preferred,auto,1' "$test_dir/monitor-actions" >/dev/null
"$helper" revert
printf 'PASS disabled external keeps preferred mode and 100%% scale\n'
reset_layout

"$helper" preview external
await_phase preview
# The preview command has exited. Its independent guard must restore on expiry.
sleep 16
[[ $(phase) == restored ]]
hyprctl -j monitors | jq -e 'length == 2' >/dev/null
printf 'PASS detached guard timeout restores the layout\n'

"$helper" preview laptop
await_phase preview
printf 'state: closed\n' >"$LID_STATE_PATH"
bash "$REPO/configs/scripts/clamshell-mode.sh" closed >/dev/null
[[ $(phase) == restored ]]
[[ $(<"$test_dir/lock-actions") == lock-session ]]
hyprctl -j monitors | jq -e 'length == 1 and .[0].name == "WAYLAND-1"' >/dev/null
printf 'PASS lid closure cancels preview, locks session, and retains lid-safe layout\n'
reset_layout

printf 'state: closed\n' >"$LID_STATE_PATH"
"$helper" preview laptop
await_phase error
hyprctl -j monitors | jq -e 'length == 2' >/dev/null
printf 'PASS closed-lid laptop preview rejected without a monitor change\n'

printf 'state: open\n' >"$LID_STATE_PATH"
AGS_DISPLAY_IGNORE=1 "$helper" preview external
await_phase error
hyprctl -j monitors | jq -e 'length == 2' >/dev/null
printf 'PASS acknowledged but unapplied profile rejected\n'

"$helper" preview laptop
await_phase preview
touch "$test_dir/ignore-restore"
"$helper" revert
[[ $(phase) == error ]]
rm "$test_dir/ignore-restore"
reset_layout
printf 'PASS acknowledged but unapplied rollback reports failure\n'
