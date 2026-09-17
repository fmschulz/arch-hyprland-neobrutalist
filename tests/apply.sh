#!/usr/bin/env bash
# Verify repeat config sync in an isolated home and user-service namespace.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d /tmp/arch-hypr-apply.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
fixture="$test_root/repo"
mock_dir="$test_root/mock-bin"
mkdir -p "$fixture" "$mock_dir"
cp -a \
  "$repo/scripts" \
  "$repo/configs" \
  "$repo/migrations" \
  "$repo/packages" \
  "$repo/wallpapers" \
  "$fixture/"

# These simulate developer-only AGS outputs that must never reach ~/.config.
mkdir -p \
  "$fixture/configs/ags/node_modules" \
  "$fixture/configs/ags/.types" \
  "$fixture/configs/ags/dist"
touch \
  "$fixture/configs/ags/node_modules/private.js" \
  "$fixture/configs/ags/.types/generated.d.ts" \
  "$fixture/configs/ags/dist/bundle.js"

cat >"$mock_dir/quiet-success" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
cat >"$mock_dir/pgrep" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
cat >"$mock_dir/pkill" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected pkill\n' >&2
exit 90
MOCK
cat >"$mock_dir/sudo" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HOME/sudo-actions"
exit 0
MOCK
chmod +x "$mock_dir"/*
for command in hyprctl makoctl notify-send systemctl tldr uv ya; do
  ln -s quiet-success "$mock_dir/$command"
done

bwrap --unshare-all --die-with-parent --ro-bind / / --dev /dev --proc /proc \
  --tmpfs /tmp --tmpfs /run --tmpfs "$HOME" \
  --dir /tmp/repo --ro-bind "$fixture" /tmp/repo \
  --dir /run/mock-bin --ro-bind "$mock_dir" /run/mock-bin \
  --setenv PATH /run/mock-bin:/usr/bin \
  bash -s <<'FIXTURE'
set -euo pipefail
mkdir -p "$HOME/.config/hypr" "$HOME/.config/waybar"
printf 'local legacy monitor profile\n' >"$HOME/.config/hypr/monitors.conf"
ln -s ../arch-hypr-neobrutalist/themes/blue/waybar.css \
  "$HOME/.config/waybar/theme.css"

bash /tmp/repo/scripts/apply.sh >/dev/null
[[ ! -e "$HOME/.config/hypr/monitors.lua" ]]
[[ ! -e "$HOME/.config/hypr/hyprland.lua" ]]
grep -Fxq 'local legacy monitor profile' "$HOME/.config/hypr/monitors.conf"
[[ $(readlink "$HOME/.config/hypr/theme.lua") == */themes/blue/hyprland.lua ]]
[[ ! -e "$HOME/.config/ags/.gitignore" ]]
[[ ! -e "$HOME/.config/ags/.types" ]]
[[ ! -e "$HOME/.config/ags/dist" ]]
[[ ! -e "$HOME/.config/ags/node_modules" ]]
printf 'Upgrade with legacy monitor rules keeps the legacy Hyprland entrypoint: PASS\n'

printf 'local Lua monitor profile\n' >"$HOME/.config/hypr/monitors.lua"
bash /tmp/repo/scripts/apply.sh >/dev/null
grep -Fxq 'local Lua monitor profile' "$HOME/.config/hypr/monitors.lua"
test -f "$HOME/.config/hypr/hyprland.lua"
printf 'updated legacy monitor profile\n' >"$HOME/.config/hypr/monitors.conf"
bash /tmp/repo/scripts/apply.sh >/dev/null
grep -Fxq 'local Lua monitor profile' "$HOME/.config/hypr/monitors.lua"
grep -Fxq 'updated legacy monitor profile' "$HOME/.config/hypr/monitors.conf"
[[ $(readlink "$HOME/.config/hypr/theme.lua") == */themes/blue/hyprland.lua ]]
printf 'Repeat apply preserves monitor profiles and selected palette; AGS artifacts excluded: PASS\n'

runtime="$HOME/.local/share/arch-hypr-neobrutalist/ags"
mkdir -p "$runtime/prefix/bin" "$runtime/prefix/share/ags/js"
cat >"$runtime/prefix/bin/ags" <<'AGS'
#!/usr/bin/env bash
exit 0
AGS
chmod +x "$runtime/prefix/bin/ags"
cat >"$runtime/env.sh" <<ENV
export AGS_RUNTIME_ROOT="$runtime"
export AGS_PREFIX="\$AGS_RUNTIME_ROOT/prefix"
export AGS_JS_PACKAGE="\$AGS_PREFIX/share/ags/js"
export PATH="\$AGS_PREFIX/bin:\$PATH"
ENV
printf 'AGS 3.1.2 installation in progress\n' >"$runtime/.complete"

for run in first second; do
  output=$(bash /tmp/repo/scripts/install.sh --skip-aur --skip-system)
  grep -q 'Ensuring pinned AGS runtime' <<<"$output"
  grep -q 'AGS runtime is already installed' <<<"$output"
  grep -Fxq 'local Lua monitor profile' "$HOME/.config/hypr/monitors.lua"
  printf 'Isolated %s install reuses the complete pinned runtime: PASS\n' "$run"
done
FIXTURE
