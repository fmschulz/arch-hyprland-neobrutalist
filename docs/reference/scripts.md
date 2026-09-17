# Scripts

Desktop helpers are installed from `configs/scripts/` into `~/.config/scripts/`.

## Desktop controls

| Script | Purpose | Normal trigger |
| --- | --- | --- |
| `ags-shell.sh` | Start, stop, inspect, or toggle the AGS bar and panels | Login, bar helpers |
| `power-menu.sh` | Lock, sleep, reboot, shutdown, and logout menu | `Super+Alt+P` |
| `screenshot.sh` | Capture an area or output to a file or clipboard | Print shortcuts |
| `screenrecord.sh` | Toggle an area recording | `Super+Shift+R`, `Shift+Print` |
| `wallpaper-cycle.sh` | Select and verify wallpapers through hyprpaper | Wallpaper shortcuts, appearance panel |
| `theme-set.sh` | Select palette fragments and refresh applications | `Super+Ctrl+T`, appearance panel |
| `keybindings-popup.sh` | Search the shortcut reference | `Super+/` |
| `workspace-overview.sh` | Show workspaces and their windows | `Super+Shift+Up` |
| `workspace-notes.sh` | Manage local workspace notes | `Super+Shift+Space` |
| `open-calendar.sh` | Open the calendar application | Clock |
| `wifi-menu.sh` | Open network controls | `Super+Ctrl+I` |
| `wifi-portal.sh` | Handle captive portal access | Network controls, portal shortcut |
| `volume-control.sh` | Change volume or mute | Media keys |
| `clear-notifications.sh` | Dismiss notifications | `Super+Ctrl+N` |

## Session helpers

| Script | Purpose |
| --- | --- |
| `secure-lock.sh` | Clear clipboard state and run hyprlock |
| `clear-sensitive-state.sh` | Clear clipboard selections and history |
| `idle-suspend.sh` | Suspend after idle on battery; recheck while on AC |
| `display-profile.sh` | Preview, confirm, or restore display layouts |
| `clamshell-mode.sh` | Handle laptop lid changes with external displays |
| `monitor-hotplug.sh` | React to connected display changes |
| `monitor-connect.sh` | Refresh desktop display integration |
| `reload.sh` | Reload the desktop configuration |
| `waybar-restart.sh` | Manage the Waybar fallback without replacing an active AGS bar |
| `bluetooth-autoconnect.sh` | Connect devices listed in local preferences |
| `auto-power-profile.sh` | Select power profiles for AC and battery |

`system-stats-waybar.sh` and `updates-waybar.sh` supply status information to the
bar. Existing command-line helpers for calendars, USB devices, package snapshots,
and system health remain available in the same directory.

## AGS commands

Run these inside the desktop session:

```bash
~/.config/scripts/ags-shell.sh status
~/.config/scripts/ags-shell.sh toggle network
~/.config/scripts/ags-shell.sh toggle sound
~/.config/scripts/ags-shell.sh toggle desktop
~/.config/scripts/ags-shell.sh toggle appearance
~/.config/scripts/ags-shell.sh toggle notifications
~/.config/scripts/ags-shell.sh toggle system
```

`status` prints `running`, `starting`, or `stopped`. `stop` restores the supervised
Waybar fallback; `login` starts with the fallback visible until AGS is ready.
