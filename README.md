# arch-hyprland-neobrutalist

`v0.1.0` public baseline for a reproducible Arch Linux Hyprland setup with a neo-brutalist visual system.

This repo is structured like other public Hyprland dotfile projects: tracked configs, package manifests, install/apply scripts, screenshots space, and a small docs layer that explains the design choices instead of leaving them implicit.

## Included Components

- Hyprland desktop stack: `hyprland`, `hyprlock`, `hypridle`, Waybar, Mako, Wofi
- Shell and terminal workflow: Bash, Kitty, Yazi, Neovim, fzf/zoxide/atuin/starship
- Login and lock experience: themed `greetd` + `regreet`, lock screen, wallpapers
- Desktop behavior: workspace rename flow, monitor helpers, power/network/USB scripts
- Terminal radio: `Super+Shift+R` opens a station selector in Kitty and starts with KALX in the default station list

## Quick Start

Start from a working Arch install with a normal user that has `sudo` access:

```bash
sudo pacman -S --needed git make
git clone https://github.com/<owner>/arch-hyprland-neobrutalist.git
cd arch-hyprland-neobrutalist
make install
```

If you also want the themed `greetd` / `regreet` login manager:

```bash
make full-install
```

## Targets

```bash
make install
make full-install
make packages
make apply
make doctor
make system
make greetd
```

## Reproducibility Rules

- Repo-managed files are merged into `~/.config`; local state is preserved on `make apply`.
- Monitor layout is intentionally local.
  Edit `~/.config/hypr/monitors.conf` instead of the tracked `hyprland.conf`.
- Stateful or private data is intentionally excluded from git.
  This includes Bluetooth MAC addresses, workspace rename state, shell-local overrides, and any personal station additions.
- Yazi plugins and flavors are restored with `ya pkg install` during `make apply`.

## Docs

- `docs/DESIGN.md` explains the palette, typography, component choices, and local override boundaries.
- `docs/KEYBINDS.md` lists the core desktop shortcuts for the public release.
- `assets/screenshots/README.md` is the checklist for the visual showcase captures.

## Repo Layout

```text
configs/     Desktop, shell, and app configs copied into ~/.config
docs/        Design notes and keybind references for reproducibility
packages/    Pacman and AUR package manifests
scripts/     Bootstrap, apply, doctor, and system setup scripts
wallpapers/  Neo-brutalist wallpaper set used by the desktop and lock screen
```

## Local Overrides

These files are meant to stay machine-local:

- `~/.config/arch-hypr-neobrutalist/bluetooth-devices.conf`
- `~/.config/arch-hypr-neobrutalist/radio-stations.tsv`
- `~/.config/hypr/monitors.conf`
- `~/.bashrc.local`
