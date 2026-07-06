# Scripts

Helper scripts live in `configs/scripts/` and are installed to `~/.config/scripts/`. Everything
is plain Bash. "Invoked by" is the normal trigger; every script can also be run by hand.

## Desktop actions

| Script | Purpose | Invoked by |
| --- | --- | --- |
| `power-menu.sh` | Lock / sleep / reboot / shutdown / logout menu | `Super+M`, Waybar power button |
| `screenshot.sh` | grimblast wrapper: area/output to file and clipboard | `Print` and friends |
| `screenrecord.sh` | Area recording toggle (wf-recorder), saves to `~/Documents/screenrecordings` | `Super+Shift+R`, `Super+Alt+Print` |
| `wallpaper-cycle.sh` | next/prev/random/apply wallpaper via awww (swww fallback) | `Super+W` variants, startup |
| `theme-set.sh` | Atomic theme switch: retargets theme symlinks, reloads Hyprland/Waybar/Mako | `Super+Ctrl+T`, menu |
| `desktop-menu.sh` | Master menu: apps, capture, style, toggles, system | `Super+Alt+Space` |
| `keybindings-popup.sh` | Searchable keybind cheatsheet (wofi, kitty pager fallback) | `Super+/`, `Super+F1` |
| `workspace-rename.sh` | Rename workspaces, overview menu, Waybar tooltip, state persistence | `Super+A`, `Super+Shift+A`, Waybar |
| `max-fullscreen.sh` | Toggle a window between tiled and monitor-filling floating | manual |
| `clear-notifications.sh` | Dismiss all Mako notifications | `Super+Ctrl+N` |
| `calendar-open.sh` / `calendar-tui.sh` | Month/year calendar in a floating Kitty popup | clock click |
| `wifi-menu.sh` | Wi-Fi network picker with wofi password prompt | network module click |
| `usb-menu.sh` | Mount/unmount/eject menu for USB drives (udisksctl) | USB module click |
| `volume-control.sh` | Volume up/down/mute on the active sink, with OSD | volume keys |

## Waybar feeds

| Script | Purpose | Interval |
| --- | --- | --- |
| `clock-waybar.sh` | Clock text + month calendar tooltip | 30 s |
| `system-stats-waybar.sh` | CPU/RAM/temp/disk with warning states | 10 s |
| `updates-waybar.sh` | Pending pacman update count | 1 h + signal 9 |
| `usb-monitor.sh` | Connected USB storage indicator | 5 s |
| `workspace-rename.sh waybar` | Workspace overview tooltip | 5 s + signal 8 |

## Session plumbing

| Script | Purpose | Invoked by |
| --- | --- | --- |
| `clamshell-mode.sh` | Lid open/close handling for docked laptops | lid switch binds + watch loop |
| `monitor-connect.sh` | Reload + Waybar restart + wallpaper after display changes | `Super+Ctrl+M` |
| `reload.sh` | Reload Hyprland and restart Waybar | `Super+Alt+R` |
| `waybar-restart.sh` | Serialized, race-free Waybar restart | other scripts |
| `bluetooth-autoconnect.sh` | Reconnect trusted devices, promote audio sinks | user service |
| `idle-lock.sh` | Idle lock that skips while an external monitor is attached | hypridle (5 min) |
| `auto-power-profile.sh` | Performance on AC, power-saver on battery | udev rule |
| `welcome.sh` | Terminal banner: fastfetch + cached weather | every new shell |

## Maintenance

| Script | Purpose | Invoked by |
| --- | --- | --- |
| `cache-cleanup.sh` | Clear browser/Electron/thumbnail caches | weekly user timer, `cleanup` |
| `system-health.sh` | Failed services, disk, journal, orphans, updates report | `health` |
| `package-snapshot.sh` | Drift report: installed packages vs manifests | manual, from the checkout |
