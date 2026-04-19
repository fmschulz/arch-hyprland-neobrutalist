# Design System

Release target: `v0.1.0`

This repo is meant to be reproducible by other Arch + Hyprland users, not just visually inspired by the source machine. The design decisions below are the public contract for the first release.

## Visual Language

- Border-first geometry with square corners and heavy black outlines
- Bright accent palette instead of muted grays
- Monospace-forward typography across Waybar, regreet, Kitty, Yazi, and Neovim
- Flat blocks plus hard drop shadows instead of glassmorphism or blur-heavy UI

Primary palette:

- Yellow: `#FFBE0B`
- Orange: `#FB5607`
- Pink: `#FF006E`
- Purple: `#8338EC`
- Mint: `#06FFA5`
- Blue: `#3A86FF`
- Black: `#000000`
- White: `#FFFFFF`

## Tracked Components

The public release tracks the design and behavior of:

- Hyprland
- Waybar
- Kitty
- Yazi
- Neovim
- Wofi
- Mako
- Hyprlock / Hypridle
- greetd / regreet
- Bash shell workflow
- Wallpapers
- Helper scripts for power, networking, USB, workspace naming, and radio playback

## Local-Only Overrides

These values are intentionally machine-specific and should not be committed:

- `~/.config/hypr/monitors.conf`
- `~/.config/arch-hypr-neobrutalist/bluetooth-devices.conf`
- `~/.config/arch-hypr-neobrutalist/radio-stations.tsv`
- `~/.config/hypr/workspace-names.json`
- `~/.bashrc.local`

## Reproducibility Boundaries

- `make apply` preserves local state instead of deleting non-repo files from `~/.config`.
- Monitor layout lives in a local file so the tracked Hyprland config stays portable.
- Radio stations ship with a safe default list that starts with KALX and can be expanded locally.
- Neovim is intentionally plugin-light for `v0.1.0`; the public baseline uses built-in functionality and a tracked theme so the result is reproducible without an external plugin graph.
