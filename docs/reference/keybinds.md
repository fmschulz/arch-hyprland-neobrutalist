# Core Keybinds

The binds below mirror `configs/hypr/conf.d/50-binds.conf`. `Super` is the
mod key. A full in-desktop cheatsheet is available at runtime with `Super+/`.

## Launchers

- `Super+Return` terminal (Kitty)
- `Super+D` app launcher (Wofi)
- `Super+Alt+Space` desktop menu (apps, capture, style, toggles, system)
- `Super+E` Yazi file manager in Kitty
- `Super+Shift+M` bester-ytm (YouTube Music TUI)
- `Super+C` clipboard history (cliphist via Wofi)
- `Super+/` or `Super+F1` keybinding cheatsheet

## Window Management

- `Super+Q` close window
- `Super+F` fullscreen
- `Super+V` toggle floating
- `Super+P` pseudo-tile
- `Super+J` toggle split direction
- `Super+G` toggle group (tabbed stack) · `Super+Ctrl+G` cycle group · `Super+Shift+Alt+G` lock group
- `Super+R` resize submap (arrows / `hjkl`; `Esc`, `Return`, or `Super+R` to exit)
- `Super+Shift+H/V` · `Super+Ctrl+H/V` step-resize · `Super+Shift+C` center
- `Super+Alt+Arrows` move focus
- `Super+Shift+Alt+Arrows` swap window

## Workspace Flow

- `Super+1..0` switch workspace · `Super+Shift+1..0` move window to workspace
- `Super+Left` / `Super+Right` adjacent workspace · `Super+Tab` previous workspace
- `Super+S` special workspace · `Super+grave` scratch · `Super+Shift+grave` send to scratch
- `Super+A` rename current workspace · `Super+Shift+A` workspace overview
- `ws <number> [name]` rename a workspace from the shell

## Monitors

- `Super+period` / `Super+comma` move window to next/previous monitor
- `Super+Shift+period` / `Super+Shift+comma` move workspace to next/previous monitor
- `Super+Ctrl+period` / `Super+Ctrl+comma` focus next/previous monitor
- `Super+Ctrl+M` monitor connect helper

## Screenshots & Recording

- `Print` region -> `~/Documents/screenshots` + clipboard
- `Super+Print` copy focused output to clipboard
- `Super+Ctrl+Print` full output -> `~/Documents/screenshots`
- `Super+Shift+Print` / `Super+Shift+F12` / `Shift+Print` region -> file + clipboard
- `Super+Shift+R` / `Super+Alt+Print` toggle area screen recording -> `~/Documents/screenrecordings`

## Desktop Actions

- `Super+W` next wallpaper · `Super+Shift+W` previous · `Super+Ctrl+W` random
- `Super+Ctrl+T` next theme (bar, borders, launcher, notifications, terminal)
- `Super+L` lock screen · `Super+Alt+P` logout menu · `Super+M` power menu
- `Super+Alt+R` reload Hyprland/Waybar · `Super+Ctrl+N` clear notifications

## Media & Brightness

- `XF86AudioRaiseVolume` / `LowerVolume` / `Mute` volume control
- `XF86AudioMicMute` toggle mic mute
- `XF86AudioPlay` / `Pause` / `Next` / `Prev` media playback (playerctl)
- `XF86MonBrightnessUp` / `Down` backlight

## Terminal Shortcuts

- `yy` open Yazi and `cd` into the selected directory on exit
- `ytm` open bester-ytm (YouTube Music TUI)
- `health` run the local system health script
- `cleanup` run the cache cleanup script
