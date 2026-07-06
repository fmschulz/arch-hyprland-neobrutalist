# Design system

The desktop is meant to be reproducible by other Arch + Hyprland users, not just visually
inspired by one machine. The decisions below are the contract that makes that work.

## Visual language

- Border-first geometry with square corners (`rounding = 0`) and heavy black outlines
- White module fields carry the content; accent color marks *state*, not decoration
- Blur is off: windows are flat and, except Kitty's deliberate 0.7 translucency, opaque, so
  the compositor does no wasted shader work
- Monospace-forward typography with Nerd Font iconography (no emoji) across Waybar, Hyprlock,
  regreet, Kitty, Yazi, and Neovim
- Hard 2-4px black borders; drop shadows are reserved for the active workspace pill

## Palette

| Color | Hex | Role |
| --- | --- | --- |
| Yellow | `#FFBE0B` | Waybar background, active window border, groupbar active |
| Mint | `#06FFA5` | Clock, focused workspace pill, idle-inhibitor active |
| Pink | `#FF006E` | Active/urgent workspace, power button, battery-critical |
| Purple | `#8338EC` | Submap/mode indicator (visible only in a submap) |
| Blue | `#3A86FF` | Accent (Kitty/regreet variants) |
| Orange | `#FB5607` | Accent (Kitty/regreet variants) |
| Black | `#000000` | Every border, inactive window border, default text |
| White | `#FFFFFF` | Default module field background |

Iconography requires **JetBrainsMono Nerd Font** (`ttf-jetbrains-mono-nerd`); without a Nerd
Font the Waybar glyphs render as tofu boxes.

## Why the config is modular

The Hyprland config is one entry file plus numbered sections
(see [Architecture](architecture.md)). The split exists for reproducibility: everything
machine-portable is tracked and numbered, while the monitor layout - the one genuinely
per-machine part - is sourced from a separate local file. Other users edit
`~/.config/hypr/monitors.conf` for their displays and take the tracked sections as-is.

## Local-only overrides

These values are intentionally machine-specific and stay out of git:

- `~/.config/hypr/monitors.conf`
- `~/.config/arch-hypr-neobrutalist/bluetooth-devices.conf`
- `~/.config/arch-hypr-neobrutalist/radio-stations.tsv`
- `~/.config/arch-hypr-neobrutalist/welcome.conf`
- `~/.local/state/hypr/workspace-names.json`
- `~/.bashrc.local`

## Reproducibility boundaries

- `make apply` preserves local state instead of deleting non-repo files from `~/.config`.
- Monitor layout lives in a local file so the tracked Hyprland config stays portable.
- Radio stations ship with a safe default list that starts with KALX and can be expanded
  locally.
- Neovim is intentionally plugin-light: the tracked config uses built-in functionality and a
  tracked theme so the result is reproducible without an external plugin graph.
