# Design System

Release target: `v0.1.0`

This repo is meant to be reproducible by other Arch + Hyprland users, not just visually inspired by the source machine. The design decisions below are the public contract for the first release.

## Visual Language

- Border-first geometry with square corners (`rounding = 0`) and heavy black outlines
- White module fields carry the content; accent color marks *state*, not decoration
- Blur is off: windows are flat and, except Kitty's deliberate 0.7 translucency, opaque, so the compositor does no wasted shader work
- Monospace-forward typography with Nerd Font iconography (no emoji) across Waybar,
  Hyprlock, regreet, Kitty, Yazi, and Neovim
- Hard 2-4px black borders; drop shadows are reserved for the active workspace pill

Primary palette:

- Yellow: `#FFBE0B` — Waybar bar background, active window border, groupbar active
- Mint: `#06FFA5` — clock, focused workspace pill, idle-inhibitor active
- Pink: `#FF006E` — active/urgent workspace, power button, battery-critical
- Purple: `#8338EC` — submap/mode indicator (visible only in a submap)
- Blue: `#3A86FF` — accent (kitty/regreet variants)
- Orange: `#FB5607` — accent (kitty/regreet variants)
- Black: `#000000` — every border, inactive window border, default text
- White: `#FFFFFF` — default module field background

Iconography requires **JetBrainsMono Nerd Font** (`ttf-jetbrains-mono-nerd`);
without a Nerd Font the Waybar glyphs render as tofu boxes.

## Structure

- Hyprland config is modular: `~/.config/hypr/hyprland.conf` defines variables and
  sources `conf.d/10-env … 70-windowrules`. Edit the numbered section, not the entry file.
- Monitors are sourced separately from `~/.config/hypr/monitors.conf` (a preserved
  local override) so the tracked sections stay portable across machines.

## Tracked Components

The public release tracks the design and behavior of:

- Hyprland
- Waybar
- Kitty
- Yazi
- Neovim
- Wofi
- Mako
- Hyprlock / Hypridle / Hyprsunset (screen lock, idle, night color temperature)
- greetd / regreet
- Bash shell workflow
- Wallpapers
- Helper scripts for power, networking, USB, workspace naming, radio playback,
  screenshots/recording, the clock/calendar popup, and the keybind cheatsheet

## Local-Only Overrides

These values are intentionally machine-specific and should not be committed:

- `~/.config/hypr/monitors.conf`
- `~/.config/arch-hypr-neobrutalist/bluetooth-devices.conf`
- `~/.config/arch-hypr-neobrutalist/radio-stations.tsv`
- `~/.local/state/hypr/workspace-names.json`
- `~/.bashrc.local`

## Reproducibility Boundaries

- `make apply` preserves local state instead of deleting non-repo files from `~/.config`.
- Monitor layout lives in a local file so the tracked Hyprland config stays portable.
- Radio stations ship with a safe default list that starts with KALX and can be expanded locally.
- Neovim is intentionally plugin-light for `v0.1.0`; the public baseline uses built-in functionality and a tracked theme so the result is reproducible without an external plugin graph.
