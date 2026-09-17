# Configure monitors

The Lua desktop reads `~/.config/hypr/monitors.lua`. On a new installation,
`make apply` creates this file from a generic example and preserves subsequent edits.

## 1. Find connector names

Run this inside Hyprland:

```bash
hyprctl monitors all
```

Use connector names such as `eDP-1`, `DP-1`, or `HDMI-A-1` in your local file.
Do not publish monitor descriptions that contain serial numbers.

## 2. Set a layout

Open `~/.config/hypr/monitors.lua`. The default selects each display's preferred
mode and places it automatically:

```lua
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.0 })
```

For a laptop and an external display, replace the connector names and positions
in this example with your own:

```lua
hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.0 })
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto-right", scale = 1.0 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.0 })
```

## 3. Reload and verify

```bash
hyprctl reload
hyprctl monitors
```

Check that the mode, scale, and position match the local file.

The AGS display panel can preview a layout and restore it if it is not confirmed.
Use the local monitor file for the layout you want at login. Closing the laptop
lid while an external display is connected invokes the clamshell helper. Set
`INTERNAL_OUTPUT` in the session environment if automatic eDP/LVDS detection
does not identify your internal display.

## Legacy configuration

Sessions using `hyprland.conf` read `~/.config/hypr/monitors.conf`. An upgrade
keeps this entrypoint active when an existing legacy monitor file has no Lua
counterpart.

To activate Lua, create `~/.config/hypr/monitors.lua` using the examples above
and translate your existing display modes, positions, and scales. Then run
`make apply` from the repository and log out and back in. Check the layout with
`hyprctl monitors`. The legacy file remains on disk but does not configure Lua.
