# arch-hyprland-neobrutalist

An Arch Linux desktop with the Framework 12 neo-brutalist style: square
corners, black borders, eight accent palettes, and monospace typography.

The desktop uses Hyprland's Lua configuration and an AGS 3 bar with controls for
Wi-Fi, audio, displays, appearance, notifications, and power. Waybar stays available
as a fallback. Wofi, Mako, Kitty, hyprlock, and greetd/regreet share the visual style.
Wallpaper selection uses hyprpaper.

## Install

Use an up-to-date x86-64 Arch Linux installation, a normal user with `sudo` access,
and a network connection. The configuration is checked with Hyprland 0.56.2 and
AGS 3.1.2.

```bash
sudo pacman -S --needed git make
git clone https://github.com/fmschulz/arch-hyprland-neobrutalist.git
cd arch-hyprland-neobrutalist
make install
make doctor
```

For the optional themed login manager, run `make greetd` after the desktop works,
or use `make full-install` during installation.

The pinned AGS runtime is built in your user account. Its source archives and
package downloads are verified before use. No built runtime or installed
JavaScript dependencies are stored in this repository.

## Desktop controls

- `Super+Return`: terminal. `Super+D`: application launcher.
- `Super+/`: keybinding reference.
- `Super+Ctrl+I`: Wi-Fi controls. Click the bar modules for the other panels.
- `Super+Ctrl+T`: cycle the accent palette.
- `Super+W`: next wallpaper.
- `Super+Shift+Up`: workspace overview.
- `Super+L`: lock. `Super+Alt+P`: power menu.

See the [keybind reference](docs/reference/keybinds.md) for window movement,
workspaces, screenshots, and recording.

## Local configuration and privacy

`make apply` merges tracked files into `~/.config` and preserves local files.
Configure your displays in `~/.config/hypr/monitors.lua`; the installer creates it
once on new installations. Upgrades with an existing legacy monitor layout keep
using `monitors.conf` until you [convert it to Lua](docs/how-to/configure-monitors.md#legacy-configuration).

The repository contains reusable configuration and code. It excludes account
credentials, wireless profiles, Bluetooth device addresses, monitor serials,
workspace notes, browser profiles, clipboard history, and runtime logs. Weather
coordinates and Bluetooth preferences belong in local files created from the examples.

The installer refuses to overwrite configuration directories managed by a
controlcenter checkout. Use that checkout's deployer on such machines.

## Documentation

[Read the documentation](https://fmschulz.github.io/arch-hyprland-neobrutalist/)
for installation, local overrides, themes, and the desktop architecture.

```bash
uvx --with mkdocs-material mkdocs serve
```

| Directory | Contents |
| --- | --- |
| `configs/` | Desktop, AGS, terminal, shell, and application sources |
| `scripts/` | Installation, apply, doctor, and optional system setup |
| `packages/` | Pacman and AUR package manifests |
| `docs/` | MkDocs documentation |
| `wallpapers/` | Public wallpaper assets |

The screenshot under `assets/screenshots/` records the earlier v0.1.0 Waybar
layout. It does not show the current AGS bar.
