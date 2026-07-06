# How to configure monitors

Monitor layout is machine-local. It lives in `~/.config/hypr/monitors.conf`, which the installer
creates once from `configs/hypr/monitors.conf.example` and then leaves alone - `make apply` never
overwrites it. Edit that file, not the tracked Hyprland config.

## 1. Find your outputs

```bash
hyprctl monitors all | grep -E 'Monitor|description'
```

This prints each output's name (`eDP-1`, `DP-3`, ...) and its EDID description. Prefer the
description for external displays: it is stable across reconnects, while names can renumber.

## 2. Edit the layout

Open `~/.config/hypr/monitors.conf`. The default is a single auto-detect line:

```ini
monitor = ,preferred,auto,1.0
```

For a laptop with an external display on a dock, key the external display by description with
`monitorv2` blocks and keep the auto-detect line as a catch-all:

```ini
monitorv2 {
    output = desc:Dell Inc. DELL P3421W C7ZQH53
    mode = preferred
    position = 0x0
    scale = 1.0
}

monitorv2 {
    output = desc:BOE NE135A1M-NY1
    mode = 2880x1920@120
    position = auto-right
    scale = 1.5
}

monitor = ,preferred,auto,1.0
```

To pin workspaces to the external display when docked, add:

```ini
workspace = 1, monitor:desc:Dell Inc. DELL P3421W C7ZQH53, default:true
workspace = 2, monitor:desc:Dell Inc. DELL P3421W C7ZQH53
```

## 3. Apply

Press `Super+Alt+R` (or run `~/.config/scripts/reload.sh`). This reloads Hyprland, restarts
Waybar, and re-applies the wallpaper.

## Verify

```bash
hyprctl monitors
```

Each connected output should show the mode, position, and scale you configured.

## Notes

- After plugging or unplugging a display, `Super+Ctrl+M` runs the monitor-connect helper
  (reload + Waybar restart + wallpaper), which fixes a bar or wallpaper stuck on the old layout.
- Closing the laptop lid with an external display attached moves workspaces to the external
  display and disables the panel; opening it restores them. This is automatic
  (`clamshell-mode.sh`). If your internal panel is not `eDP-1`, set
  `INTERNAL_OUTPUT` or `INTERNAL_OUTPUT_DESC` in the environment that starts Hyprland.
